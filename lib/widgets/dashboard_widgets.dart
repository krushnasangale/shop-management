import 'package:material_ui/material_ui.dart';
import 'package:flashbill/l10n/app_localizations.dart';

Color dashboardSurface(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF171C22)
      : Colors.white;
}

TextStyle dashboardSectionLabel(BuildContext context) {
  return TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

/// A reusable expandable card widget for dashboard components
class ExpandableCard extends StatefulWidget {
  final String title;
  final Color themeColor;
  final String? badgeText;
  final Widget? expandedContent;
  final bool initiallyExpanded;
  final VoidCallback? onExpansionChanged;
  final AppLocalizations? loc;
  final String? subtitle;
  final bool grouped;
  final bool showDivider;

  const ExpandableCard({
    super.key,
    required this.title,
    required this.themeColor,
    this.badgeText,
    this.expandedContent,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.loc,
    this.subtitle,
    this.grouped = false,
    this.showDivider = false,
  });

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() => _isExpanded = !_isExpanded);
            widget.onExpansionChanged?.call();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: widget.subtitle == null ? 28 : 36,
                  decoration: BoxDecoration(
                    color: widget.themeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.badgeText != null) ...[
                  Text(
                    widget.badgeText!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.themeColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded && widget.expandedContent != null)
          widget.expandedContent!,
        if (widget.showDivider)
          const Divider(height: 1, indent: 32, endIndent: 16),
      ],
    );

    if (widget.grouped) return body;

    return Material(color: dashboardSurface(context), child: body);
  }
}

/// A reusable widget for displaying product information in lists
class ProductListItem extends StatelessWidget {
  final int index;
  final String name;
  final int quantity;
  final int revenue;
  final int profit;
  final AppLocalizations? loc;

  const ProductListItem({
    super.key,
    required this.index,
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.profit,
    this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. $name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${loc?.qty ?? 'Qty'}: $quantity  ·  ${loc?.revenue ?? 'Revenue'}: ₹$revenue',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${loc?.profit ?? 'Profit'}: ₹$profit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: profit >= 0 ? Colors.green[600] : Colors.red[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// A reusable widget for displaying metric cards with icons
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: dashboardSurface(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardMetric extends StatelessWidget {
  const DashboardMetric({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

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
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: valueColor ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// A reusable widget for displaying payment information
class PaymentListItem extends StatelessWidget {
  final String customerName;
  final int totalAmount;
  final int remainingAmount;
  final VoidCallback? onTap;
  final AppLocalizations? loc;

  const PaymentListItem({
    super.key,
    required this.customerName,
    required this.totalAmount,
    required this.remainingAmount,
    this.onTap,
    this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${loc?.bill ?? 'Bill'}: ₹$totalAmount  ·  ${loc?.remaining ?? 'Remaining'}: ₹$remainingAmount',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
