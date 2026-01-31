import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bills_data_service.dart';

/// Service for dashboard calculations using centralized bills data
class DashboardService {
  final BillsDataService _billsService = BillsDataService();

  StreamSubscription<List<Map<String, dynamic>>>? _billsSubscription;

  /// Get access to bills service for checking cached data
  BillsDataService get billsService => _billsService;

  /// Initialize dashboard data loading
  void initialize(String userId) {
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
    final controller = StreamController<DashboardData>();

    // Cancel any existing subscription before creating a new one
    _billsSubscription?.cancel();

    // Immediately calculate and emit data using cached bills
    final cachedBills = _billsService.getCachedBills();
    if (cachedBills.isNotEmpty) {
      _calculateAllDashboardData(
            cachedBills,
            userId,
            filterType: filterType,
            selectedDate: selectedDate,
            rangeStartDate: rangeStartDate,
            rangeEndDate: rangeEndDate,
          )
          .then((dashboardData) {
            if (!controller.isClosed) {
              controller.add(dashboardData);
            }
          })
          .catchError((error) {
            print('Error calculating initial dashboard data: $error');
            if (!controller.isClosed) {
              controller.addError(error);
            }
          });
    }

    _billsSubscription = _billsService.billsStream.listen(
      (bills) async {
        try {
          final dashboardData = await _calculateAllDashboardData(
            bills,
            userId,
            filterType: filterType,
            selectedDate: selectedDate,
            rangeStartDate: rangeStartDate,
            rangeEndDate: rangeEndDate,
          );
          if (!controller.isClosed) {
            controller.add(dashboardData);
          }
        } catch (e) {
          print('Error calculating dashboard data: $e');
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    // Listen for controller being cancelled to clean up subscription
    controller.onCancel = () {
      _billsSubscription?.cancel();
      _billsSubscription = null;
    };

    return controller.stream;
  }

  /// Calculate all dashboard metrics from cached bills data
  Future<DashboardData> _calculateAllDashboardData(
    List<Map<String, dynamic>> bills,
    String userId, {
    required String filterType,
    required DateTime selectedDate,
    DateTime? rangeStartDate,
    DateTime? rangeEndDate,
  }) async {
    // Calculate all metrics in parallel for better performance
    final results = await Future.wait([
      _calculateSalesMetrics(
        bills,
        filterType: filterType,
        selectedDate: selectedDate,
        rangeStartDate: rangeStartDate,
        rangeEndDate: rangeEndDate,
      ),
      _calculateTopSellingProducts(bills),
      _calculatePendingPayments(bills),
      _calculateUpcomingPayments(bills),
      _calculatePreviousDueTracking(bills),
      _loadPurchasesData(
        userId,
        filterType: filterType,
        selectedDate: selectedDate,
        rangeStartDate: rangeStartDate,
        rangeEndDate: rangeEndDate,
      ),
      _loadProductsData(userId),
    ]);

    return DashboardData(
      salesMetrics: results[0] as SalesMetrics,
      topSellingProducts: results[1] as List<Map<String, dynamic>>,
      pendingPayments: results[2] as PendingPaymentsData,
      upcomingPayments: results[3] as List<Map<String, dynamic>>,
      previousDueTracking: results[4] as PreviousDueData,
      purchasesData: results[5] as PurchasesData,
      productsData: results[6] as ProductsData,
    );
  }

  Future<SalesMetrics> _calculateSalesMetrics(
    List<Map<String, dynamic>> bills, {
    required String filterType,
    required DateTime selectedDate,
    DateTime? rangeStartDate,
    DateTime? rangeEndDate,
  }) async {
    int totalSales = 0;
    int totalProfit = 0;
    int salesCount = 0;
    int itemsSold = 0;

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
        filterType,
        selectedDate,
        rangeStartDate,
        rangeEndDate,
      )) {
        totalSales += totalAmount - deliveryCharges;
        salesCount++;

        int billProfit = 0;
        if (products != null) {
          products.forEach((pKey, pValue) {
            if (pValue is Map<String, dynamic>) {
              final quantity = (pValue['quantity'] as num?)?.toInt() ?? 0;
              final sellingPrice = (pValue['price'] as num?)?.toInt() ?? 0;
              final boughtPrice = (pValue['boughtPrice'] as num?)?.toInt() ?? 0;
              itemsSold += quantity;

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

    return SalesMetrics(
      totalSales: totalSales,
      totalProfit: totalProfit,
      salesCount: salesCount,
      itemsSold: itemsSold,
    );
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

    return topProducts.take(3).toList();
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
          print('Error parsing date $nextPaymentDate: $e');
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

  Future<PurchasesData> _loadPurchasesData(
    String userId, {
    required String filterType,
    required DateTime selectedDate,
    DateTime? rangeStartDate,
    DateTime? rangeEndDate,
  }) async {
    try {
      final purchasesSnapshot = await FirebaseFirestore.instance
          .collection('purchases')
          .doc(userId)
          .collection('items')
          .get();

      int totalBuying = 0;
      int buyingCount = 0;
      int totalQuantityBought = 0;

      if (purchasesSnapshot.docs.isNotEmpty) {
        for (final purchaseDoc in purchasesSnapshot.docs) {
          final purchaseData = purchaseDoc.data();
          final purchaseDate = purchaseData['date'] as String? ?? '';

          if (_isFromSelectedMonth(
            purchaseDate,
            filterType,
            selectedDate,
            rangeStartDate,
            rangeEndDate,
          )) {
            final amount = (purchaseData['totalAmount'] as num?)?.toInt() ?? 0;
            totalBuying += amount;
            buyingCount++;

            final totalUnits =
                (purchaseData['totalUnits'] as num?)?.toInt() ?? 0;
            totalQuantityBought += totalUnits;
          }
        }
      }

      return PurchasesData(
        totalBuying: totalBuying,
        buyingCount: buyingCount,
        totalQuantityBought: totalQuantityBought,
      );
    } catch (e) {
      print('Error loading purchases data: $e');
      return PurchasesData.empty();
    }
  }

  Future<ProductsData> _loadProductsData(String userId) async {
    try {
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(userId)
          .collection('items')
          .get();

      final orderNowList = <Map<String, dynamic>>[];
      int totalQty = 0;
      double totalAmount = 0.0;
      final availableProductNames = <String>{};

      for (final productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        final quantity = (productData['quantity'] as num?)?.toInt() ?? 0;
        final buyingPrice =
            (productData['buyingPrice'] as num?)?.toDouble() ?? 0.0;
        final productName = productData['productName'] as String? ?? '';

        if (quantity == 0) {
          orderNowList.add({
            'productName': productData['productName'] ?? 'Unknown',
            'supplierName': productData['supplierName'] ?? 'Unknown Supplier',
            'unit': productData['unit'] ?? 'N/A',
            'quantity': 0,
          });
        }

        if (quantity > 0) {
          totalQty += quantity;
          totalAmount += quantity * buyingPrice;
          if (productName.isNotEmpty) {
            availableProductNames.add(productName);
          }
        }
      }

      return ProductsData(
        orderNowProducts: orderNowList,
        totalAvailableQty: totalQty,
        totalAvailableAmount: totalAmount,
        availableProductsCount: availableProductNames.length,
      );
    } catch (e) {
      print('Error loading products data: $e');
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
      print('Error parsing date "$billDate": $e');
      return false;
    }
  }

  void dispose() {
    _billsSubscription?.cancel();
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
  final PurchasesData purchasesData;
  final ProductsData productsData;

  const DashboardData({
    required this.salesMetrics,
    required this.topSellingProducts,
    required this.pendingPayments,
    required this.upcomingPayments,
    required this.previousDueTracking,
    required this.purchasesData,
    required this.productsData,
  });
}

class SalesMetrics {
  final int totalSales;
  final int totalProfit;
  final int salesCount;
  final int itemsSold;

  const SalesMetrics({
    required this.totalSales,
    required this.totalProfit,
    required this.salesCount,
    required this.itemsSold,
  });
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

class PurchasesData {
  final int totalBuying;
  final int buyingCount;
  final int totalQuantityBought;

  const PurchasesData({
    required this.totalBuying,
    required this.buyingCount,
    required this.totalQuantityBought,
  });

  factory PurchasesData.empty() => const PurchasesData(
    totalBuying: 0,
    buyingCount: 0,
    totalQuantityBought: 0,
  );
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
