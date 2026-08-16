import 'package:material_ui/material_ui.dart';

/// Shared chrome for the product purchase/sales history tabs so both keep the
/// same flat, full-width look used across purchases and bills.
Color historySurfaceColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF171C22)
      : Colors.white;
}

ButtonStyle get historyDenseIconButton => IconButton.styleFrom(
  minimumSize: const Size(36, 36),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  iconSize: 20,
);

Color historyMarginColor(double margin) {
  if (margin < 0) return Colors.red;
  if (margin < 10) return Colors.orange;
  if (margin < 30) return Colors.amber;
  return Colors.green;
}

class HistoryMetric extends StatelessWidget {
  const HistoryMetric({
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
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryGroupLabel extends StatelessWidget {
  const HistoryGroupLabel({
    super.key,
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        '${label.toUpperCase()}  ·  $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
  });

  final IconData icon;
  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.grey[400], size: 56),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  hint!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HistorySheetOption {
  const HistorySheetOption({required this.value, required this.label});

  final String value;
  final String label;
}

class HistoryOptionSheet extends StatelessWidget {
  const HistoryOptionSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<HistorySheetOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: options.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = option.value == selected;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  selected: isSelected,
                  selectedTileColor: scheme.primary.withValues(alpha: 0.08),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: scheme.primary, size: 20)
                      : null,
                  onTap: () {
                    onSelected(option.value);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
