import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bills_data_service.dart';
import 'package:flashbill/utils/app_logger.dart';

/// Service for dashboard calculations using centralized bills data
class DashboardService {
  final BillsDataService _billsService = BillsDataService();

  StreamSubscription<List<Map<String, dynamic>>>? _billsSubscription;
  StreamSubscription<QuerySnapshot>? _productsSubscription;
  StreamController<DashboardData>? _dashboardController;
  DashboardData? _latestData;
  String? _userId;
  int _recalcToken = 0;

  String _salesFilterType = 'month';
  DateTime _salesSelectedDate = DateTime.now();
  DateTime? _salesRangeStart;
  DateTime? _salesRangeEnd;

  /// Get access to bills service for checking cached data
  BillsDataService get billsService => _billsService;

  /// Initialize dashboard data loading
  void initialize(String userId) {
    _userId = userId;
    _billsService.initialize(userId);
  }

  /// Get stream of dashboard data updates
  Stream<DashboardData> getDashboardStream(
    String userId, {
    required String filterType,
    required DateTime selectedDate,
    DateTime? rangeStartDate,
    DateTime? rangeEndDate,
  }) {
    _salesFilterType = filterType;
    _salesSelectedDate = selectedDate;
    _salesRangeStart = rangeStartDate;
    _salesRangeEnd = rangeEndDate;
    _userId = userId;

    final controller = StreamController<DashboardData>();
    _dashboardController = controller;

    // Cancel any existing subscription before creating a new one
    _billsSubscription?.cancel();
    _productsSubscription?.cancel();

    // Always compute once immediately so the UI is never waiting on a filter change.
    unawaited(refreshAll());

    _billsSubscription = _billsService.billsStream.listen(
      (bills) => unawaited(_onBillsUpdated(bills)),
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
    );

    // Listen to products changes so availability / restock stay live.
    _productsSubscription = FirebaseFirestore.instance
        .collection('purchased-products')
        .doc(userId)
        .collection('items')
        .snapshots()
        .listen(
          (_) => unawaited(refreshAll()),
          onError: (error) {
            if (!controller.isClosed) {
              controller.addError(error);
            }
          },
        );

    // Listen for controller being cancelled to clean up subscription
    controller.onCancel = () {
      _billsSubscription?.cancel();
      _billsSubscription = null;
      _productsSubscription?.cancel();
      _productsSubscription = null;
      if (_dashboardController == controller) {
        _dashboardController = null;
      }
    };

    return controller.stream;
  }

  Future<void> _onBillsUpdated(List<Map<String, dynamic>> bills) async {
    await _emitLiveSales(bills);
    await refreshAll();
  }

  /// Pushes Sales & Profit immediately so it never waits on product queries.
  Future<void> _emitLiveSales(List<Map<String, dynamic>> bills) async {
    final controller = _dashboardController;
    if (controller == null || controller.isClosed) return;
    final sales = await _calculateSalesMetrics(bills);
    final latest = _latestData;
    final next = latest == null
        ? DashboardData.empty().copyWith(salesMetrics: sales)
        : latest.copyWith(salesMetrics: sales);
    _latestData = next;
    if (!controller.isClosed) {
      controller.add(next);
    }
  }

  /// Recalculates every dashboard box from the latest bills and products.
  Future<void> refreshAll() async {
    final userId = _userId;
    final controller = _dashboardController;
    if (userId == null || controller == null || controller.isClosed) return;

    final token = ++_recalcToken;
    final bills = _billsService.getCachedBills();
    try {
      final billResults = await Future.wait([
        _calculateSalesMetrics(bills),
        _calculateTopSellingProducts(bills),
        _calculatePendingPayments(bills),
        _calculateUpcomingPayments(bills),
        _calculatePreviousDueTracking(bills),
      ]);
      if (token != _recalcToken || controller.isClosed) return;

      final fromBills = DashboardData(
        salesMetrics: billResults[0] as SalesMetrics,
        topSellingProducts: billResults[1] as List<Map<String, dynamic>>,
        pendingPayments: billResults[2] as PendingPaymentsData,
        upcomingPayments: billResults[3] as List<Map<String, dynamic>>,
        previousDueTracking: billResults[4] as PreviousDueData,
        productsData: _latestData?.productsData ?? ProductsData.empty(),
      );
      _latestData = fromBills;
      controller.add(fromBills);

      final productsData = await _loadProductsData(userId);
      if (token != _recalcToken || controller.isClosed) return;
      final full = fromBills.copyWith(productsData: productsData);
      _latestData = full;
      controller.add(full);
    } catch (e) {
      appLog('Error calculating dashboard data: $e');
      if (!controller.isClosed && token == _recalcToken) {
        controller.addError(e);
      }
    }
  }

  /// Updates only Sales & Profit. Other dashboard sections stay unchanged.
  Future<void> applySalesFilter({
    required String filterType,
    required DateTime selectedDate,
    DateTime? rangeStartDate,
    DateTime? rangeEndDate,
  }) async {
    _salesFilterType = filterType;
    _salesSelectedDate = selectedDate;
    _salesRangeStart = rangeStartDate;
    _salesRangeEnd = rangeEndDate;
    ++_recalcToken;

    final controller = _dashboardController;
    if (controller == null || controller.isClosed) {
      await refreshAll();
      return;
    }

    await _emitLiveSales(_billsService.getCachedBills());
  }

  Future<SalesMetrics> _calculateSalesMetrics(
    List<Map<String, dynamic>> bills,
  ) async {
    int totalSales = 0;
    int totalProfit = 0;

    for (final billData in bills) {
      final billDate = billData['billDate'] as String? ?? '';
      final totalAmount = (billData['totalAmount'] as num?)?.toInt() ?? 0;
      final deliveryCharges =
          (billData['deliveryCharges'] as num?)?.toInt() ?? 0;
      final products = billData['products'] as Map<String, dynamic>?;
      final discount = (billData['discount'] as num?)?.toInt() ?? 0;

      // Check if bill matches the selected filter criteria
      if (_isFromSelectedMonth(
        billDate,
        _salesFilterType,
        _salesSelectedDate,
        _salesRangeStart,
        _salesRangeEnd,
      )) {
        totalSales += totalAmount - deliveryCharges;

        int billProfit = 0;
        if (products != null) {
          products.forEach((pKey, pValue) {
            if (pValue is Map<String, dynamic>) {
              final quantity = (pValue['quantity'] as num?)?.toInt() ?? 0;
              final sellingPrice = (pValue['price'] as num?)?.toInt() ?? 0;
              final boughtPrice = (pValue['boughtPrice'] as num?)?.toInt() ?? 0;

              final profitPerUnit = sellingPrice - boughtPrice;
              final productProfit = profitPerUnit * quantity;
              billProfit += productProfit;
            }
          });
        }

        final validDiscount = discount > 0 ? discount : 0;
        final netBillProfit = billProfit - validDiscount;
        totalProfit += netBillProfit;
      }
    }

    return SalesMetrics(totalSales: totalSales, totalProfit: totalProfit);
  }

  Future<List<Map<String, dynamic>>> _calculateTopSellingProducts(
    List<Map<String, dynamic>> bills,
  ) async {
    final productSales = <String, Map<String, dynamic>>{};

    for (final billData in bills) {
      final products = billData['products'] as Map<String, dynamic>?;
      final billDiscount = (billData['discount'] as num?)?.toInt() ?? 0;

      if (products != null) {
        int billTotalProfit = 0;
        final productProfits = <String, int>{};

        products.forEach((pKey, pValue) {
          if (pValue is Map<String, dynamic>) {
            final productName = pValue['productName'] as String? ?? 'Unknown';
            final quantity = (pValue['quantity'] as num?)?.toInt() ?? 0;
            final price = (pValue['price'] as num?)?.toInt() ?? 0;
            final boughtPrice = (pValue['boughtPrice'] as num?)?.toInt() ?? 0;

            final profitTotal = (pValue['profitTotal'] as num?)?.toInt();
            final productProfit =
                profitTotal ?? ((price - boughtPrice) * quantity);

            billTotalProfit += productProfit;
            productProfits[productName] =
                (productProfits[productName] ?? 0) + productProfit;
          }
        });

        products.forEach((pKey, pValue) {
          if (pValue is Map<String, dynamic>) {
            final productName = pValue['productName'] as String? ?? 'Unknown';
            final quantity = (pValue['quantity'] as num?)?.toInt() ?? 0;
            final price = (pValue['price'] as num?)?.toInt() ?? 0;
            final boughtPrice = (pValue['boughtPrice'] as num?)?.toInt() ?? 0;

            final profitTotal = (pValue['profitTotal'] as num?)?.toInt();
            final productProfit =
                profitTotal ?? ((price - boughtPrice) * quantity);

            final productDiscountShare = billTotalProfit > 0
                ? ((productProfit / billTotalProfit) * billDiscount).round()
                : 0;

            final adjustedProfit = productProfit - productDiscountShare;

            if (productSales.containsKey(productName)) {
              productSales[productName]!['quantity'] += quantity;
              productSales[productName]!['revenue'] += (quantity * price);
              productSales[productName]!['totalProfit'] += adjustedProfit;
            } else {
              productSales[productName] = {
                'quantity': quantity,
                'revenue': (quantity * price),
                'totalProfit': adjustedProfit,
                'name': productName,
              };
            }
          }
        });
      }
    }

    final topProducts = productSales.values.toList()
      ..sort(
        (a, b) => ((b['revenue'] as num?)?.toInt() ?? 0).compareTo(
          (a['revenue'] as num?)?.toInt() ?? 0,
        ),
      );

    return topProducts;
  }

  Future<PendingPaymentsData> _calculatePendingPayments(
    List<Map<String, dynamic>> bills,
  ) async {
    final pendingBills = <Map<String, dynamic>>[];
    int totalPending = 0;

    for (final billData in bills) {
      final totalAmountPaid = billData['totalAmountPaid'] as bool? ?? false;

      if (!totalAmountPaid) {
        final amountRemaining =
            (billData['amountRemaining'] as num?)?.toInt() ?? 0;

        if (amountRemaining > 0) {
          pendingBills.add({
            'id': billData['id'],
            'customerName': billData['customerName'] ?? 'Unknown',
            'customerMobile': billData['customerMobile'] ?? 'N/A',
            'customerVehicle': billData['customerVehicle'],
            'billDate': billData['billDate'] ?? 'N/A',
            'amountRemaining': amountRemaining,
            'totalAmount': billData['totalAmount'] ?? 0,
            'totalAmountPaid': false,
            'amountPaid': billData['amountPaid'] ?? 0,
            'products': billData['products'],
            'paymentMethod': billData['paymentMethod'] ?? 'cash',
          });
          totalPending += amountRemaining;
        }
      }
    }

    pendingBills.sort(
      (a, b) => ((b['amountRemaining'] as num?)?.toInt() ?? 0).compareTo(
        (a['amountRemaining'] as num?)?.toInt() ?? 0,
      ),
    );

    return PendingPaymentsData(
      payments: pendingBills.take(5).toList(),
      totalAmount: totalPending,
    );
  }

  Future<List<Map<String, dynamic>>> _calculateUpcomingPayments(
    List<Map<String, dynamic>> bills,
  ) async {
    final upcomingBills = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    for (final billData in bills) {
      final nextPaymentDate = billData['nextPaymentDate'] as String?;
      final amountRemaining =
          (billData['amountRemaining'] as num?)?.toInt() ?? 0;

      if (nextPaymentDate != null &&
          nextPaymentDate.isNotEmpty &&
          amountRemaining > 0) {
        try {
          final dateParts = nextPaymentDate.split('/');
          if (dateParts.length == 3) {
            final month = int.parse(dateParts[1]);
            final year = int.parse(dateParts[2]);

            if (month == currentMonth && year == currentYear) {
              upcomingBills.add({
                'id': billData['id'],
                'customerName': billData['customerName'] ?? 'Unknown',
                'customerMobile': billData['customerMobile'] ?? 'N/A',
                'customerVehicle': billData['customerVehicle'],
                'billDate': billData['billDate'] ?? 'N/A',
                'nextPaymentDate': nextPaymentDate,
                'totalAmount': billData['totalAmount'] ?? 0,
                'amountPaid': billData['amountPaid'] ?? 0,
                'amountRemaining': amountRemaining,
                'products': billData['products'],
              });
            }
          }
        } catch (e) {
          appLog('Error parsing date $nextPaymentDate: $e');
        }
      }
    }

    upcomingBills.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['nextPaymentDate'].replaceAll('/', '-'));
        final dateB = DateTime.parse(b['nextPaymentDate'].replaceAll('/', '-'));
        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });

    return upcomingBills;
  }

  Future<PreviousDueData> _calculatePreviousDueTracking(
    List<Map<String, dynamic>> bills,
  ) async {
    double totalCollected = 0.0;
    double totalPending = 0.0;
    int totalBills = 0;

    for (final billData in bills) {
      final previousDueAmount =
          (billData['previousDueAmount'] as num?)?.toDouble() ?? 0.0;
      final previousPaidAmount =
          (billData['previousPaidAmount'] as num?)?.toDouble() ?? 0.0;

      if (previousDueAmount > 0) {
        totalBills++;
        totalCollected += previousPaidAmount;
        totalPending += (previousDueAmount - previousPaidAmount);
      }
    }

    return PreviousDueData(
      totalBills: totalBills,
      totalCollected: totalCollected,
      totalPending: totalPending,
    );
  }

  Future<ProductsData> _loadProductsData(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshots = await Future.wait([
        firestore
            .collection('purchased-products')
            .doc(userId)
            .collection('items')
            .get(),
        firestore
            .collection('product-names')
            .doc(userId)
            .collection('items')
            .get(),
      ]);
      final productsSnapshot = snapshots[0];
      final namesSnapshot = snapshots[1];

      final catalogImages = <String, String>{};
      for (final doc in namesSnapshot.docs) {
        final data = doc.data();
        final name = (data['name'] as String? ?? '').trim().toLowerCase();
        final url = data['imageUrl'] as String?;
        if (name.isNotEmpty && url != null && url.isNotEmpty) {
          catalogImages[name] = url;
        }
      }

      final orderNowList = <Map<String, dynamic>>[];
      int totalQty = 0;
      double totalAmount = 0.0;
      final availableProductNames = <String>{};

      // Group batches by product name to track total quantity per product
      final Map<String, Map<String, dynamic>> productSummary = {};

      for (final productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        // Parse quantity - handle both number and string types
        int quantity = 0;
        final qtyValue = productData['quantity'];
        if (qtyValue is num) {
          quantity = qtyValue.toInt();
        } else if (qtyValue is String) {
          quantity = int.tryParse(qtyValue) ?? 0;
        }

        final buyingPrice =
            (productData['buyingPrice'] as num?)?.toDouble() ?? 0.0;
        final productName = productData['productName'] as String? ?? '';
        final supplierName =
            productData['supplierName'] as String? ?? 'Unknown Supplier';
        final unit = productData['unit'] as String? ?? 'N/A';
        final imageUrl = (productData['imageUrl'] as String?)?.trim();
        final resolvedImage = (imageUrl != null && imageUrl.isNotEmpty)
            ? imageUrl
            : null;

        // Track total quantity across all batches for this product
        if (productSummary.containsKey(productName)) {
          productSummary[productName]!['totalQuantity'] += quantity;
          if (productSummary[productName]!['imageUrl'] == null &&
              resolvedImage != null) {
            productSummary[productName]!['imageUrl'] = resolvedImage;
          }
        } else {
          productSummary[productName] = {
            'productName': productName.isEmpty ? 'Unknown' : productName,
            'supplierName': supplierName,
            'unit': unit,
            'totalQuantity': quantity,
            'imageUrl': resolvedImage,
          };
        }

        if (quantity > 0) {
          totalQty += quantity;
          totalAmount += quantity * buyingPrice;
          if (productName.isNotEmpty) {
            availableProductNames.add(productName);
          }
        }
      }

      // Add products to orderNow list only if total quantity across all batches is 0
      for (final productData in productSummary.values) {
        if (productData['totalQuantity'] == 0) {
          final name = productData['productName'] as String;
          orderNowList.add({
            'productName': name,
            'supplierName': productData['supplierName'],
            'unit': productData['unit'],
            'quantity': 0,
            'imageUrl':
                productData['imageUrl'] ?? catalogImages[name.toLowerCase()],
          });
        }
      }

      // Sort the orderNowList alphabetically by product name (A to Z)
      orderNowList.sort((a, b) {
        final nameA = (a['productName'] as String).toLowerCase();
        final nameB = (b['productName'] as String).toLowerCase();
        return nameA.compareTo(nameB);
      });

      return ProductsData(
        orderNowProducts: orderNowList,
        totalAvailableQty: totalQty,
        totalAvailableAmount: totalAmount,
        availableProductsCount: availableProductNames.length,
      );
    } catch (e) {
      appLog('Error loading products data: $e');
      return ProductsData.empty();
    }
  }

  bool _isFromSelectedMonth(
    String billDate,
    String filterType,
    DateTime selectedDate,
    DateTime? rangeStartDate,
    DateTime? rangeEndDate,
  ) {
    try {
      if (filterType == 'all') return true;

      final parts = billDate.split('/');
      if (parts.length != 3) return false;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final date = DateTime(year, month, day);

      if (filterType == 'range') {
        if (rangeStartDate == null || rangeEndDate == null) return false;
        return date.isAfter(rangeStartDate.subtract(const Duration(days: 1))) &&
            date.isBefore(rangeEndDate.add(const Duration(days: 1)));
      } else if (filterType == 'month') {
        return month == selectedDate.month && year == selectedDate.year;
      } else if (filterType == 'year') {
        return year == selectedDate.year;
      } else if (filterType == 'day') {
        return day == selectedDate.day &&
            month == selectedDate.month &&
            year == selectedDate.year;
      }
      return false;
    } catch (e) {
      appLog('Error parsing date "$billDate": $e');
      return false;
    }
  }

  void dispose() {
    _billsSubscription?.cancel();
    _productsSubscription?.cancel();
    _billsService.dispose();
  }
}

// Data models for dashboard
class DashboardData {
  final SalesMetrics salesMetrics;
  final List<Map<String, dynamic>> topSellingProducts;
  final PendingPaymentsData pendingPayments;
  final List<Map<String, dynamic>> upcomingPayments;
  final PreviousDueData previousDueTracking;
  final ProductsData productsData;

  const DashboardData({
    required this.salesMetrics,
    required this.topSellingProducts,
    required this.pendingPayments,
    required this.upcomingPayments,
    required this.previousDueTracking,
    required this.productsData,
  });

  factory DashboardData.empty() => const DashboardData(
    salesMetrics: SalesMetrics(totalSales: 0, totalProfit: 0),
    topSellingProducts: [],
    pendingPayments: PendingPaymentsData(payments: [], totalAmount: 0),
    upcomingPayments: [],
    previousDueTracking: PreviousDueData(
      totalBills: 0,
      totalCollected: 0,
      totalPending: 0,
    ),
    productsData: ProductsData(
      orderNowProducts: [],
      totalAvailableQty: 0,
      totalAvailableAmount: 0,
      availableProductsCount: 0,
    ),
  );

  DashboardData copyWith({
    SalesMetrics? salesMetrics,
    List<Map<String, dynamic>>? topSellingProducts,
    PendingPaymentsData? pendingPayments,
    List<Map<String, dynamic>>? upcomingPayments,
    PreviousDueData? previousDueTracking,
    ProductsData? productsData,
  }) {
    return DashboardData(
      salesMetrics: salesMetrics ?? this.salesMetrics,
      topSellingProducts: topSellingProducts ?? this.topSellingProducts,
      pendingPayments: pendingPayments ?? this.pendingPayments,
      upcomingPayments: upcomingPayments ?? this.upcomingPayments,
      previousDueTracking: previousDueTracking ?? this.previousDueTracking,
      productsData: productsData ?? this.productsData,
    );
  }
}

class SalesMetrics {
  final int totalSales;
  final int totalProfit;

  const SalesMetrics({required this.totalSales, required this.totalProfit});
}

class PendingPaymentsData {
  final List<Map<String, dynamic>> payments;
  final int totalAmount;

  const PendingPaymentsData({
    required this.payments,
    required this.totalAmount,
  });
}

class PreviousDueData {
  final int totalBills;
  final double totalCollected;
  final double totalPending;

  const PreviousDueData({
    required this.totalBills,
    required this.totalCollected,
    required this.totalPending,
  });
}

class ProductsData {
  final List<Map<String, dynamic>> orderNowProducts;
  final int totalAvailableQty;
  final double totalAvailableAmount;
  final int availableProductsCount;

  const ProductsData({
    required this.orderNowProducts,
    required this.totalAvailableQty,
    required this.totalAvailableAmount,
    required this.availableProductsCount,
  });

  factory ProductsData.empty() => const ProductsData(
    orderNowProducts: [],
    totalAvailableQty: 0,
    totalAvailableAmount: 0.0,
    availableProductsCount: 0,
  );
}
