import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';

class PurchaseHistoryTab extends StatefulWidget {
  final List<Map<String, dynamic>> purchaseHistory;
  final bool isLoading;

  const PurchaseHistoryTab({
    super.key,
    required this.purchaseHistory,
    required this.isLoading,
  });

  @override
  State<PurchaseHistoryTab> createState() => _PurchaseHistoryTabState();
}

class _PurchaseHistoryTabState extends State<PurchaseHistoryTab> {
  List<Map<String, dynamic>> _filteredPurchaseHistory = [];
  final Map<int, bool> _expandedPurchaseHistory = {};

  late TextEditingController _searchController;
  String _sortBy = 'date';
  bool _sortAscending = false;
  String _filterSupplier = 'all';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterAndSortPurchaseHistory);
    _filteredPurchaseHistory = widget.purchaseHistory;
    _filterAndSortPurchaseHistory();
  }

  @override
  void didUpdateWidget(PurchaseHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.purchaseHistory != widget.purchaseHistory) {
      _filterAndSortPurchaseHistory();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterAndSortPurchaseHistory() {
    setState(() {
      _filteredPurchaseHistory = widget.purchaseHistory.where((purchase) {
        final searchQuery = _searchController.text.toLowerCase();
        final supplierName = (purchase['supplierName'] ?? '')
            .toString()
            .toLowerCase();

        if (searchQuery.isNotEmpty && !supplierName.contains(searchQuery)) {
          return false;
        }

        if (_filterSupplier != 'all' &&
            purchase['supplierName'] != _filterSupplier) {
          return false;
        }

        return true;
      }).toList();

      _filteredPurchaseHistory.sort((a, b) {
        int comparison = 0;

        switch (_sortBy) {
          case 'date':
            DateTime dateA =
                DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
            DateTime dateB =
                DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
            comparison = dateA.compareTo(dateB);
            break;
          case 'amount':
            comparison = ((a['total'] ?? 0) as num).compareTo(
              (b['total'] ?? 0) as num,
            );
            break;
          case 'supplier':
            comparison = (a['supplierName'] ?? '').toString().compareTo(
              (b['supplierName'] ?? '').toString(),
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

        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  List<String> _getUniqueSuppliers() {
    final suppliers = widget.purchaseHistory
        .map((p) => (p['supplierName'] ?? 'Unknown').toString())
        .toSet()
        .toList();
    suppliers.sort();
    return suppliers;
  }

  Map<String, List<Map<String, dynamic>>> _groupPurchasesByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();

    for (var purchase in _filteredPurchaseHistory) {
      final date = DateTime.tryParse(purchase['date'] ?? '') ?? DateTime(2000);

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
      grouped[groupKey]!.add(purchase);
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

  Map<String, dynamic> _calculateSummaryStats() {
    if (_filteredPurchaseHistory.isEmpty) {
      return {
        'totalPurchases': 0,
        'totalSpent': 0.0,
        'avgPurchaseValue': 0.0,
        'totalProfit': 0.0,
        'bestSupplier': 'N/A',
      };
    }

    double totalSpent = 0;
    double totalProfit = 0;
    final supplierSpending = <String, double>{};

    for (var purchase in _filteredPurchaseHistory) {
      final cost =
          ((purchase['buyingPrice'] ?? 0) as num) *
          ((purchase['quantity'] ?? 0) as num);
      final profit =
          (((purchase['sellingPrice'] ?? 0) as num) -
              ((purchase['buyingPrice'] ?? 0) as num)) *
          ((purchase['quantity'] ?? 0) as num);

      totalSpent += cost.toDouble();
      totalProfit += profit.toDouble();

      final supplier = (purchase['supplierName'] ?? 'Unknown').toString();
      supplierSpending[supplier] =
          (supplierSpending[supplier] ?? 0) + cost.toDouble();
    }

    String bestSupplier = 'N/A';
    if (supplierSpending.isNotEmpty) {
      bestSupplier = supplierSpending.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return {
      'totalPurchases': _filteredPurchaseHistory.length,
      'totalSpent': totalSpent,
      'avgPurchaseValue': totalSpent / _filteredPurchaseHistory.length,
      'totalProfit': totalProfit,
      'bestSupplier': bestSupplier,
    };
  }

  void _showSupplierFilterSheet(BuildContext context) {
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
                  Icon(Icons.filter_list, color: Colors.blue[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Filter by Supplier',
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
                        _filterSupplier == 'all'
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: _filterSupplier == 'all'
                            ? Colors.blue[600]
                            : Colors.grey,
                      ),
                      title: Text(
                        'All Suppliers',
                        style: TextStyle(
                          fontWeight: _filterSupplier == 'all'
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _filterSupplier = 'all';
                        });
                        _filterAndSortPurchaseHistory();
                        Navigator.pop(context);
                      },
                    ),
                    ..._getUniqueSuppliers().map(
                      (supplier) => ListTile(
                        leading: Icon(
                          _filterSupplier == supplier
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _filterSupplier == supplier
                              ? Colors.blue[600]
                              : Colors.grey,
                        ),
                        title: Text(
                          supplier,
                          style: TextStyle(
                            fontWeight: _filterSupplier == supplier
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _filterSupplier = supplier;
                          });
                          _filterAndSortPurchaseHistory();
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

  void _showPurchaseSortSheet(BuildContext context) {
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
                  Icon(Icons.sort, color: Colors.blue[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Sort Purchases',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1),
            ListTile(
              leading: Icon(
                _sortBy == 'date' ? Icons.check_circle : Icons.circle_outlined,
                color: _sortBy == 'date' ? Colors.blue[600] : Colors.grey,
              ),
              title: Text(
                'Date',
                style: TextStyle(
                  fontWeight: _sortBy == 'date'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortBy = 'date';
                });
                _filterAndSortPurchaseHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortBy == 'amount'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortBy == 'amount' ? Colors.blue[600] : Colors.grey,
              ),
              title: Text(
                'Amount',
                style: TextStyle(
                  fontWeight: _sortBy == 'amount'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortBy = 'amount';
                });
                _filterAndSortPurchaseHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortBy == 'supplier'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortBy == 'supplier' ? Colors.blue[600] : Colors.grey,
              ),
              title: Text(
                'Supplier',
                style: TextStyle(
                  fontWeight: _sortBy == 'supplier'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortBy = 'supplier';
                });
                _filterAndSortPurchaseHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortBy == 'profit'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortBy == 'profit' ? Colors.blue[600] : Colors.grey,
              ),
              title: Text(
                'Profit',
                style: TextStyle(
                  fontWeight: _sortBy == 'profit'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortBy = 'profit';
                });
                _filterAndSortPurchaseHistory();
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
                      colors: [Colors.blue[400]!, Colors.blue[700]!],
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
                  'Summary Statistics',
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
                    stats['totalPurchases'].toString(),
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Spent',
                    '₹${stats['totalSpent'].toStringAsFixed(0)}',
                    Icons.account_balance_wallet,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Profit',
                    '₹${stats['totalProfit'].toStringAsFixed(0)}',
                    Icons.monetization_on,
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
              _searchController.text.isNotEmpty || _filterSupplier != 'all'
                  ? Icons.search_off
                  : Icons.history_outlined,
              color: Colors.grey[400],
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty || _filterSupplier != 'all'
                  ? 'No purchases found'
                  : 'No purchase history yet',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (_searchController.text.isNotEmpty || _filterSupplier != 'all')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Try adjusting your filters',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
                colors: [Colors.blue[400]!, Colors.blue[600]!],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
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
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$itemCount',
              style: TextStyle(
                color: Colors.blue[700],
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

  Widget _buildPurchaseCard(
    BuildContext context,
    Map<String, dynamic> purchase,
    int index,
    bool isDark,
  ) {
    final profitPerUnit =
        ((purchase['sellingPrice'] ?? 0) as num).toDouble() -
        ((purchase['buyingPrice'] ?? 0) as num).toDouble();
    final totalProfit =
        profitPerUnit * ((purchase['quantity'] ?? 0) as num).toDouble();
    final isExpanded = _expandedPurchaseHistory[index] ?? false;
    final profitMargin = ((purchase['buyingPrice'] ?? 0) as num).toDouble() > 0
        ? (profitPerUnit / ((purchase['buyingPrice'] ?? 1) as num).toDouble()) *
              100
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
            _buildPurchaseCardHeader(
              context,
              purchase,
              index,
              isExpanded,
              profitMargin,
              totalProfit,
            ),
            if (isExpanded)
              _buildPurchaseCardDetails(
                context,
                purchase,
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

  Widget _buildPurchaseCardHeader(
    BuildContext context,
    Map<String, dynamic> purchase,
    int index,
    bool isExpanded,
    double profitMargin,
    double totalProfit,
  ) {
    return InkWell(
      onTap: () => setState(() {
        _expandedPurchaseHistory[index] = !isExpanded;
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
                  colors: [Colors.blue[400]!, Colors.blue[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  (purchase['supplierName'] ?? 'U').toString()[0].toUpperCase(),
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
                          purchase['supplierName'] ?? 'Unknown',
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
                        purchase['date'] ?? 'N/A',
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
                        '${purchase['quantity']} ${purchase['unit'] ?? 'units'}',
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
                  '₹${purchase['total'] ?? 0}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue[700],
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
              color: Colors.blue[600],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseCardDetails(
    BuildContext context,
    Map<String, dynamic> purchase,
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
                          '₹${purchase['buyingPrice']}',
                          Icons.shopping_bag_outlined,
                          Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _buildDetailChip(
                          'Sell',
                          '₹${purchase['sellingPrice']}',
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
                      Colors.blue.withOpacity(0.05),
                      Colors.blue.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
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
                                color: Colors.blue[700],
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
                                  ? Colors.blue[700]
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
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        purchase['paymentMethod'] ?? 'N/A',
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

  Widget _buildSearchAndFilterBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by supplier name...',
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
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
                    onTap: () => _showSupplierFilterSheet(context),
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
                              _filterSupplier == 'all'
                                  ? 'All Suppliers'
                                  : _filterSupplier,
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
                    onTap: () => _showPurchaseSortSheet(context),
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
                              _sortBy == 'date'
                                  ? 'Date'
                                  : _sortBy == 'amount'
                                  ? 'Amount'
                                  : _sortBy == 'supplier'
                                  ? 'Supplier'
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
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: Colors.blue[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _sortAscending = !_sortAscending;
                      });
                      _filterAndSortPurchaseHistory();
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

  @override
  Widget build(BuildContext context) {
    final stats = _calculateSummaryStats();
    final groupedPurchases = _groupPurchasesByDate();
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
                if (widget.purchaseHistory.isNotEmpty)
                  _buildSummaryCard(context, stats, cardColor),
                const SizedBox(height: 4),
                if (widget.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_filteredPurchaseHistory.isEmpty)
                  _buildEmptyState(context)
                else
                  ...groupedPurchases.entries.map((group) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGroupHeader(group.key, group.value.length),
                        ...group.value.asMap().entries.map((entry) {
                          final index = _filteredPurchaseHistory.indexOf(
                            entry.value,
                          );
                          return _buildPurchaseCard(
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
