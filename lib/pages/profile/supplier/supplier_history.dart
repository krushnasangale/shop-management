// --- Supplier History Screen ---
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class SupplierHistoryScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;
  final String userId;

  const SupplierHistoryScreen({super.key, 
    required this.supplierId,
    required this.supplierName,
    required this.userId,
  });

  @override
  State<SupplierHistoryScreen> createState() => _SupplierHistoryScreenState();
}

class _SupplierHistoryScreenState extends State<SupplierHistoryScreen> {
  late DatabaseReference _boughtProductsRef;
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
      _boughtProductsRef = FirebaseDatabase.instance.ref('purchased-products/${widget.userId}');
      final snapshot = await _boughtProductsRef.get();

      final history = <Map<String, dynamic>>[];
      double totalSpent = 0;

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        for (var entry in data.entries) {
          final product = entry.value as Map<dynamic, dynamic>;
          
          // Filter by supplier name (since purchased-products stores supplierName)
          if (product['supplierName'] == widget.supplierName) {
            final quantity = product['quantity'] ?? 0;
            final buyingPrice = (product['buyingPrice'] ?? 0).toDouble();
            final amount = quantity * buyingPrice;
            totalSpent += amount;

            history.add({
              'id': entry.key,
              'date': product['date'] ?? 'N/A',
              'productName': product['productName'] ?? 'Unknown',
              'quantity': quantity,
              'buyingPrice': buyingPrice,
              'amount': amount,
              'unit': product['unit'] ?? '',
            });
          }
        }
      }

      // Sort by date (most recent first)
      history.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

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
                      style: TextStyle(color: secondaryTextColor),
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
                                          style: TextStyle(color: secondaryTextColor),
                                        ),
                                        Text(
                                          '$_totalTransactions',
                                          style: TextStyle(
                                            color: primaryTextColor,
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
                                          style: TextStyle(color: secondaryTextColor),
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
                              child: ListTile(
                                title: Text(transaction['productName']),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      'Date: ',
                                      style: TextStyle(fontSize: 12, color: primaryTextColor),
                                    ),
                                    Text(
                                      '${transaction['date']}  ',
                                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                    ),
                                    Text(
                                      'QTY: ',
                                      style: TextStyle(fontSize: 12, color: primaryTextColor),
                                    ),
                                    Text(
                                      '${transaction['quantity']} ${transaction['unit']}',
                                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                    ),
                                    
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${transaction['amount'].toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    Text(
                                      '₹${transaction['buyingPrice']} each',
                                      style: TextStyle(fontSize: 11, color: secondaryTextColor),
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


