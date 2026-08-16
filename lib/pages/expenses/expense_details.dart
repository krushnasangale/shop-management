import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/expenses/add_expense_entry.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

class ExpenseDetails extends StatefulWidget {
  final Map<String, dynamic> expense;

  const ExpenseDetails({super.key, required this.expense});

  @override
  State<ExpenseDetails> createState() => _ExpenseDetailsState();
}

class _ExpenseDetailsState extends State<ExpenseDetails> {
  late Map<String, dynamic> _expense;

  @override
  void initState() {
    super.initState();
    _expense = Map.from(widget.expense);
  }

  Future<void> _deleteExpense() async {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc?.deleteExpense ?? 'Delete Expense'),
        content: Text(
          loc?.deleteExpenseConfirmation ??
              'Are you sure you want to delete this expense?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: Text(loc?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(user.uid)
          .collection('entries')
          .doc(_expense['id'])
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc?.expenseDeleted ?? 'Expense deleted')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _editExpense() async {
    final updated = await AppNavigator.push<Map<String, dynamic>>(
      context,
      AddExpenseEntry(expense: _expense),
    );
    if (updated != null && mounted) {
      setState(() => _expense = {..._expense, ...updated});
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final date = (_expense['date'] ?? 'N/A').toString();
    final amount = (_expense['amount'] ?? 0) as num;
    final category = (_expense['category'] ?? 'Other').toString();
    final description = (_expense['description'] ?? '').toString();
    final paymentMethod = (_expense['paymentMethod'] ?? 'cash').toString();
    final createdAt = _formatTimestamp(_expense['createdAt']);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.expenseDetails ?? 'Expense Details'),
        actions: [
          AppContextMenu.iconButton(
            width: 168,
            items: () => [
              AppContextMenuItem(
                label: loc?.edit ?? 'Edit',
                icon: CupertinoIcons.pencil,
                onPressed: _editExpense,
              ),
              AppContextMenuItem(
                label: loc?.delete ?? 'Delete',
                icon: CupertinoIcons.delete,
                onPressed: _deleteExpense,
                destructive: true,
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _SummaryTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: loc?.amount ?? 'Amount',
                  value: '₹${_formatAmount(amount)}',
                  valueColor: scheme.error,
                ),
                const SizedBox(width: 8),
                _SummaryTile(
                  icon: Icons.category_outlined,
                  label: loc?.category ?? 'Category',
                  value: category,
                ),
                const SizedBox(width: 8),
                _SummaryTile(
                  icon: _paymentIcon(paymentMethod),
                  label: loc?.paymentMethod ?? 'Payment',
                  value: _paymentLabel(paymentMethod, loc),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _sectionLabel(context, loc?.details ?? 'Details'),
          ),
          Adaptive.fullWidthGroup(
            context: context,
            children: [
              _infoTile(
                icon: Icons.calendar_today_outlined,
                label: loc?.date ?? 'Date',
                value: date,
              ),
              if (description.isNotEmpty)
                _infoTile(
                  icon: Icons.notes_outlined,
                  label: loc?.description ?? 'Description',
                  value: description,
                ),
              if (createdAt != null)
                _infoTile(
                  icon: Icons.schedule_outlined,
                  label: loc?.createdAt ?? 'Created At',
                  value: createdAt,
                ),
            ],
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

  String? _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
    }
    return null;
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

IconData _paymentIcon(String method) {
  switch (method.toLowerCase()) {
    case 'online':
      return Icons.qr_code_outlined;
    case 'card':
      return Icons.credit_card_outlined;
    default:
      return Icons.payments_outlined;
  }
}

String _paymentLabel(String method, AppLocalizations? loc) {
  switch (method.toLowerCase()) {
    case 'online':
      return loc?.online ?? 'Online';
    case 'card':
      return 'Card';
    default:
      return loc?.cash ?? 'Cash';
  }
}
