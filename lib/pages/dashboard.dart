import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flashbill/pages/helpers/utils.dart';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/pending_payments_page.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  DateTime selectedDate = DateTime.now();
  String filterType = 'month'; // 'month', 'year', 'day', 'range', or 'all'
  DateTime? _rangeStartDate;
  DateTime? _rangeEndDate;
  bool _isLoading = true;
  int _totalSales = 0;
  int _totalBuying = 0;
  int _totalProfitLoss = 0;
  int _totalSalesCount = 0; // Number of bills/sales
  int _totalItemsSold = 0; // Total items sold
  int _totalBuyingCount = 0; // Number of purchase transactions
  int _totalQuantityBought = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _billsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _purchasesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _productsSubscription;

  // Top Selling Products
  List<Map<String, dynamic>> _topSellingProducts = [];

  // Pending Payments
  List<Map<String, dynamic>> _pendingPayments = [];
  int _totalPendingAmount = 0;

  // Upcoming Payments (based on next payment date where remaining amount is 0)
  List<Map<String, dynamic>> _upcomingPayments = [];

  // Expansion states
  bool _expandTopProducts = false;
  bool _expandPendingPayments = false;
  bool _expandUpcomingPayments = false;
  bool _expandOrderNow = false;

  // Order Now Products (qty = 0)
  List<Map<String, dynamic>> _orderNowProducts = [];

  // Availability Section
  int _totalAvailableQty = 0;
  double _totalAvailableAmount = 0.0;
  int _availableProductsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFilterPreference();
  }

  @override
  void dispose() {
    _billsSubscription?.cancel();
    _purchasesSubscription?.cancel();
    _productsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFilterPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFilterType = prefs.getString('dashboard_filter_type');
    if (savedFilterType != null) {
      setState(() {
        filterType = savedFilterType;
        if (savedFilterType == 'range') {
          final startDateStr = prefs.getString('dashboard_range_start');
          final endDateStr = prefs.getString('dashboard_range_end');
          if (startDateStr != null && endDateStr != null) {
            _rangeStartDate = DateTime.parse(startDateStr);
            _rangeEndDate = DateTime.parse(endDateStr);
          }
        }
      });
    }
    _loadSalesReport();
  }

  Future<void> _saveFilterPreference(String filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_filter_type', filter);
    if (filter == 'range' && _rangeStartDate != null && _rangeEndDate != null) {
      await prefs.setString(
        'dashboard_range_start',
        _rangeStartDate!.toIso8601String(),
      );
      await prefs.setString(
        'dashboard_range_end',
        _rangeEndDate!.toIso8601String(),
      );
    }
  }

  void _loadSalesReport() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final userId = user.uid;
    final firestore = FirebaseFirestore.instance;

    // Listen to bills changes
    _billsSubscription = firestore
        .collection('bills')
        .doc(userId)
        .collection('items')
        .snapshots()
        .listen((_) {
          _calculateAndUpdateDashboard(userId);
          _loadTopSellingProducts(userId);
          _loadPendingPayments(userId);
          _loadUpcomingPayments(userId);
          _loadOrderNowProducts(userId);
          _loadAvailability(userId);
        });

    // Listen to purchases changes
    _purchasesSubscription = firestore
        .collection('purchases')
        .doc(userId)
        .collection('items')
        .snapshots()
        .listen((_) {
          _calculateAndUpdateDashboard(userId);
        });

    // Listen to purchased products changes
    _productsSubscription = firestore
        .collection('purchased-products')
        .doc(userId)
        .collection('items')
        .snapshots()
        .listen((_) {
          _calculateAndUpdateDashboard(userId);
          _loadOrderNowProducts(userId);
          _loadAvailability(userId);
        });
  }

  Future<void> _loadTopSellingProducts(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final billsSnapshot = await firestore
          .collection('bills')
          .doc(userId)
          .collection('items')
          .get();

      final productSales = <String, Map<String, dynamic>>{};

      for (var billDoc in billsSnapshot.docs) {
        final billData = billDoc.data();
        final products = billData['products'] as Map<String, dynamic>?;
        final billDiscount = (billData['discount'] as num?)?.toInt() ?? 0;

        if (products != null) {
          // First, calculate total bill profit to determine discount distribution
          int billTotalProfit = 0;
          final productProfits = <String, int>{};

          products.forEach((pKey, pValue) {
            if (pValue is Map<String, dynamic>) {
              final productName = pValue['productName'] as String? ?? 'Unknown';
              final quantity = (pValue['quantity'] as num?)?.toInt() ?? 0;
              final price = (pValue['price'] as num?)?.toInt() ?? 0;
              final boughtPrice = (pValue['boughtPrice'] as num?)?.toInt() ?? 0;

              // Use stored profitTotal if available, else calculate
              final profitTotal = (pValue['profitTotal'] as num?)?.toInt();
              final productProfit =
                  profitTotal ?? ((price - boughtPrice) * quantity);

              billTotalProfit += productProfit;
              productProfits[productName] =
                  (productProfits[productName] ?? 0) + productProfit;
            }
          });

          // Now distribute discount proportionally and accumulate product sales
          products.forEach((pKey, pValue) {
            if (pValue is Map<String, dynamic>) {
              final productName = pValue['productName'] as String? ?? 'Unknown';
              final quantity = (pValue['quantity'] as num?)?.toInt() ?? 0;
              final price = (pValue['price'] as num?)?.toInt() ?? 0;
              final boughtPrice = (pValue['boughtPrice'] as num?)?.toInt() ?? 0;

              // Use stored profitTotal if available, else calculate
              final profitTotal = (pValue['profitTotal'] as num?)?.toInt();
              final productProfit =
                  profitTotal ?? ((price - boughtPrice) * quantity);

              // Calculate this product's share of the discount
              final productDiscountShare = billTotalProfit > 0
                  ? ((productProfit / billTotalProfit) * billDiscount).round()
                  : 0;

              // Adjusted profit after discount
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

      // Convert to list and sort by revenue
      final topProducts = productSales.values.toList()
        ..sort(
          (a, b) => ((b['revenue'] as num?)?.toInt() ?? 0).compareTo(
            (a['revenue'] as num?)?.toInt() ?? 0,
          ),
        );

      if (mounted) {
        setState(() {
          _topSellingProducts = topProducts.take(3).toList();
        });
      }
    } catch (e) {
      print('Error loading top selling products: $e');
    }
  }

  Future<void> _loadPendingPayments(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final billsSnapshot = await firestore
          .collection('bills')
          .doc(userId)
          .collection('items')
          .get();

      final pendingBills = <Map<String, dynamic>>[];
      int totalPending = 0;

      for (var billDoc in billsSnapshot.docs) {
        final billData = billDoc.data();
        final totalAmountPaid = billData['totalAmountPaid'] as bool? ?? false;

        // Only process unpaid bills
        if (!totalAmountPaid) {
          final amountRemaining =
              (billData['amountRemaining'] as num?)?.toInt() ?? 0;

          // Only add if there's an actual amount remaining
          if (amountRemaining > 0) {
            pendingBills.add({
              'id': billDoc.id,
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

      // Sort by amount remaining (highest first) and take top 5
      pendingBills.sort(
        (a, b) => ((b['amountRemaining'] as num?)?.toInt() ?? 0).compareTo(
          (a['amountRemaining'] as num?)?.toInt() ?? 0,
        ),
      );

      if (mounted) {
        setState(() {
          _pendingPayments = pendingBills.take(5).toList();
          _totalPendingAmount = totalPending;
        });
      }
    } catch (e) {
      print('Error loading pending payments: $e');
    }
  }

  Future<void> _loadUpcomingPayments(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final billsSnapshot = await firestore
          .collection('bills')
          .doc(userId)
          .collection('items')
          .get();

      final upcomingBills = <Map<String, dynamic>>[];
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      for (var billDoc in billsSnapshot.docs) {
        final billData = billDoc.data();
        final nextPaymentDate = billData['nextPaymentDate'] as String?;
        final amountRemaining =
            (billData['amountRemaining'] as num?)?.toInt() ?? 0;

        // Show upcoming payments where nextPaymentDate is set AND amountRemaining > 0
        if (nextPaymentDate != null &&
            nextPaymentDate.isNotEmpty &&
            amountRemaining > 0) {
          try {
            // Parse date in dd/MM/yyyy format
            final dateParts = nextPaymentDate.split('/');
            if (dateParts.length == 3) {
              final month = int.parse(dateParts[1]);
              final year = int.parse(dateParts[2]);

              // Only include if it's in the current month and year
              if (month == currentMonth && year == currentYear) {
                upcomingBills.add({
                  'id': billDoc.id,
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

      // Sort by next payment date (upcoming first)
      upcomingBills.sort((a, b) {
        try {
          final dateA = DateTime.parse(
            a['nextPaymentDate'].replaceAll('/', '-'),
          );
          final dateB = DateTime.parse(
            b['nextPaymentDate'].replaceAll('/', '-'),
          );
          return dateA.compareTo(dateB);
        } catch (e) {
          return 0;
        }
      });

      if (mounted) {
        setState(() {
          _upcomingPayments = upcomingBills;
        });
      }
    } catch (e) {
      print('Error loading upcoming payments: $e');
    }
  }

  Future<void> _loadOrderNowProducts(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final productsSnapshot = await firestore
          .collection('purchased-products')
          .doc(userId)
          .collection('items')
          .get();

      final orderNowList = <Map<String, dynamic>>[];

      for (var productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        final quantity = (productData['quantity'] as num?)?.toInt() ?? 0;

        // Only process products with zero quantity (out of stock)
        if (quantity == 0) {
          orderNowList.add({
            'productName': productData['productName'] ?? 'Unknown',
            'supplierName': productData['supplierName'] ?? 'Unknown Supplier',
            'unit': productData['unit'] ?? 'N/A',
            'quantity': 0,
          });
        }
      }

      if (mounted) {
        setState(() {
          _orderNowProducts = orderNowList;
        });
      }
    } catch (e) {
      print('Error loading order now products: $e');
    }
  }

  Future<void> _loadAvailability(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final productsSnapshot = await firestore
          .collection('purchased-products')
          .doc(userId)
          .collection('items')
          .get();

      int totalQty = 0;
      double totalAmount = 0.0;

      // Use a Set to track unique product names with quantity > 0
      final availableProductNames = <String>{};

      for (var productDoc in productsSnapshot.docs) {
        final productData = productDoc.data();
        final quantity = (productData['quantity'] as num?)?.toInt() ?? 0;
        final buyingPrice =
            (productData['buyingPrice'] as num?)?.toDouble() ?? 0.0;
        final productName = productData['productName'] as String? ?? '';

        // Only count products with quantity > 0
        if (quantity > 0) {
          totalQty += quantity;
          totalAmount += quantity * buyingPrice;
          // Add product name to the set (duplicates are automatically ignored)
          if (productName.isNotEmpty) {
            availableProductNames.add(productName);
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalAvailableQty = totalQty;
          _totalAvailableAmount = totalAmount;
          _availableProductsCount = availableProductNames.length;
        });
      }
    } catch (e) {
      print('Error loading availability: $e');
    }
  }

  Future<void> _calculateAndUpdateDashboard(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Load bills data and calculate sales + profit
      int totalSales = 0;
      int totalProfit = 0;
      int totalBuying = 0;
      int salesCount = 0;
      int itemsSold = 0;

      final billsSnapshot = await firestore
          .collection('bills')
          .doc(userId)
          .collection('items')
          .get();

      for (var billDoc in billsSnapshot.docs) {
        final billData = billDoc.data();
        final billDate = billData['billDate'] as String? ?? '';
        final totalAmount = (billData['totalAmount'] as num?)?.toInt() ?? 0;
        final products = billData['products'] as Map<String, dynamic>?;
        final discount = (billData['discount'] as num?)?.toInt() ?? 0;

        // Check if bill is from selected month
        if (_isFromSelectedMonth(billDate)) {
          totalSales += totalAmount;
          salesCount++; // Increment sales count

          int billProfit = 0;

          // Calculate profit for this bill using profitMargin if available, else calculate
          if (products != null) {
            products.forEach((pKey, pValue) {
              if (pValue is Map<String, dynamic>) {
                final quantity = (pValue['quantity'] as num?)?.toInt() ?? 0;
                final sellingPrice = (pValue['price'] as num?)?.toInt() ?? 0;
                final boughtPrice =
                    (pValue['boughtPrice'] as num?)?.toInt() ?? 0;
                itemsSold += quantity;
                // Fallback: calculate from prices (legacy bills)
                final profitPerUnit = sellingPrice - boughtPrice;
                final productProfit = profitPerUnit * quantity;
                billProfit += productProfit;
              }
            });
          }

          // IMPORTANT: Discount reduces profit, never increases it
          // Ensure discount is always positive before subtracting
          final validDiscount = discount > 0 ? discount : 0;
          final netBillProfit = billProfit - validDiscount;
          totalProfit += netBillProfit;
        }
      }

      // Load bought products data for the selected month
      int buyingCount = 0;
      int totalQuantityBoughtThisMonth = 0;

      // Try to get data from purchases (purchase entry headers)
      final purchasesSnapshot = await firestore
          .collection('purchases')
          .doc(userId)
          .collection('items')
          .get();

      if (purchasesSnapshot.docs.isNotEmpty) {
        for (var purchaseDoc in purchasesSnapshot.docs) {
          final purchaseData = purchaseDoc.data();
          final purchaseDate = purchaseData['date'] as String? ?? '';

          // Check if purchase is from selected month
          if (_isFromSelectedMonth(purchaseDate)) {
            final amount = (purchaseData['totalAmount'] as num?)?.toInt() ?? 0;
            totalBuying += amount;
            buyingCount++;

            // Get total units for this purchase
            final totalUnits =
                (purchaseData['totalUnits'] as num?)?.toInt() ?? 0;
            totalQuantityBoughtThisMonth += totalUnits;
          }
        }
      } else {
        // Fallback: Calculate from purchased-products if purchases doesn't exist
        final productsSnapshot = await firestore
            .collection('purchased-products')
            .doc(userId)
            .collection('items')
            .get();

        if (productsSnapshot.docs.isNotEmpty) {
          for (var productDoc in productsSnapshot.docs) {
            final productData = productDoc.data();
            final productDate = productData['date'] as String? ?? '';

            // Check if product purchase is from selected month
            if (_isFromSelectedMonth(productDate)) {
              final quantity = (productData['quantity'] as num?)?.toInt() ?? 0;
              final buyingPrice =
                  (productData['buyingPrice'] as num?)?.toInt() ?? 0;
              final amount = quantity * buyingPrice;

              totalBuying += amount;
              totalQuantityBoughtThisMonth += quantity;
            }
          }

          // Count distinct purchases from the products
          final purchasesFromProducts = <String>{};
          for (var productDoc in productsSnapshot.docs) {
            final productData = productDoc.data();
            final productDate = productData['date'] as String? ?? '';
            if (_isFromSelectedMonth(productDate)) {
              final purchaseId = productData['purchaseId'] as String?;
              if (purchaseId != null) {
                purchasesFromProducts.add(purchaseId);
              }
            }
          }
          buyingCount = purchasesFromProducts.length;
        }
      }

      if (mounted) {
        setState(() {
          _totalSales = totalSales;
          _totalBuying = totalBuying;
          _totalProfitLoss = totalProfit;
          _totalSalesCount = salesCount;
          _totalItemsSold = itemsSold;
          _totalBuyingCount = buyingCount;
          _totalQuantityBought = totalQuantityBoughtThisMonth;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error calculating dashboard: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isFromSelectedMonth(String billDate) {
    try {
      // If 'all' is selected, show all data
      if (filterType == 'all') {
        return true;
      }

      // Expected format: "dd/MM/yyyy" (e.g., "18/11/2025")
      final parts = billDate.split('/');
      if (parts.length != 3) return false;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final date = DateTime(year, month, day);

      if (filterType == 'range') {
        if (_rangeStartDate == null || _rangeEndDate == null) return false;
        return date.isAfter(
              _rangeStartDate!.subtract(const Duration(days: 1)),
            ) &&
            date.isBefore(_rangeEndDate!.add(const Duration(days: 1)));
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

  Widget _buildTopSellingProductsCard(AppLocalizations? loc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.purple.withOpacity(0.3)
              : Colors.purple.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _expandTopProducts = !_expandTopProducts),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc?.topSellingProducts ?? 'Top Selling Products',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[100] : Colors.grey[800],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_topSellingProducts.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expandTopProducts
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.purple[600],
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expandTopProducts) ...[
            Divider(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _topSellingProducts.isEmpty
                  ? Center(
                      child: Text(
                        loc?.noSalesDataYet ?? 'No sales data yet',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _topSellingProducts.length,
                      separatorBuilder: (_, __) => Divider(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        height: 12,
                      ),
                      itemBuilder: (context, index) {
                        final product = _topSellingProducts[index];
                        final profit =
                            (product['totalProfit'] as num?)?.toInt() ?? 0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${index + 1}. ${product['name']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey[100]
                                          : Colors.grey[800],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${loc?.qty ?? 'Qty'}: ${product['quantity']} • ${loc?.revenue ?? 'Revenue'}: ₹${product['revenue']}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${loc?.profit ?? 'Profit'}: ₹$profit',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: profit >= 0
                                              ? Colors.green[600]
                                              : Colors.red[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingPaymentsCard(AppLocalizations? loc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.orange.withOpacity(0.3)
              : Colors.orange.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(
              () => _expandPendingPayments = !_expandPendingPayments,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc?.pendingPayments ?? 'Pending Payments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[100] : Colors.grey[800],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '₹${_formatCurrency(_totalPendingAmount, loc: AppLocalizations.of(context))}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expandPendingPayments
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.orange[600],
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expandPendingPayments) ...[
            Divider(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _pendingPayments.isEmpty
                  ? Center(
                      child: Text(
                        loc?.noPendingPayments ?? 'No pending payments',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pendingPayments.length,
                      separatorBuilder: (_, __) => Divider(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        height: 12,
                      ),
                      itemBuilder: (context, index) {
                        final payment = _pendingPayments[index];
                        return InkWell(
                          onTap: () => _navigateToBillDetails(payment),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      payment['customerName'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey[100]
                                            : Colors.grey[800],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${loc?.bill ?? 'Bill'}: ₹${payment['totalAmount']} • ${loc?.remaining ?? 'Remaining'}: ₹${payment['amountRemaining']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_expandPendingPayments && _pendingPayments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      AppNavigator.push(context, const PendingPaymentsPage());
                    },
                    icon: const Icon(Icons.visibility, size: 18),
                    label: Text(
                      loc?.viewAllPendingPayments ??
                          'View All Pending Payments',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[600],
                      side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(AppLocalizations? loc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.green.withOpacity(0.3)
              : Colors.green.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc?.availability ?? 'Availability',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey[100] : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc?.currentStockOverview ?? 'Current Stock Overview',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _availableProductsCount.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        loc?.availableProductsCount ?? 'Available\nProducts',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[600],
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.green.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2,
                              color: Colors.green[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc?.totalQuantity ?? 'Total Quantity',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _totalAvailableQty.toString(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.green[600],
                          ),
                        ),
                        Text(
                          loc?.itemsInStock ?? 'items in stock',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.currency_rupee,
                              color: Colors.blue[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc?.totalAmount ?? 'Total Amount',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${_formatCurrency(_totalAvailableAmount.toInt(), loc: AppLocalizations.of(context))}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue[600],
                          ),
                        ),
                        Text(
                          loc?.stockValue ?? 'stock value',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingPaymentsCard(AppLocalizations? loc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.blue.withOpacity(0.3)
              : Colors.blue.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(
              () => _expandUpcomingPayments = !_expandUpcomingPayments,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc?.upcomingPayments ?? 'Upcoming Payments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey[100] : Colors.grey[800],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_upcomingPayments.length} ${loc?.due ?? 'due'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _expandUpcomingPayments
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.blue[600],
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '${loc?.getFullMonthName(DateTime.now().month) ?? getMonthName(DateTime.now().month)} ${DateTime.now().year}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expandUpcomingPayments) ...[
            Divider(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _upcomingPayments.isEmpty
                  ? Center(
                      child: Text(
                        loc?.noUpcomingPayments ?? 'No upcoming payments',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _upcomingPayments.length,
                      separatorBuilder: (_, __) => Divider(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        height: 12,
                      ),
                      itemBuilder: (context, index) {
                        final payment = _upcomingPayments[index];
                        return InkWell(
                          onTap: () => _navigateToBillDetails(payment),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      payment['customerName'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey[100]
                                            : Colors.grey[800],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${loc?.due ?? 'Due'}: ${payment['nextPaymentDate']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '₹${payment['totalAmount']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[600],
                                          ),
                                        ),

                                        const Spacer(),
                                        Text(
                                          '${loc?.remaining ?? 'Remaining'}: ₹${payment['amountRemaining']}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.orange[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderNowCard(AppLocalizations? loc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.red.withOpacity(0.3)
              : Colors.red.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expandOrderNow = !_expandOrderNow),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc?.orderNow ?? 'Order Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[100] : Colors.grey[800],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_orderNowProducts.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expandOrderNow ? Icons.expand_less : Icons.expand_more,
                        color: Colors.red[600],
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expandOrderNow) ...[
            Divider(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _orderNowProducts.isEmpty
                  ? Center(
                      child: Text(
                        loc?.noProductsToOrder ?? 'No products to order',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _orderNowProducts.length,
                      separatorBuilder: (_, __) => Divider(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        height: 12,
                      ),
                      itemBuilder: (context, index) {
                        final product = _orderNowProducts[index];
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['productName'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey[100]
                                          : Colors.grey[800],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${product['supplierName']} • ${product['unit']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                loc?.stock0 ?? 'Stock: 0',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[600],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          // Section 1 Title: Sales & Profit Analysis
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  color: isDark
                                      ? Colors.blue[300]
                                      : Colors.blue[700],
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc?.salesProfitAnalysis ??
                                      'Sales & Profit Analysis',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.grey[100]
                                        : Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.blue.withOpacity(0.6)
                                        : Colors.blue.withOpacity(0.3),
                                    width: isDark ? 1.2 : 1,
                                  ),
                                ),
                                child: Text(
                                  _getMonthYear(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.blue[300]
                                        : Colors.blue[700],
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[750]
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.grey[600]!
                                            : Colors.transparent,
                                        width: isDark ? 1 : 0,
                                      ),
                                    ),
                                    child: PopupMenuButton<String>(
                                      offset: const Offset(0, 40),
                                      itemBuilder: (BuildContext context) => [
                                        PopupMenuItem(
                                          value: 'all',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.all_inclusive,
                                                size: 18,
                                                color: filterType == 'all'
                                                    ? Colors.blue[600]
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                loc?.allData ?? 'All Data',
                                                style: TextStyle(
                                                  fontWeight:
                                                      filterType == 'all'
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: filterType == 'all'
                                                      ? Colors.blue[600]
                                                      : null,
                                                ),
                                              ),
                                              if (filterType == 'all') ...[
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color: Colors.blue[600],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'range',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.date_range,
                                                size: 18,
                                                color: filterType == 'range'
                                                    ? Colors.blue[600]
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                loc?.dateRange ?? 'Date Range',
                                                style: TextStyle(
                                                  fontWeight:
                                                      filterType == 'range'
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: filterType == 'range'
                                                      ? Colors.blue[600]
                                                      : null,
                                                ),
                                              ),
                                              if (filterType == 'range') ...[
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color: Colors.blue[600],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'day',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 18,
                                                color: filterType == 'day'
                                                    ? Colors.blue[600]
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                loc?.day ?? 'Day',
                                                style: TextStyle(
                                                  fontWeight:
                                                      filterType == 'day'
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: filterType == 'day'
                                                      ? Colors.blue[600]
                                                      : null,
                                                ),
                                              ),
                                              if (filterType == 'day') ...[
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color: Colors.blue[600],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'month',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_month,
                                                size: 18,
                                                color: filterType == 'month'
                                                    ? Colors.blue[600]
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                loc?.month ?? 'Month',
                                                style: TextStyle(
                                                  fontWeight:
                                                      filterType == 'month'
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: filterType == 'month'
                                                      ? Colors.blue[600]
                                                      : null,
                                                ),
                                              ),
                                              if (filterType == 'month') ...[
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color: Colors.blue[600],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'year',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_month,
                                                size: 18,
                                                color: filterType == 'year'
                                                    ? Colors.blue[600]
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                loc?.year ?? 'Year',
                                                style: TextStyle(
                                                  fontWeight:
                                                      filterType == 'year'
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: filterType == 'year'
                                                      ? Colors.blue[600]
                                                      : null,
                                                ),
                                              ),
                                              if (filterType == 'year') ...[
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color: Colors.blue[600],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (String newValue) {
                                        setState(() {
                                          filterType = newValue;
                                          _isLoading = true;
                                        });
                                        _saveFilterPreference(newValue);
                                        _loadSalesReport();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.filter_list,
                                              color: Colors.blue[600],
                                              size: 20,
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_drop_down,
                                              color: Colors.blue[600],
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Material(
                                    color: Colors.transparent,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.calendar_today,
                                        color: Colors.blue[600],
                                        size: 22,
                                      ),
                                      onPressed: () =>
                                          _showMonthPicker(context, loc),
                                      style: IconButton.styleFrom(
                                        backgroundColor: isDark
                                            ? Colors.grey[750]
                                            : Colors.white,
                                        side: isDark
                                            ? BorderSide(
                                                color: Colors.grey[600]!,
                                                width: 1,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Two Column Layout
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernCard(
                                  title: loc?.totalSales ?? 'Total Sales',
                                  value:
                                      '₹${_formatCurrency(_totalSales, loc: loc)}',
                                  subtitle:
                                      '${loc?.bills ?? "Bills"}: $_totalSalesCount • ${loc?.items ?? "Items"}: $_totalItemsSold',
                                  backgroundColor: Colors.blue.withOpacity(0.1),
                                  textColor: Colors.blue[700]!,
                                  icon: Icons.trending_up,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModernCard(
                                  title: loc?.totalPurchase ?? 'Total Purchase',
                                  value:
                                      '₹${_formatCurrency(_totalBuying, loc: loc)}',
                                  subtitle:
                                      '${loc?.orders ?? "Orders"}: $_totalBuyingCount • ${loc?.qtyLabel ?? "Qty"}: $_totalQuantityBought',
                                  backgroundColor: Colors.orange.withOpacity(
                                    0.1,
                                  ),
                                  textColor: Colors.orange[700]!,
                                  icon: Icons.shopping_bag,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Profit/Loss Card
                          _buildProfitLossCard(),
                          const SizedBox(height: 12),

                          // Section 2 Title: Inventory & Payments
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.store_outlined,
                                  color: isDark
                                      ? Colors.green[300]
                                      : Colors.green[700],
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc?.inventoryPayments ??
                                          'Inventory & Payments',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.grey[100]
                                            : Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      loc?.liveStatus ?? 'Live status',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Availability Section
                          _buildAvailabilityCard(loc),
                          const SizedBox(height: 12),

                          // Upcoming Payments
                          _buildUpcomingPaymentsCard(loc),
                          const SizedBox(height: 12),

                          // Top Selling Products
                          _buildTopSellingProductsCard(loc),
                          const SizedBox(height: 12),

                          // Pending Payments
                          _buildPendingPaymentsCard(loc),
                          const SizedBox(height: 12),

                          // Order Now
                          _buildOrderNowCard(loc),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required String value,
    required String subtitle,
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? textColor.withOpacity(0.4)
              : textColor.withOpacity(0.2),
          width: isDark ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? textColor.withOpacity(0.15)
                      : textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitLossCard() {
    final isProfitable = _totalProfitLoss >= 0;
    final bgColor = isProfitable ? Colors.green : Colors.red;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? bgColor.withOpacity(0.4) : bgColor.withOpacity(0.2),
          width: isDark ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isProfitable
                    ? loc?.profitLabel ?? 'Profit'
                    : loc?.loss ?? 'Loss',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${_formatCurrency(_totalProfitLoss.abs(), loc: loc)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: bgColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? bgColor.withOpacity(0.15)
                  : bgColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isProfitable ? Icons.trending_up : Icons.trending_down,
              size: 28,
              color: bgColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount, {AppLocalizations? loc}) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}${loc?.currencyLakh ?? ' L'}';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}${loc?.currencyThousand ?? ' K'}';
    }
    return amount.toString();
  }

  void _showMonthPicker(BuildContext context, AppLocalizations? loc) {
    // If range filter is selected, show date range picker
    if (filterType == 'range') {
      showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: _rangeStartDate != null && _rangeEndDate != null
            ? DateTimeRange(start: _rangeStartDate!, end: _rangeEndDate!)
            : null,
      ).then((pickedRange) {
        if (pickedRange != null) {
          setState(() {
            _rangeStartDate = pickedRange.start;
            _rangeEndDate = pickedRange.end;
            _isLoading = true;
          });
          _saveFilterPreference('range');
          _loadSalesReport();
        }
      });
      return;
    }

    // If day filter is selected, show calendar picker instead
    if (filterType == 'day') {
      showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      ).then((pickedDate) {
        if (pickedDate != null) {
          setState(() {
            selectedDate = pickedDate;
            _isLoading = true;
          });
          _loadSalesReport();
        }
      });
      return;
    }

    int selectedYear = selectedDate.year;
    int selectedMonth = selectedDate.month;
    Color primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String dialogTitle = filterType == 'year'
            ? (loc?.selectYear ?? 'Select Year')
            : (loc?.selectMonthYear ?? 'Select Month & Year');

        return AlertDialog(
          title: Text(dialogTitle, style: TextStyle(color: primaryColor)),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year Selector (always shown)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setStateDialog(() {
                              selectedYear--;
                            });
                          },
                        ),
                        Text(
                          selectedYear.toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setStateDialog(() {
                              selectedYear++;
                            });
                          },
                        ),
                      ],
                    ),
                    // Only show month selector if not year filter
                    if (filterType != 'year') ...[
                      const SizedBox(height: 20),
                      // Month Grid
                      GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.5,
                            ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          return InkWell(
                            onTap: () {
                              setStateDialog(() {
                                selectedMonth = index + 1;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: selectedMonth == index + 1
                                    ? Theme.of(context).primaryColor
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selectedMonth == index + 1
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  loc?.getFullMonthName(index + 1) ??
                                      getMonthName(index + 1),
                                  style: TextStyle(
                                    color: selectedMonth == index + 1
                                        ? Colors.white
                                        : null,
                                    fontWeight: selectedMonth == index + 1
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedDate = DateTime(selectedYear, selectedMonth, 1);
                  _isLoading = true;
                });
                Navigator.of(context).pop();
                _loadSalesReport();
              },
              child: Text(loc?.select ?? 'Select'),
            ),
          ],
        );
      },
    );
  }

  String _getMonthYear() {
    final loc = AppLocalizations.of(context);
    if (filterType == 'all') {
      return loc?.allTime ?? 'All Time';
    } else if (filterType == 'range') {
      if (_rangeStartDate != null && _rangeEndDate != null) {
        return '${_rangeStartDate!.day}/${_rangeStartDate!.month}/${_rangeStartDate!.year} - ${_rangeEndDate!.day}/${_rangeEndDate!.month}/${_rangeEndDate!.year}';
      }
      return loc?.selectRange ?? 'Select Range';
    } else if (filterType == 'year') {
      return '${selectedDate.year}';
    } else if (filterType == 'day') {
      return '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
    } else {
      return '${loc?.getFullMonthName(selectedDate.month) ?? getMonthName(selectedDate.month)} ${selectedDate.year}';
    }
  }

  void _navigateToBillDetails(Map<String, dynamic> bill) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Convert bill data to match ViewBillDetailsScreen parameters
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ViewBillDetailsScreen(
            billId: bill['id'] as String,
            billDate: bill['billDate'] as String,
            customerName: bill['customerName'] as String,
            customerMobile: (bill['customerMobile'] ?? 'N/A') as String,
            customerVehicle: bill['customerVehicle'] as String?,
            totalAmount: ((bill['totalAmount'] ?? 0) as num).toInt(),
            totalAmountPaid: (bill['totalAmountPaid'] as bool?) ?? false,
            amountPaid: ((bill['amountPaid'] ?? 0) as num).toInt(),
            amountRemaining:
                (((bill['amountRemaining'] ?? bill['totalAmount'] ?? 0) as num)
                    .toInt()),
            products: bill['products'] != null
                ? (bill['products'] as Map).entries
                      .map(
                        (e) => {
                          'productName':
                              (e.value['productName'] ?? 'Unknown') as String,
                          'quantity': ((e.value['quantity'] ?? 0) as num)
                              .toInt(),
                          'price': ((e.value['price'] ?? 0) as num).toInt(),
                          'boughtPrice': ((e.value['boughtPrice'] ?? 0) as num)
                              .toInt(),
                        },
                      )
                      .toList()
                : null,
            paymentMethod: (bill['paymentMethod'] ?? 'cash') as String,
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to bill details: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening bill details: $e')));
    }
  }
}
