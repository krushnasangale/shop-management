import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flashbill/pages/helpers/utils.dart';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  DateTime selectedDate = DateTime.now();
  String filterType = 'month'; // 'month', 'year', or 'day'
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

  @override
  void initState() {
    super.initState();
    _loadSalesReport();
  }

  @override
  void dispose() {
    _billsSubscription?.cancel();
    _purchasesSubscription?.cancel();
    _productsSubscription?.cancel();
    super.dispose();
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
          _upcomingPayments = upcomingBills.take(5).toList();
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
                final profitMargin = pValue['profitMargin'] as num?;

                itemsSold += quantity;

                // Use stored profitTotal if available (new batch system), else calculate
                final profitTotal = (pValue['profitTotal'] as num?)?.toInt();
                if (profitTotal != null) {
                  // Use stored profit from batch system (accurate per batch)
                  billProfit += profitTotal;
                } else if (profitMargin != null) {
                  // Use profitMargin if available (backward compatible)
                  final productProfit = (profitMargin * quantity).toInt();
                  billProfit += productProfit;
                } else {
                  // Fallback: calculate from prices (legacy bills)
                  final profitPerUnit = sellingPrice - boughtPrice;
                  final productProfit = profitPerUnit * quantity;
                  billProfit += productProfit;
                }
              }
            });
          }

          // Subtract discount from bill profit
          totalProfit += (billProfit - discount);
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
      // Expected format: "dd/MM/yyyy" (e.g., "18/11/2025")
      final parts = billDate.split('/');
      if (parts.length != 3) return false;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      if (filterType == 'month') {
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

  Widget _buildTopSellingProductsCard() {
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
                    'Top Selling Products',
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
                        'No sales data yet',
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
                                        'Qty: ${product['quantity']} • Revenue: ₹${product['revenue']}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Profit: ₹$profit',
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

  Widget _buildPendingPaymentsCard() {
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
                    'Pending Payments',
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
                          '₹${_formatCurrency(_totalPendingAmount)}',
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
                        'No pending payments',
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
                                      'Bill: ₹${payment['totalAmount']} • Remaining: ₹${payment['amountRemaining']}',
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
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingPaymentsCard() {
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
                        'Upcoming Payments',
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
                              '${_upcomingPayments.length} Due',
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
                    _getMonthYear(),
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
                        'No upcoming payments',
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
                                          'Due: ${payment['nextPaymentDate']}',
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
                                          'Remaining: ₹${payment['amountRemaining']}',
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

  Widget _buildOrderNowCard() {
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
                    'Order Now',
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
                        'No products to order',
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
                                'Stock: 0',
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
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
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
                            'Dashboard',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: primaryTextColor,
                                ),
                          ),
                          const SizedBox(height: 6),
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
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[750]
                                  : Colors.grey[100],
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
                                  value: 'day',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Day'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'month',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Month'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'year',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Year'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (String newValue) {
                                setState(() {
                                  filterType = newValue;
                                  _isLoading = true;
                                });
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
                              onPressed: () => _showMonthPicker(context),
                              style: IconButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.grey[750]
                                    : Colors.grey[100],
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
                ],
              ),
            ),

            // Content
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
                          // Two Column Layout
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernCard(
                                  title: 'Total Sales',
                                  value: '₹${_formatCurrency(_totalSales)}',
                                  subtitle:
                                      'Bills: $_totalSalesCount • Items: $_totalItemsSold',
                                  backgroundColor: Colors.blue.withOpacity(0.1),
                                  textColor: Colors.blue[700]!,
                                  icon: Icons.trending_up,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModernCard(
                                  title: 'Total Purchase',
                                  value: '₹${_formatCurrency(_totalBuying)}',
                                  subtitle:
                                      'Orders: $_totalBuyingCount • Qty: $_totalQuantityBought',
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

                          // Upcoming Payments
                          _buildUpcomingPaymentsCard(),
                          const SizedBox(height: 12),

                          // Top Selling Products
                          _buildTopSellingProductsCard(),
                          const SizedBox(height: 12),

                          // Pending Payments
                          _buildPendingPaymentsCard(),
                          const SizedBox(height: 12),

                          // Order Now
                          _buildOrderNowCard(),
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
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? bgColor.withOpacity(0.4) : bgColor.withOpacity(0.2),
          width: isDark ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isProfitable ? 'Profit' : 'Loss',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${_formatCurrency(_totalProfitLoss.abs())}',
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

  String _formatCurrency(int amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }

  void _showMonthPicker(BuildContext context) {
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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String dialogTitle = filterType == 'year'
            ? 'Select Year'
            : 'Select Month & Year';

        return AlertDialog(
          title: Text(dialogTitle),
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
                                  getMonthName(index + 1).substring(0, 3),
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
              child: const Text('Cancel'),
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
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  String _getMonthYear() {
    if (filterType == 'year') {
      return '${selectedDate.year}';
    } else if (filterType == 'day') {
      return '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
    } else {
      return '${getMonthName(selectedDate.month)} ${selectedDate.year}';
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
