import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:material_ui/material_ui.dart';

class BoughtItemReview {
  final String productName;
  final String unit;
  final String? expiryDate;
  final int quantity;
  final double buyingPrice;
  final double sellingPrice;

  BoughtItemReview({
    required this.productName,
    required this.unit,
    this.expiryDate,
    required this.quantity,
    required this.buyingPrice,
    required this.sellingPrice,
  });

  double get total => quantity * buyingPrice;
}

class AddPurchaseReview extends StatefulWidget {
  final String date;
  final String supplierName;
  final List<BoughtItemReview> items;
  final double totalAmount;
  final Future<void> Function() onConfirm;

  const AddPurchaseReview({
    super.key,
    required this.date,
    required this.supplierName,
    required this.items,
    required this.totalAmount,
    required this.onConfirm,
  });

  @override
  State<AddPurchaseReview> createState() => _AddPurchaseReviewState();
}

class _AddPurchaseReviewState extends State<AddPurchaseReview> {
  bool _isLoading = false;

  AppLocalizations get loc => AppLocalizations.of(context)!;

  int get _totalUnits =>
      widget.items.fold(0, (sum, product) => sum + product.quantity);

  Future<void> _confirm() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.errorOccurred}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.reviewPurchaseDetails),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    _SummaryTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: loc.total,
                      value: '₹${_formatAmount(widget.totalAmount)}',
                      valueColor: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    _SummaryTile(
                      icon: Icons.shopping_bag_outlined,
                      label: loc.totalUnits,
                      value: '$_totalUnits',
                    ),
                    const SizedBox(width: 8),
                    _SummaryTile(
                      icon: Icons.inventory_2_outlined,
                      label: loc.products,
                      value: '${widget.items.length}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionLabel(context, loc.purchaseDetails),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Adaptive.fullWidthGroup(
              bordered: true,
              context: context,
              children: [
                _infoTile(
                  icon: Icons.local_shipping_outlined,
                  label: loc.supplier,
                  value: widget.supplierName,
                ),
                _infoTile(
                  icon: Icons.calendar_today_outlined,
                  label: loc.date,
                  value: widget.date,
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _sectionLabel(context, loc.products),
            ),
          ),
          SliverToBoxAdapter(
            child: Adaptive.fullWidthGroup(
              bordered: true,
              context: context,
              children: [
                for (final product in widget.items)
                  _ReviewProductRow(product: product, loc: loc),
              ],
            ),
          ),
          Adaptive.sliverBottomAction(
            child: FilledButton(
              style: Adaptive.compactFilled,
              onPressed: _isLoading ? null : _confirm,
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: Adaptive.progress(color: scheme.onPrimary),
                    )
                  : Text(loc.confirmSave),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      minVerticalPadding: 4,
      leading: _squareIcon(icon, scheme),
      title: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: Text(label),
    );
  }
}

class _ReviewProductRow extends StatelessWidget {
  const _ReviewProductRow({required this.product, required this.loc});

  final BoughtItemReview product;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profit = product.sellingPrice - product.buyingPrice;
    final expiry = product.expiryDate;
    final meta = (expiry != null && expiry.isNotEmpty)
        ? '${loc.expiryDate}: $expiry'
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _squareIcon(Icons.inventory_2_outlined, scheme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '₹${_formatAmount(product.total)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                label: loc.qty,
                value: product.unit.isEmpty
                    ? '${product.quantity}'
                    : '${product.quantity} ${product.unit}',
              ),
              _Metric(
                label: loc.buyingPrice,
                value: '₹${_formatAmount(product.buyingPrice)}',
              ),
              _Metric(
                label: loc.sellingPrice,
                value: '₹${_formatAmount(product.sellingPrice)}',
              ),
              _Metric(
                label: loc.profit,
                value: '${profit >= 0 ? '+' : ''}₹${_formatAmount(profit)}',
                valueColor: profit >= 0 ? scheme.primary : scheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
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
              fontWeight: FontWeight.w700,
              color: valueColor ?? scheme.onSurface,
            ),
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
