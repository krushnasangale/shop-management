// --- Supplier History Screen ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:intl/intl.dart';
import 'package:flashbill/pages/purchase/purchase_entry_details.dart';

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
  late Map<String, List<Map<String, dynamic>>> _groupedHistory;
  bool _isLoading = true;
  double _totalSpent = 0;
  int _totalTransactions = 0;
  int _totalUnits = 0;
  String _sortBy = 'Recent First';
  final List<String> _sortOptions = [
    'Recent First',
    'Oldest First',
    'Amount: High to Low',
    'Amount: Low to High',
  ];

  @override
  void initState() {
    super.initState();
    _loadSupplierHistory();
  }

  Future<void> _loadSupplierHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('purchases')
          .doc(widget.userId)
          .collection('items')
          .get();

      final history = <Map<String, dynamic>>[];
      double totalSpent = 0;
      int totalUnits = 0;

      for (var doc in snapshot.docs) {
        final purchase = doc.data();

        // Filter by supplier name
        if (purchase['supplierName'] == widget.supplierName) {
          final totalAmount = (purchase['totalAmount'] ?? 0).toDouble();
          final totalQty = (purchase['totalUnits'] as num?)?.toInt() ?? 0;
          totalSpent += totalAmount;
          totalUnits += totalQty;

          history.add({
            'id': doc.id,
            'date': purchase['date'] ?? 'N/A',
            'supplierName': purchase['supplierName'] ?? 'Unknown',
            'totalUnits': totalQty,
            'totalAmount': totalAmount,
            'timestamp': purchase['timestamp'],
            'itemCount': (purchase['items'] as List?)?.length ?? 0,
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
          _totalUnits = totalUnits;
          _groupedHistory = _groupByMonth(history);
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

  Map<String, List<Map<String, dynamic>>> _groupByMonth(
    List<Map<String, dynamic>> history,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var transaction in history) {
      final date = transaction['date'] as String;
      try {
        final parts = date.split('/');
        if (parts.length == 3) {
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final monthYear = DateFormat(
            'MMMM yyyy',
          ).format(DateTime(year, month));

          if (!grouped.containsKey(monthYear)) {
            grouped[monthYear] = [];
          }
          grouped[monthYear]!.add(transaction);
        }
      } catch (e) {
        // If date parsing fails, put in "Unknown" group
        if (!grouped.containsKey('Unknown')) {
          grouped['Unknown'] = [];
        }
        grouped['Unknown']!.add(transaction);
      }
    }
    return grouped;
  }

  void _sortHistory() {
    List<Map<String, dynamic>> sorted = List.from(_supplierHistory);

    switch (_sortBy) {
      case 'Recent First':
        sorted.sort(
          (a, b) => b['date'].toString().compareTo(a['date'].toString()),
        );
        break;
      case 'Oldest First':
        sorted.sort(
          (a, b) => a['date'].toString().compareTo(b['date'].toString()),
        );
        break;
      case 'Amount: High to Low':
        sorted.sort(
          (a, b) => ((b['totalAmount'] ?? 0) as num).toDouble().compareTo(
            ((a['totalAmount'] ?? 0) as num).toDouble(),
          ),
        );
        break;
      case 'Amount: Low to High':
        sorted.sort(
          (a, b) => ((a['totalAmount'] ?? 0) as num).toDouble().compareTo(
            ((b['totalAmount'] ?? 0) as num).toDouble(),
          ),
        );
        break;
    }

    setState(() {
      _supplierHistory = sorted;
      _groupedHistory = _groupByMonth(sorted);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.supplierName}'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort by',
              onSelected: (value) {
                setState(() {
                  _sortBy = value;
                });
                _sortHistory();
              },
              itemBuilder: (context) => _sortOptions.map((option) {
                return PopupMenuItem<String>(
                  value: option,
                  child: Row(
                    children: [
                      if (_sortBy == option)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: isDark
                              ? Colors.blue.shade300
                              : Colors.blue.shade700,
                        ),
                      if (_sortBy == option) const SizedBox(width: 8),
                      Text(
                        option,
                        style: TextStyle(
                          fontWeight: _sortBy == option
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _supplierHistory.isEmpty
          ? _buildEmptyState()
          : CustomScrollView(
              slivers: [
                // Enhanced Summary Card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.blue.shade800, Colors.purple.shade800]
                            : [Colors.blue.shade400, Colors.purple.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.business_center,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Business Summary',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '₹${_totalSpent.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total Invested',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$_totalTransactions Purchases',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Quick Stats Row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildQuickStatCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Items',
                      value: '$_totalUnits',
                      color: Colors.orange,
                      isDark: isDark,
                    ),
                  ),
                ),

                // Grouped History List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final monthYear = _groupedHistory.keys.elementAt(index);
                      final transactions = _groupedHistory[monthYear]!;
                      final monthTotal = transactions.fold<double>(
                        0,
                        (double sum, t) =>
                            sum + ((t['totalAmount'] ?? 0) as num).toDouble(),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Month Header
                          Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  size: 18,
                                  color: isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  monthYear,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.grey.shade200
                                        : Colors.grey.shade800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '₹${monthTotal.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.blue.shade900.withOpacity(0.5)
                                        : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${transactions.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.blue.shade200
                                          : Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Transactions
                          ...transactions.map(
                            (transaction) =>
                                _buildTransactionCard(transaction, isDark),
                          ),
                        ],
                      );
                    }, childCount: _groupedHistory.keys.length),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> purchase, bool isDark) {
    final amount = ((purchase['totalAmount'] ?? 0) as num).toDouble();
    final isHighValue = amount > 10000;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PurchaseEntryDetails(entry: purchase),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighValue
                ? Colors.amber.withOpacity(0.5)
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            width: isHighValue ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Purchase Date and Supplier
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 11,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              purchase['date'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.grey.shade100
                                    : Colors.grey.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: 11,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              purchase['supplierName'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isHighValue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'HIGH',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Divider
              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
              const SizedBox(height: 8),

              // Total Amount and Items Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if ((purchase['itemCount'] ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.purple.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 12,
                                color: Colors.purple.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${purchase['itemCount']} Items',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 12,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${purchase['totalUnits']} Qty',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Purchase History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No transactions found with\nthis supplier yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
