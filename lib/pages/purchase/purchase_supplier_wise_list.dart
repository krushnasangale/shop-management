import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/purchase/purchase_entry_details.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:material_ui/material_ui.dart';

class CustomerBillsPage extends StatefulWidget {
  final String supplierName;
  final List<Map<String, dynamic>> bills;

  const CustomerBillsPage({
    super.key,
    required this.supplierName,
    required this.bills,
  });

  @override
  State<CustomerBillsPage> createState() => _CustomerBillsPageState();
}

class _CustomerBillsPageState extends State<CustomerBillsPage> {
  late List<Map<String, dynamic>> _bills;

  @override
  void initState() {
    super.initState();
    _bills = List.from(widget.bills);
    _bills.sort((a, b) {
      final dateA = _asDate(a['timestamp']);
      final dateB = _asDate(b['timestamp']);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final totalAmount = _bills.fold<double>(
      0,
      (total, bill) => total + ((bill['totalAmount'] ?? 0) as num).toDouble(),
    );
    final totalUnits = _bills.fold<int>(
      0,
      (total, bill) => total + ((bill['totalUnits'] ?? 0) as num).toInt(),
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.supplierName)),
      body: _bills.isEmpty
          ? _EmptyState(
              icon: Icons.inventory_2_outlined,
              message: loc?.noPurchasedEntriesYet ?? 'No purchased entries yet',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _SummaryTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: loc?.total ?? 'Total',
                        value: '₹${_formatAmount(totalAmount)}',
                        valueColor: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        icon: Icons.receipt_long_outlined,
                        label: loc?.bills ?? 'Bills',
                        value: '${_bills.length}',
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        icon: Icons.shopping_bag_outlined,
                        label: loc?.totalQuantity ?? 'Qty',
                        value: '$totalUnits',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _sectionLabel(
                    context,
                    loc?.purchasedEntries ?? 'Purchases',
                  ),
                ),
                Adaptive.fullWidthGroup(
                  context: context,
                  children: [
                    for (final entry in _bills)
                      _PurchaseTile(
                        title: (entry['date'] ?? 'N/A').toString(),
                        subtitle: [
                          '${entry['totalProducts'] ?? 0} ${loc?.products ?? 'Products'}',
                          '${entry['totalUnits'] ?? 0} ${loc?.totalQuantity ?? 'Qty'}',
                        ].join('  ·  '),
                        amount: (entry['totalAmount'] ?? 0) as num,
                        onTap: () => AppNavigator.push(
                          context,
                          PurchaseEntryDetails(entry: entry),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final num amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
      minVerticalPadding: 4,
      onTap: onTap,
      leading: _squareIcon(Icons.receipt_long_outlined, scheme),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '₹${_formatAmount(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 24,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _squareIcon(icon, scheme),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _squareIcon(icon, scheme),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionLabel(BuildContext context, String title) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: scheme.onSurfaceVariant,
      ),
    ),
  );
}

Widget _squareIcon(IconData icon, ColorScheme scheme) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: ColoredBox(
      color: scheme.primaryContainer,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
      ),
    ),
  );
}

String _formatAmount(num amount) {
  if (amount == amount.roundToDouble()) return amount.toInt().toString();
  return amount.toStringAsFixed(2);
}
