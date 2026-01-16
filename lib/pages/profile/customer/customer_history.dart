// --- Customer History Screen ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';
import 'package:flashbill/l10n/app_localizations.dart';

class CustomerHistoryScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerMobile;
  final String userId;

  const CustomerHistoryScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.customerMobile,
    required this.userId,
  });

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  late List<Map<String, dynamic>> _customerBills;
  bool _isLoading = true;
  double _totalBilledAmount = 0;
  double _totalPaidAmount = 0;
  int _totalBills = 0;

  @override
  void initState() {
    super.initState();
    _loadCustomerBills();
  }

  Future<void> _loadCustomerBills() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .doc(widget.userId)
          .collection('items')
          .get();

      final bills = <Map<String, dynamic>>[];
      double totalBilled = 0;
      double totalPaid = 0;

      for (var doc in snapshot.docs) {
        final bill = doc.data();

        // Filter by customerId
        if (bill['customerId'] == widget.customerId) {
          final billDate = bill['billDate'] as String? ?? 'N/A';
          final totalAmount = ((bill['totalAmount'] ?? 0) as num).toInt();
          final amountPaid = ((bill['amountPaid'] ?? 0) as num).toInt();
          final amountRemaining = ((bill['amountRemaining'] ?? 0) as num)
              .toInt();
          final totalAmountPaid = (bill['totalAmountPaid'] ?? false) as bool;

          totalBilled += totalAmount;
          totalPaid += amountPaid;

          bills.add({
            'id': doc.id,
            'billId': doc.id,
            'date': billDate,
            'billDate': billDate,
            'customerName': widget.customerName,
            'customerMobile': widget.customerMobile,
            'customerVehicle': bill['customerVehicle'] ?? '',
            'totalAmount': totalAmount,
            'amountPaid': amountPaid,
            'amountRemaining': amountRemaining,
            'totalAmountPaid': totalAmountPaid,
            'products': bill['products'] as Map<dynamic, dynamic>? ?? {},
          });
        }
      }

      // Sort by date (most recent first)
      bills.sort(
        (a, b) => b['date'].toString().compareTo(a['date'].toString()),
      );

      if (mounted) {
        setState(() {
          _customerBills = bills;
          _totalBilledAmount = totalBilled;
          _totalPaidAmount = totalPaid;
          _totalBills = bills.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations?.errorLoadingCustomerBills ?? 'Error loading customer bills'}: $e',
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildItemsCountBadge(
    Map<dynamic, dynamic> productsMap,
    AppLocalizations? localizations,
  ) {
    // Count total items/products in the bill
    final productCount = productsMap.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_cart_outlined, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            '$productCount ${productCount == 1 ? (localizations?.item ?? 'Item') : (localizations?.items ?? 'Items')}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitBadge(
    Map<dynamic, dynamic> productsMap,
    AppLocalizations? localizations,
  ) {
    // Calculate total profit from products in the bill
    double totalProfit = 0;

    productsMap.forEach((key, value) {
      if (value is Map) {
        final product = Map<String, dynamic>.from(value);

        // Try to get profitTotal first (batch system)
        final profitTotal = product['profitTotal'] as num?;
        if (profitTotal != null) {
          totalProfit += profitTotal as double;
        } else {
          // Fallback: calculate from profitMargin or manual calculation
          final profitMargin = product['profitMargin'] as num?;
          final quantity = product['quantity'] as num? ?? 1;

          if (profitMargin != null) {
            totalProfit += (profitMargin as double) * (quantity as double);
          } else {
            // Final fallback: calculate from prices
            final sellingPrice = (product['sellingPrice'] as num? ?? 0)
                .toDouble();
            final boughtPrice = (product['boughtPrice'] as num? ?? 0)
                .toDouble();
            final profit = (sellingPrice - boughtPrice) * (quantity as double);
            totalProfit += profit;
          }
        }
      }
    });

    final isProfit = totalProfit >= 0;
    final profitDisplay = totalProfit.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isProfit ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            isProfit ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: isProfit ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            '₹$profitDisplay ${isProfit ? (localizations?.profit ?? 'Profit') : (localizations?.loss ?? 'Loss')}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isProfit ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.customerName} - ${localizations?.bills ?? 'Bills'}',
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customerBills.isEmpty
          ? Center(
              child: Text(
                localizations?.noBillsForThisCustomer ??
                    'No bills for this customer',
                style: context.subtitleMedium,
              ),
            )
          : Column(
              children: [
                // Summary Card
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations?.totalBills ?? 'Total Bills',
                                    style: context.subtitleMedium,
                                  ),
                                  Text(
                                    _totalBills.toString(),
                                    style: context.displayMedium?.copyWith(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    localizations?.totalAmount ??
                                        'Total Amount',
                                    style: context.subtitleMedium,
                                  ),
                                  Text(
                                    '₹ ${_totalBilledAmount.toStringAsFixed(0)}',
                                    style: context.displayMedium?.copyWith(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations?.totalPaid ?? 'Total Paid',
                                    style: TextStyle(
                                      color: Colors.green.shade400,
                                    ),
                                  ),
                                  Text(
                                    '₹ ${_totalPaidAmount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade400,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    localizations?.totalRemaining ??
                                        'Total Remaining',
                                    style: TextStyle(
                                      color: Colors.orange.shade400,
                                    ),
                                  ),
                                  Text(
                                    '₹ ${(_totalBilledAmount - _totalPaidAmount).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bills list
                Expanded(
                  child: ListView.builder(
                    itemCount: _customerBills.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemBuilder: (context, index) {
                      final bill = _customerBills[index];
                      final totalAmount =
                          (bill['totalAmount'] as num?)?.toInt() ?? 0;
                      final amountPaid =
                          (bill['amountPaid'] as num?)?.toInt() ?? 0;
                      final amountRemaining =
                          (bill['amountRemaining'] as num?)?.toInt() ?? 0;
                      final isFullyPaid = bill['totalAmountPaid'] as bool;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            AppNavigator.push(
                              context,
                              ViewBillDetailsScreen(
                                billId: bill['billId'] ?? '',
                                billDate: bill['billDate'] ?? '',
                                customerName: bill['customerName'] ?? '',
                                customerMobile: bill['customerMobile'] ?? '',
                                customerVehicle: bill['customerVehicle'] ?? '',
                                totalAmount: totalAmount,
                                totalAmountPaid: isFullyPaid,
                                amountPaid: amountPaid,
                                amountRemaining: amountRemaining,
                                products: _convertProductsToList(
                                  bill['products'] as Map<dynamic, dynamic>? ??
                                      {},
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${localizations?.billDate ?? 'Bill Date'}: ${bill['date']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isFullyPaid
                                            ? Colors.green.shade100
                                            : amountRemaining == totalAmount
                                            ? Colors.red.shade100
                                            : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isFullyPaid
                                            ? (localizations?.paid ?? 'Paid')
                                            : amountRemaining == totalAmount
                                            ? (localizations?.unpaid ??
                                                  'Unpaid')
                                            : (localizations?.partiallyPaid ??
                                                  'Partial'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isFullyPaid
                                              ? Colors.green.shade700
                                              : amountRemaining == totalAmount
                                              ? Colors.red.shade700
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${localizations?.amount ?? 'Amount'}: ₹ $totalAmount',
                                      style: context.subtitleMedium?.copyWith(
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${localizations?.paidAmount ?? 'Paid'}: ₹ $amountPaid',
                                      style: TextStyle(
                                        color: Colors.green.shade400,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (amountRemaining > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '${localizations?.remaining ?? 'Remaining'}: ₹ $amountRemaining',
                                      style: TextStyle(
                                        color: Colors.orange.shade400,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                // Items count and Profit/Loss badges
                                Row(
                                  children: [
                                    _buildItemsCountBadge(
                                      bill['products']
                                              as Map<dynamic, dynamic>? ??
                                          {},
                                      localizations,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildProfitBadge(
                                      bill['products']
                                              as Map<dynamic, dynamic>? ??
                                          {},
                                      localizations,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  List<Map<String, dynamic>>? _convertProductsToList(
    Map<dynamic, dynamic> productsMap,
  ) {
    if (productsMap.isEmpty) return null;

    final productList = <Map<String, dynamic>>[];
    productsMap.forEach((key, value) {
      if (value is Map) {
        productList.add(Map<String, dynamic>.from(value));
      }
    });

    return productList.isEmpty ? null : productList;
  }
}
