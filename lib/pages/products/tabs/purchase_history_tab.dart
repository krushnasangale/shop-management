import 'package:material_ui/material_ui.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/pages/products/tabs/history_ui.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/search_utils.dart';

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
  bool _showSearch = false;
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
        final searchQuery = _searchController.text;
        final supplierName = (purchase['supplierName'] ?? '').toString();

        if (searchQuery.isNotEmpty &&
            !SearchUtils.matchesSubsequence(supplierName, searchQuery)) {
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
        groupKey = 'today';
      } else if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day - 1) {
        groupKey = 'yesterday';
      } else if (now.difference(date).inDays < 7) {
        groupKey = 'this_week';
      } else if (date.year == now.year && date.month == now.month) {
        groupKey = 'this_month';
      } else if (date.year == now.year) {
        groupKey = 'this_year';
      } else {
        groupKey = 'older';
      }

      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(purchase);
    }

    // Return groups in chronological order (most recent first)
    final orderedGroups = <String, List<Map<String, dynamic>>>{};
    final order = [
      'today',
      'yesterday',
      'this_week',
      'this_month',
      'this_year',
      'older',
    ];

    for (var key in order) {
      if (grouped.containsKey(key)) {
        orderedGroups[key] = grouped[key]!;
      }
    }

    return orderedGroups;
  }

  String _localizedGroupLabel(String key, AppLocalizations? loc) {
    return switch (key) {
      'today' => loc?.today ?? 'Today',
      'yesterday' => loc?.yesterday ?? 'Yesterday',
      'this_week' => loc?.thisWeek ?? 'This Week',
      'this_month' => loc?.thisMonth ?? 'This Month',
      'this_year' => loc?.thisYear ?? 'This Year',
      'older' => loc?.older ?? 'Older',
      _ => key,
    };
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
    final loc = AppLocalizations.of(context);
    Adaptive.showSheet(
      context: context,
      builder: (context) => HistoryOptionSheet(
        title: loc?.filterBySupplier ?? 'Filter by Supplier',
        options: [
          HistorySheetOption(
            value: 'all',
            label: loc?.allSuppliers ?? 'All Suppliers',
          ),
          ..._getUniqueSuppliers().map(
            (supplier) => HistorySheetOption(
              value: supplier,
              label: supplier == 'Unknown'
                  ? (loc?.unknown ?? 'Unknown')
                  : supplier,
            ),
          ),
        ],
        selected: _filterSupplier,
        onSelected: (value) {
          setState(() => _filterSupplier = value);
          _filterAndSortPurchaseHistory();
        },
      ),
    );
  }

  void _showPurchaseSortSheet(BuildContext context) {
    final loc = AppLocalizations.of(context);
    Adaptive.showSheet(
      context: context,
      builder: (context) => HistoryOptionSheet(
        title: loc?.sortPurchases ?? 'Sort Purchases',
        options: [
          HistorySheetOption(value: 'date', label: loc?.date ?? 'Date'),
          HistorySheetOption(value: 'amount', label: loc?.amount ?? 'Amount'),
          HistorySheetOption(
            value: 'supplier',
            label: loc?.supplier ?? 'Supplier',
          ),
          HistorySheetOption(value: 'profit', label: loc?.profit ?? 'Profit'),
        ],
        selected: _sortBy,
        onSelected: (value) {
          setState(() => _sortBy = value);
          _filterAndSortPurchaseHistory();
        },
      ),
    );
  }

  String _sortLabel(AppLocalizations? loc) => switch (_sortBy) {
    'amount' => loc?.amount ?? 'Amount',
    'supplier' => loc?.supplier ?? 'Supplier',
    'profit' => loc?.profit ?? 'Profit',
    _ => loc?.date ?? 'Date',
  };

  Widget _buildToolbar(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: Adaptive.compactOutlined,
                  onPressed: () => _showSupplierFilterSheet(context),
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: Text(
                    _filterSupplier == 'all'
                        ? (loc?.allSuppliers ?? 'All Suppliers')
                        : (_filterSupplier == 'Unknown'
                            ? (loc?.unknown ?? 'Unknown')
                            : _filterSupplier),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: Adaptive.compactOutlined,
                  onPressed: () => _showPurchaseSortSheet(context),
                  icon: const Icon(Icons.sort, size: 16),
                  label: Text(
                    _sortLabel(loc),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                style: historyDenseIconButton,
                tooltip: _sortAscending
                    ? (loc?.ascending ?? 'Ascending')
                    : (loc?.descending ?? 'Descending'),
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                onPressed: () {
                  setState(() => _sortAscending = !_sortAscending);
                  _filterAndSortPurchaseHistory();
                },
              ),
              IconButton(
                style: historyDenseIconButton,
                tooltip: loc?.search ?? 'Search',
                icon: Icon(_showSearch ? Icons.search_off : Icons.search),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _searchController.clear();
                  });
                },
              ),
            ],
          ),
        ),
        if (_showSearch)
          Adaptive.searchField(
            controller: _searchController,
            hint: loc?.searchBySupplierName ?? 'Search by supplier name',
            query: _searchController.text,
          ),
      ],
    );
  }

  Widget _buildSummary(
    BuildContext context,
    Map<String, dynamic> stats,
  ) {
    final loc = AppLocalizations.of(context);
    final totalProfit = (stats['totalProfit'] as num).toDouble();
    return Adaptive.box(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            HistoryMetric(
              label: loc?.purchases ?? 'Purchases',
              value: stats['totalPurchases'].toString(),
            ),
            HistoryMetric(
              label: loc?.spent ?? 'Spent',
              value: '₹${(stats['totalSpent'] as num).toStringAsFixed(0)}',
            ),
            HistoryMetric(
              label: loc?.profit ?? 'Profit',
              value: '₹${totalProfit.toStringAsFixed(0)}',
              valueColor: totalProfit >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final filtering =
        _searchController.text.isNotEmpty || _filterSupplier != 'all';
    return HistoryEmptyState(
      icon: filtering ? Icons.search_off : Icons.history_outlined,
      message: filtering
          ? (loc?.noPurchasesFound ?? 'No purchases found')
          : (loc?.noPurchaseHistoryYet ?? 'No purchase history yet'),
      hint: filtering
          ? (loc?.tryAdjustingFilters ?? 'Try adjusting your filters')
          : null,
    );
  }

  Widget _buildPurchaseRow(
    BuildContext context,
    Map<String, dynamic> purchase,
    int index,
    Color surfaceColor,
    bool showDivider,
  ) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? Colors.grey[400] : Colors.grey[600];
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

    return Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              _expandedPurchaseHistory[index] = !isExpanded;
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
                          purchase['supplierName'] ??
                              (loc?.unknown ?? 'Unknown'),
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
                        '₹${purchase['total'] ?? 0}',
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
                            purchase['date'] ?? 'N/A',
                            style: TextStyle(fontSize: 12, color: mutedColor),
                          ),
                        ],
                      ),
                      Text(
                        [
                          '${purchase['quantity']} ${purchase['unit'] ?? 'units'}',
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
                          label: loc?.buy ?? 'Buy',
                          value: '₹${purchase['buyingPrice']}',
                        ),
                        HistoryMetric(
                          label: loc?.sell ?? 'Sell',
                          value: '₹${purchase['sellingPrice']}',
                        ),
                        HistoryMetric(
                          label: loc?.perUnit ?? 'Per unit',
                          value: '₹${profitPerUnit.toStringAsFixed(0)}',
                          valueColor: profitPerUnit >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                        HistoryMetric(
                          label: loc?.profit ?? 'Profit',
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
                          purchase['paymentMethod'] ?? 'N/A',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final stats = _calculateSummaryStats();
    final groupedPurchases = _groupPurchasesByDate();
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
                if (widget.purchaseHistory.isNotEmpty)
                  _buildSummary(context, stats),
                if (widget.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
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
                        HistoryGroupLabel(
                          label: _localizedGroupLabel(group.key, loc),
                          count: group.value.length,
                        ),
                        Adaptive.box(
                          context: context,
                          child: Column(
                            children: [
                              ...group.value.asMap().entries.map((entry) {
                                final index = _filteredPurchaseHistory.indexOf(
                                  entry.value,
                                );
                                return _buildPurchaseRow(
                                  context,
                                  entry.value,
                                  index,
                                  surfaceColor,
                                  entry.key != group.value.length - 1,
                                );
                              }),
                            ],
                          ),
                        ),
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
