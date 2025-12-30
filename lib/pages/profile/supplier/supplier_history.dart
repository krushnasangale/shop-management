// --- Supplier History Screen ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';

class SupplierHistoryScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;
  final String userId;

  const SupplierHistoryScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
    required this.userId,
  });

  @override
  State<SupplierHistoryScreen> createState() => _SupplierHistoryScreenState();
}

class _SupplierHistoryScreenState extends State<SupplierHistoryScreen> {
  late List<Map<String, dynamic>> _supplierHistory;
  bool _isLoading = true;
  double _totalSpent = 0;
  int _totalTransactions = 0;

  @override
  void initState() {
    super.initState();
    _loadSupplierHistory();
  }

  Future<void> _loadSupplierHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(widget.userId)
          .collection('items')
          .get();

      final history = <Map<String, dynamic>>[];
      double totalSpent = 0;

      for (var doc in snapshot.docs) {
        final product = doc.data();

        // Filter by supplier ID
        if (product['supplierId'] == widget.supplierId) {
          final quantity = product['initialQuantity'] ?? 0;
          final buyingPrice = (product['buyingPrice'] ?? 0).toDouble();
          final amount = quantity * buyingPrice;
          totalSpent += amount;

          history.add({
            'id': doc.id,
            'date': product['date'] ?? 'N/A',
            'productName': product['productName'] ?? 'Unknown',
            'quantity': quantity,
            'buyingPrice': buyingPrice,
            'amount': amount,
            'unit': product['unit'] ?? '',
            'batchId': product['batchId'] ?? '',
            'profitMargin': (product['profitMargin'] ?? 0).toDouble(),
          });
        }
      }

      // Sort by date (most recent first)
      history.sort(
        (a, b) => b['date'].toString().compareTo(a['date'].toString()),
      );

      if (mounted) {
        setState(() {
          _supplierHistory = history;
          _totalSpent = totalSpent;
          _totalTransactions = history.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading history: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.supplierName} - History'),
          centerTitle: false,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _supplierHistory.isEmpty
            ? Center(
                child: Text(
                  'No purchase history for this supplier',
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
                                      'Total Transactions',
                                      style: context.subtitleMedium,
                                    ),
                                    Text(
                                      '$_totalTransactions',
                                      style: context.titleLarge?.copyWith(
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
                                      'Total Amount Spent',
                                      style: context.subtitleMedium,
                                    ),
                                    Text(
                                      '₹${_totalSpent.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.green[400],
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
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
                  // History List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _supplierHistory.length,
                      itemBuilder: (context, index) {
                        final transaction = _supplierHistory[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product Name
                                Text(
                                  transaction['productName'],
                                  style: context.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Date, Quantity, Price Row
                                Row(
                                  children: [
                                    Text(
                                      'Date: ',
                                      style: context.bodyLargeText?.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${transaction['date']}  ',
                                      style: context.subtitleMedium?.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'QTY: ',
                                      style: context.bodyLargeText?.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${transaction['quantity']} ${transaction['unit']}',
                                      style: context.subtitleMedium?.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Amount and Buying Price Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '₹${transaction['amount'].toStringAsFixed(2)}',
                                          style: context.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '₹${transaction['buyingPrice']} each',
                                          style: context.subtitleMedium
                                              ?.copyWith(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    // Batch Badges
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        if (transaction['batchId']
                                            .toString()
                                            .isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Batch: ${transaction['batchId'].toString().substring(0, transaction['batchId'].toString().length > 8 ? 8 : transaction['batchId'].toString().length)}...',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.purple,
                                              ),
                                            ),
                                          ),
                                        if (transaction['profitMargin']
                                                as double >
                                            0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '₹${(transaction['profitMargin'] as double).toStringAsFixed(1)}/unit',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green,
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
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
