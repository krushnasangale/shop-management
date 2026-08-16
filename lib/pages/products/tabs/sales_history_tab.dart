import 'package:material_ui/material_ui.dart';
import 'package:flashbill/pages/products/tabs/history_ui.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/search_utils.dart';

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
  bool _showSearch = false;
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
        final searchQuery = _searchSalesController.text;
        final customerName = (sale['customerName'] ?? '').toString();

        if (searchQuery.isNotEmpty &&
            !SearchUtils.matchesSubsequence(customerName, searchQuery)) {
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
    Adaptive.showSheet(
      context: context,
      builder: (context) => HistoryOptionSheet(
        title: 'Filter by Customer',
        options: [
          const HistorySheetOption(value: 'all', label: 'All Customers'),
          ..._getUniqueCustomers().map(
            (customer) => HistorySheetOption(value: customer, label: customer),
          ),
        ],
        selected: _filterCustomer,
        onSelected: (value) {
          setState(() => _filterCustomer = value);
          _filterAndSortSoldHistory();
        },
      ),
    );
  }

  void _showSalesSortSheet(BuildContext context) {
    Adaptive.showSheet(
      context: context,
      builder: (context) => HistoryOptionSheet(
        title: 'Sort Sales',
        options: const [
          HistorySheetOption(value: 'date', label: 'Date'),
          HistorySheetOption(value: 'amount', label: 'Amount'),
          HistorySheetOption(value: 'customer', label: 'Customer'),
          HistorySheetOption(value: 'profit', label: 'Profit'),
        ],
        selected: _sortSalesBy,
        onSelected: (value) {
          setState(() => _sortSalesBy = value);
          _filterAndSortSoldHistory();
        },
      ),
    );
  }

  String get _sortLabel => switch (_sortSalesBy) {
    'amount' => 'Amount',
    'customer' => 'Customer',
    'profit' => 'Profit',
    _ => 'Date',
  };

  Widget _buildToolbar(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: Adaptive.compactOutlined,
                  onPressed: () => _showCustomerFilterSheet(context),
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: Text(
                    _filterCustomer == 'all'
                        ? 'All Customers'
                        : _filterCustomer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: Adaptive.compactOutlined,
                  onPressed: () => _showSalesSortSheet(context),
                  icon: const Icon(Icons.sort, size: 16),
                  label: Text(
                    _sortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                style: historyDenseIconButton,
                tooltip: _sortSalesAscending ? 'Ascending' : 'Descending',
                icon: Icon(
                  _sortSalesAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
                onPressed: () {
                  setState(() => _sortSalesAscending = !_sortSalesAscending);
                  _filterAndSortSoldHistory();
                },
              ),
              IconButton(
                style: historyDenseIconButton,
                tooltip: 'Search',
                icon: Icon(_showSearch ? Icons.search_off : Icons.search),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _searchSalesController.clear();
                  });
                },
              ),
            ],
          ),
        ),
        if (_showSearch)
          Adaptive.searchField(
            controller: _searchSalesController,
            hint: 'Search by customer name',
            query: _searchSalesController.text,
          ),
      ],
    );
  }

  Widget _buildSummary(
    BuildContext context,
    Map<String, dynamic> stats,
    Color surfaceColor,
  ) {
    final totalProfit = (stats['totalProfit'] as num).toDouble();
    return Material(
      color: surfaceColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            HistoryMetric(
              label: 'Sales',
              value: stats['totalSales'].toString(),
            ),
            HistoryMetric(
              label: 'Revenue',
              value: '₹${(stats['totalRevenue'] as num).toStringAsFixed(0)}',
            ),
            HistoryMetric(
              label: 'Profit',
              value: '₹${totalProfit.toStringAsFixed(0)}',
              valueColor: totalProfit >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final filtering =
        _searchSalesController.text.isNotEmpty || _filterCustomer != 'all';
    return HistoryEmptyState(
      icon: filtering ? Icons.search_off : Icons.receipt_long_outlined,
      message: filtering ? 'No sales found' : 'No sales yet',
      hint: filtering ? 'Try adjusting your filters' : null,
    );
  }

  Widget _buildSaleRow(
    BuildContext context,
    Map<String, dynamic> sale,
    int index,
    Color surfaceColor,
    bool showDivider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final profitPerUnit =
        ((sale['sellingPrice'] ?? 0) as num).toDouble() -
        ((sale['buyingPrice'] ?? 0) as num).toDouble();
    final totalProfit =
        profitPerUnit * ((sale['quantity'] ?? 0) as num).toDouble();
    final isExpanded = _expandedSoldHistory[index] ?? false;
    final profitMargin = ((sale['buyingPrice'] ?? 0) as num).toDouble() > 0
        ? (profitPerUnit / ((sale['buyingPrice'] ?? 1) as num).toDouble()) * 100
        : 0.0;

    return Material(
      color: surfaceColor,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              _expandedSoldHistory[index] = !isExpanded;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sale['customerName'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${sale['total'] ?? 0}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: mutedColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 13,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sale['date'] ?? 'N/A',
                            style: TextStyle(fontSize: 12, color: mutedColor),
                          ),
                        ],
                      ),
                      Text(
                        [
                          '${sale['quantity']} ${sale['unit'] ?? 'units'}',
                          '${profitMargin.toStringAsFixed(0)}% margin',
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: historyMarginColor(profitMargin),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        HistoryMetric(
                          label: 'Buy',
                          value: '₹${sale['buyingPrice']}',
                        ),
                        HistoryMetric(
                          label: 'Sell',
                          value: '₹${sale['sellingPrice']}',
                        ),
                        HistoryMetric(
                          label: 'Per unit',
                          value: '₹${profitPerUnit.toStringAsFixed(0)}',
                          valueColor: profitPerUnit >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                        HistoryMetric(
                          label: 'Profit',
                          value: '₹${totalProfit.toStringAsFixed(0)}',
                          valueColor: totalProfit >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (profitMargin.clamp(0, 100) / 100),
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(
                          historyMarginColor(profitMargin),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 14,
                          color: mutedColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sale['paymentMethod'] ?? 'N/A',
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateSalesSummaryStats();
    final groupedSales = _groupSalesByDate();
    final surfaceColor = historySurfaceColor(context);

    return Column(
      children: [
        _buildToolbar(context),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                if (widget.soldHistory.isNotEmpty)
                  _buildSummary(context, stats, surfaceColor),
                if (widget.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
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
                        HistoryGroupLabel(
                          label: group.key,
                          count: group.value.length,
                        ),
                        ...group.value.asMap().entries.map((entry) {
                          final index = _filteredSoldHistory.indexOf(
                            entry.value,
                          );
                          return _buildSaleRow(
                            context,
                            entry.value,
                            index,
                            surfaceColor,
                            entry.key != group.value.length - 1,
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
