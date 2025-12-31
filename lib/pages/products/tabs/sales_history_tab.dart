import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';

class SalesHistoryTab extends StatefulWidget {
  final List<Map<String, dynamic>> soldHistory;
  final bool isLoading;

  const SalesHistoryTab({
    super.key,
    required this.soldHistory,
    required this.isLoading,
  });

  @override
  State<SalesHistoryTab> createState() => _SalesHistoryTabState();
}

class _SalesHistoryTabState extends State<SalesHistoryTab> {
  List<Map<String, dynamic>> _filteredSoldHistory = [];
  final Map<int, bool> _expandedSoldHistory = {};

  late TextEditingController _searchSalesController;
  String _sortSalesBy = 'date';
  bool _sortSalesAscending = false;
  String _filterCustomer = 'all';

  @override
  void initState() {
    super.initState();
    _searchSalesController = TextEditingController();
    _searchSalesController.addListener(_filterAndSortSoldHistory);
    _filteredSoldHistory = widget.soldHistory;
    _filterAndSortSoldHistory();
  }

  @override
  void didUpdateWidget(SalesHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.soldHistory != widget.soldHistory) {
      _filterAndSortSoldHistory();
    }
  }

  @override
  void dispose() {
    _searchSalesController.dispose();
    super.dispose();
  }

  void _filterAndSortSoldHistory() {
    setState(() {
      _filteredSoldHistory = widget.soldHistory.where((sale) {
        final searchQuery = _searchSalesController.text.toLowerCase();
        final customerName = (sale['customerName'] ?? '')
            .toString()
            .toLowerCase();

        if (searchQuery.isNotEmpty && !customerName.contains(searchQuery)) {
          return false;
        }

        if (_filterCustomer != 'all' &&
            sale['customerName'] != _filterCustomer) {
          return false;
        }

        return true;
      }).toList();

      _filteredSoldHistory.sort((a, b) {
        int comparison = 0;

        switch (_sortSalesBy) {
          case 'date':
            final timestampA = a['timestamp'] ?? '';
            final timestampB = b['timestamp'] ?? '';
            comparison = timestampA.compareTo(timestampB);
            break;
          case 'amount':
            comparison = ((a['total'] ?? 0) as num).compareTo(
              (b['total'] ?? 0) as num,
            );
            break;
          case 'customer':
            comparison = (a['customerName'] ?? '').toString().compareTo(
              (b['customerName'] ?? '').toString(),
            );
            break;
          case 'profit':
            final profitA =
                ((a['sellingPrice'] ?? 0) - (a['buyingPrice'] ?? 0)) *
                (a['quantity'] ?? 0);
            final profitB =
                ((b['sellingPrice'] ?? 0) - (b['buyingPrice'] ?? 0)) *
                (b['quantity'] ?? 0);
            comparison = profitA.compareTo(profitB);
            break;
        }

        return _sortSalesAscending ? comparison : -comparison;
      });
    });
  }

  List<String> _getUniqueCustomers() {
    final customers = widget.soldHistory
        .map((s) => (s['customerName'] ?? 'Unknown').toString())
        .toSet()
        .toList();
    customers.sort();
    return customers;
  }

  Map<String, List<Map<String, dynamic>>> _groupSalesByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();

    // Group sales by date categories
    for (var sale in _filteredSoldHistory) {
      DateTime date;
      if (sale['timestamp'] != null &&
          sale['timestamp'].toString().isNotEmpty) {
        date = DateTime.tryParse(sale['timestamp']) ?? DateTime(2000);
      } else if (sale['date'] != null) {
        date = DateTime.tryParse(sale['date']) ?? DateTime(2000);
      } else {
        date = DateTime(2000);
      }

      String groupKey;
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        groupKey = 'Today';
      } else if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day - 1) {
        groupKey = 'Yesterday';
      } else if (now.difference(date).inDays < 7) {
        groupKey = 'This Week';
      } else if (date.year == now.year && date.month == now.month) {
        groupKey = 'This Month';
      } else if (date.year == now.year) {
        groupKey = 'This Year';
      } else {
        groupKey = 'Older';
      }

      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(sale);
    }

    // Return groups in chronological order (most recent first)
    final orderedGroups = <String, List<Map<String, dynamic>>>{};
    final order = [
      'Today',
      'Yesterday',
      'This Week',
      'This Month',
      'This Year',
      'Older',
    ];

    for (var key in order) {
      if (grouped.containsKey(key)) {
        orderedGroups[key] = grouped[key]!;
      }
    }

    return orderedGroups;
  }

  Map<String, dynamic> _calculateSalesSummaryStats() {
    if (_filteredSoldHistory.isEmpty) {
      return {'totalSales': 0, 'totalRevenue': 0.0, 'totalProfit': 0.0};
    }

    double totalRevenue = 0;
    double totalProfit = 0;

    for (var sale in _filteredSoldHistory) {
      final revenue = ((sale['total'] ?? 0) as num).toDouble();
      final profit =
          (((sale['sellingPrice'] ?? 0) as num) -
              ((sale['buyingPrice'] ?? 0) as num)) *
          ((sale['quantity'] ?? 0) as num);

      totalRevenue += revenue;
      totalProfit += profit.toDouble();
    }

    return {
      'totalSales': _filteredSoldHistory.length,
      'totalRevenue': totalRevenue,
      'totalProfit': totalProfit,
    };
  }

  void _showCustomerFilterSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Filter by Customer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        _filterCustomer == 'all'
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: _filterCustomer == 'all'
                            ? Colors.green[600]
                            : Colors.grey,
                      ),
                      title: Text(
                        'All Customers',
                        style: TextStyle(
                          fontWeight: _filterCustomer == 'all'
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _filterCustomer = 'all';
                        });
                        _filterAndSortSoldHistory();
                        Navigator.pop(context);
                      },
                    ),
                    ..._getUniqueCustomers().map(
                      (customer) => ListTile(
                        leading: Icon(
                          _filterCustomer == customer
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _filterCustomer == customer
                              ? Colors.green[600]
                              : Colors.grey,
                        ),
                        title: Text(
                          customer,
                          style: TextStyle(
                            fontWeight: _filterCustomer == customer
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _filterCustomer = customer;
                          });
                          _filterAndSortSoldHistory();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSalesSortSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.sort, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Sort Sales',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1),
            ListTile(
              leading: Icon(
                _sortSalesBy == 'date'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortSalesBy == 'date' ? Colors.green[600] : Colors.grey,
              ),
              title: Text(
                'Date',
                style: TextStyle(
                  fontWeight: _sortSalesBy == 'date'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortSalesBy = 'date';
                });
                _filterAndSortSoldHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortSalesBy == 'amount'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortSalesBy == 'amount'
                    ? Colors.green[600]
                    : Colors.grey,
              ),
              title: Text(
                'Amount',
                style: TextStyle(
                  fontWeight: _sortSalesBy == 'amount'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortSalesBy = 'amount';
                });
                _filterAndSortSoldHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortSalesBy == 'customer'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortSalesBy == 'customer'
                    ? Colors.green[600]
                    : Colors.grey,
              ),
              title: Text(
                'Customer',
                style: TextStyle(
                  fontWeight: _sortSalesBy == 'customer'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortSalesBy = 'customer';
                });
                _filterAndSortSoldHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortSalesBy == 'profit'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortSalesBy == 'profit'
                    ? Colors.green[600]
                    : Colors.grey,
              ),
              title: Text(
                'Profit',
                style: TextStyle(
                  fontWeight: _sortSalesBy == 'profit'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortSalesBy = 'profit';
                });
                _filterAndSortSoldHistory();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      child: Column(
        children: [
          TextField(
            controller: _searchSalesController,
            decoration: InputDecoration(
              hintText: 'Search by customer name...',
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              suffixIcon: _searchSalesController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchSalesController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? Colors.grey[800] : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 35,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showCustomerFilterSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _filterCustomer == 'all'
                                  ? 'All Customers'
                                  : _filterCustomer,
                              style: TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.filter_list,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _showSalesSortSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _sortSalesBy == 'date'
                                  ? 'Date'
                                  : _sortSalesBy == 'amount'
                                  ? 'Amount'
                                  : _sortSalesBy == 'customer'
                                  ? 'Customer'
                                  : 'Profit',
                              style: TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.sort, size: 20, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _sortSalesAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: Colors.green[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _sortSalesAscending = !_sortSalesAscending;
                      });
                      _filterAndSortSoldHistory();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    Map<String, dynamic> stats,
    Color cardColor,
  ) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[400]!, Colors.green[700]!],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Sales Summary',
                  style: context.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total',
                    stats['totalSales'].toString(),
                    Icons.receipt_long,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Revenue',
                    '₹${stats['totalRevenue'].toStringAsFixed(0)}',
                    Icons.attach_money,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Profit',
                    '₹${stats['totalProfit'].toStringAsFixed(0)}',
                    Icons.trending_up,
                    stats['totalProfit'] >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Icon(
              _searchSalesController.text.isNotEmpty || _filterCustomer != 'all'
                  ? Icons.search_off
                  : Icons.receipt_long_outlined,
              color: Colors.grey[400],
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _searchSalesController.text.isNotEmpty || _filterCustomer != 'all'
                  ? 'No sales found'
                  : 'No sales yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String groupKey, int itemCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[600]!],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              groupKey,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$itemCount',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMarginColor(double margin) {
    if (margin < 0) return Colors.red;
    if (margin < 10) return Colors.orange;
    if (margin < 30) return Colors.amber;
    return Colors.green;
  }

  Widget _buildSaleCard(
    BuildContext context,
    Map<String, dynamic> sale,
    int index,
    bool isDark,
  ) {
    final profitPerUnit =
        ((sale['sellingPrice'] ?? 0) as num).toDouble() -
        ((sale['buyingPrice'] ?? 0) as num).toDouble();
    final totalProfit =
        profitPerUnit * ((sale['quantity'] ?? 0) as num).toDouble();
    final isExpanded = _expandedSoldHistory[index] ?? false;
    final profitMargin = ((sale['buyingPrice'] ?? 0) as num).toDouble() > 0
        ? (profitPerUnit / ((sale['buyingPrice'] ?? 1) as num).toDouble()) * 100
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildSaleCardHeader(
              context,
              sale,
              index,
              isExpanded,
              profitMargin,
              totalProfit,
            ),
            if (isExpanded)
              _buildSaleCardDetails(
                context,
                sale,
                isDark,
                profitPerUnit,
                totalProfit,
                profitMargin,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleCardHeader(
    BuildContext context,
    Map<String, dynamic> sale,
    int index,
    bool isExpanded,
    double profitMargin,
    double totalProfit,
  ) {
    return InkWell(
      onTap: () => setState(() {
        _expandedSoldHistory[index] = !isExpanded;
      }),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  (sale['customerName'] ?? 'U').toString()[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sale['customerName'] ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: context.primaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getMarginColor(
                            profitMargin,
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${profitMargin.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _getMarginColor(profitMargin),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 11,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sale['date'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 11,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${sale['quantity']} ${sale['unit'] ?? 'units'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${sale['total'] ?? 0}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: totalProfit >= 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        totalProfit >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 10,
                        color: totalProfit >= 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '₹${totalProfit.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: totalProfit >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.green[600],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleCardDetails(
    BuildContext context,
    Map<String, dynamic> sale,
    bool isDark,
    double profitPerUnit,
    double totalProfit,
    double profitMargin,
  ) {
    return Column(
      children: [
        Divider(color: isDark ? Colors.grey[700] : Colors.grey[200], height: 1),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey[800]?.withOpacity(0.5)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildDetailChip(
                          'Buy',
                          '₹${sale['buyingPrice']}',
                          Icons.shopping_bag_outlined,
                          Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _buildDetailChip(
                          'Sell',
                          '₹${sale['sellingPrice']}',
                          Icons.sell_outlined,
                          Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _buildDetailChip(
                          'Margin',
                          '₹$profitPerUnit',
                          Icons.attach_money,
                          profitPerUnit >= 0 ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Profit Margin',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${profitMargin.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _getMarginColor(profitMargin),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (profitMargin.clamp(0, 100) / 100),
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation(
                              _getMarginColor(profitMargin),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.05),
                      Colors.green.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.monetization_on,
                                size: 16,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Total Profit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${totalProfit.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: totalProfit >= 0
                                  ? Colors.green[700]
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sale['paymentMethod'] ?? 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateSalesSummaryStats();
    final groupedSales = _groupSalesByDate();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;

    return Column(
      children: [
        _buildSearchAndFilterBar(context, isDark),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 10, left: 10, bottom: 8),
            child: Column(
              children: [
                if (widget.soldHistory.isNotEmpty)
                  _buildSummaryCard(context, stats, cardColor),
                const SizedBox(height: 4),
                if (widget.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_filteredSoldHistory.isEmpty)
                  _buildEmptyState(context)
                else
                  ...groupedSales.entries.map((group) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGroupHeader(group.key, group.value.length),
                        ...group.value.asMap().entries.map((entry) {
                          final index = _filteredSoldHistory.indexOf(
                            entry.value,
                          );
                          return _buildSaleCard(
                            context,
                            entry.value,
                            index,
                            isDark,
                          );
                        }),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
