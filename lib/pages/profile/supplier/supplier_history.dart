import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/purchase/purchase_entry_details.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

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
  List<Map<String, dynamic>> _supplierHistory = [];
  Map<String, List<Map<String, dynamic>>> _groupedHistory = {};
  bool _isLoading = true;
  double _totalSpent = 0;
  int _totalTransactions = 0;
  int _totalUnits = 0;
  int _sortByIndex = 0;

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
        if (purchase['supplierName'] != widget.supplierName) continue;

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

      history.sort(
        (a, b) => b['date'].toString().compareTo(a['date'].toString()),
      );

      if (!mounted) return;
      setState(() {
        _supplierHistory = history;
        _totalSpent = totalSpent;
        _totalTransactions = history.length;
        _totalUnits = totalUnits;
        _groupedHistory = _groupByMonth(history);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizations?.errorLoadingHistory ?? 'Error loading history'}: $e',
          ),
        ),
      );
      setState(() => _isLoading = false);
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
          grouped.putIfAbsent(monthYear, () => []).add(transaction);
        }
      } catch (e) {
        grouped.putIfAbsent('Unknown', () => []).add(transaction);
      }
    }
    return grouped;
  }

  void _sortHistory() {
    final sorted = List<Map<String, dynamic>>.from(_supplierHistory);

    switch (_sortByIndex) {
      case 0:
        sorted.sort(
          (a, b) => b['date'].toString().compareTo(a['date'].toString()),
        );
      case 1:
        sorted.sort(
          (a, b) => a['date'].toString().compareTo(b['date'].toString()),
        );
      case 2:
        sorted.sort(
          (a, b) => ((b['totalAmount'] ?? 0) as num).toDouble().compareTo(
            ((a['totalAmount'] ?? 0) as num).toDouble(),
          ),
        );
      case 3:
        sorted.sort(
          (a, b) => ((a['totalAmount'] ?? 0) as num).toDouble().compareTo(
            ((b['totalAmount'] ?? 0) as num).toDouble(),
          ),
        );
    }

    setState(() {
      _supplierHistory = sorted;
      _groupedHistory = _groupByMonth(sorted);
    });
  }

  List<String> _sortOptions(AppLocalizations? loc) => [
    loc?.recentFirst ?? 'Recent First',
    loc?.oldestFirst ?? 'Oldest First',
    loc?.amountHighToLow ?? 'Amount: High to Low',
    loc?.amountLowToHigh ?? 'Amount: Low to High',
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    if (Adaptive.isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(widget.supplierName, overflow: TextOverflow.ellipsis),
          trailing: _sortButton(loc),
        ),
        child: SafeArea(child: _buildBody(loc)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplierName),
        actions: [_sortButton(loc)],
      ),
      body: _buildBody(loc),
    );
  }

  Widget _sortButton(AppLocalizations? loc) {
    const icons = [
      CupertinoIcons.clock,
      CupertinoIcons.clock,
      Icons.currency_rupee,
      Icons.currency_rupee,
    ];
    final options = _sortOptions(loc);
    return AppContextMenu.iconButton(
      icon: Icons.sort,
      tooltip: loc?.sortBy ?? 'Sort by',
      width: 200,
      items: () => [
        for (var i = 0; i < options.length; i++)
          AppContextMenuItem(
            label: options[i],
            icon: icons[i],
            selected: _sortByIndex == i,
            onPressed: () {
              setState(() => _sortByIndex = i);
              _sortHistory();
            },
          ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations? loc) {
    if (_isLoading) {
      return Center(child: Adaptive.progress());
    }
    if (_supplierHistory.isEmpty) {
      return _EmptyState(loc: loc);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SummaryCard(
          totalSpent: _totalSpent,
          purchases: _totalTransactions,
          items: _totalUnits,
          purchasesLabel: loc?.purchases ?? 'Purchases',
          itemsLabel: loc?.items ?? 'Items',
        ),
        const SizedBox(height: 20),
        for (final monthYear in _groupedHistory.keys) ...[
          _MonthHeader(
            title: monthYear,
            total: _groupedHistory[monthYear]!.fold<double>(
              0,
              (total, t) => total + ((t['totalAmount'] ?? 0) as num).toDouble(),
            ),
            count: _groupedHistory[monthYear]!.length,
          ),
          _TransactionGroup(
            transactions: _groupedHistory[monthYear]!,
            qtyLabel: loc?.qty ?? 'Qty',
            onOpen: _openPurchase,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  void _openPurchase(Map<String, dynamic> purchase) {
    AppNavigator.push(context, PurchaseEntryDetails(entry: purchase));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalSpent,
    required this.purchases,
    required this.items,
    required this.purchasesLabel,
    required this.itemsLabel,
  });

  final double totalSpent;
  final int purchases;
  final int items;
  final String purchasesLabel;
  final String itemsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget row(String label, String value, {bool emphasize = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                fontSize: emphasize ? 18 : 15,
              ),
            ),
          ],
        ),
      );
    }

    if (Adaptive.isCupertino) {
      return CupertinoListSection.insetGrouped(
        margin: EdgeInsets.zero,
        header: const Text('BUSINESS SUMMARY'),
        children: [
          CupertinoListTile(
            title: const Text('Total Invested'),
            additionalInfo: Text('₹${totalSpent.toStringAsFixed(2)}'),
          ),
          CupertinoListTile(
            title: Text(purchasesLabel),
            additionalInfo: Text('$purchases'),
          ),
          CupertinoListTile(
            title: Text(itemsLabel),
            additionalInfo: Text('$items'),
          ),
        ],
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          row(
            'Total Invested',
            '₹${totalSpent.toStringAsFixed(2)}',
            emphasize: true,
          ),
          const Divider(height: 1, indent: 16),
          row(purchasesLabel, '$purchases'),
          const Divider(height: 1, indent: 16),
          row(itemsLabel, '$items'),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.title,
    required this.total,
    required this.count,
  });

  final String title;
  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '₹${total.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TransactionGroup extends StatelessWidget {
  const _TransactionGroup({
    required this.transactions,
    required this.qtyLabel,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> transactions;
  final String qtyLabel;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    if (Adaptive.isCupertino) {
      return CupertinoListSection.insetGrouped(
        margin: EdgeInsets.zero,
        children: [
          for (final purchase in transactions)
            _TransactionTile(
              purchase: purchase,
              qtyLabel: qtyLabel,
              onOpen: () => onOpen(purchase),
            ),
        ],
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            _TransactionTile(
              purchase: transactions[i],
              qtyLabel: qtyLabel,
              onOpen: () => onOpen(transactions[i]),
            ),
            if (i != transactions.length - 1)
              const Divider(height: 1, indent: 16),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.purchase,
    required this.qtyLabel,
    required this.onOpen,
  });

  final Map<String, dynamic> purchase;
  final String qtyLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amount = ((purchase['totalAmount'] ?? 0) as num).toDouble();
    final qty = purchase['totalUnits'] ?? 0;
    final date = purchase['date']?.toString() ?? 'N/A';
    final amountText = '₹${amount.toStringAsFixed(2)}';
    final subtitle = '$qty $qtyLabel';

    if (Adaptive.isCupertino) {
      return CupertinoListTile(
        padding: const EdgeInsets.fromLTRB(16, 7, 12, 7),
        title: Text(
          date,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        subtitle: Text(subtitle),
        additionalInfo: Text(amountText),
        trailing: const CupertinoListTileChevron(),
        onTap: onOpen,
      );
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 3, 12, 3),
      title: Text(
        date,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        amountText,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      onTap: onOpen,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loc});

  final AppLocalizations? loc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              loc?.noPurchaseHistory ?? 'No Purchase History',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc?.noTransactionsWithSupplier ??
                  'No transactions found with this supplier yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
