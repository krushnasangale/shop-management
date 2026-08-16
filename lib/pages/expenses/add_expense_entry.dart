import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

class AddExpenseEntry extends StatefulWidget {
  final Map<String, dynamic>? expense;

  const AddExpenseEntry({super.key, this.expense});

  @override
  State<AddExpenseEntry> createState() => _AddExpenseEntryState();
}

class _AddExpenseEntryState extends State<AddExpenseEntry> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _dateController;
  late TextEditingController _amountController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  String _selectedCategory = 'Other';
  String _paymentMethod = 'cash';
  bool _isLoading = false;

  final List<String> _categories = [
    'Office',
    'Travel',
    'Utilities',
    'Food',
    'Hospital',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
    _amountController = TextEditingController();
    _categoryController = TextEditingController();
    _descriptionController = TextEditingController();

    if (widget.expense != null) {
      final expense = widget.expense!;
      _dateController.text = expense['date'] ?? '';
      _amountController.text = expense['amount']?.toString() ?? '';
      _descriptionController.text = expense['description'] ?? '';
      _selectedCategory = expense['category'] ?? 'Other';
      _paymentMethod = expense['paymentMethod'] ?? 'cash';
    } else {
      _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
    _categoryController.text = _selectedCategory;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = AppLocalizations.of(context);
    _categoryController.text = _categoryLabel(_selectedCategory, loc);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    try {
      if (_dateController.text.isNotEmpty) {
        initialDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _selectCategory() async {
    final loc = AppLocalizations.of(context);
    final categories = [
      ..._categories,
      if (!_categories.contains(_selectedCategory)) _selectedCategory,
    ];
    final selected = await Adaptive.showSheet<String>(
      context: context,
      builder: (context) => _CategoryPickerSheet(
        title: loc?.category ?? 'Category',
        cancelLabel: loc?.cancel ?? 'Cancel',
        categories: categories,
        selected: _selectedCategory,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedCategory = selected;
      _categoryController.text = _categoryLabel(selected, loc);
    });
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final amount = double.parse(_amountController.text);
      final parsedDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
      final date = DateFormat('dd/MM/yyyy').format(parsedDate);
      final description = _descriptionController.text.trim();

      final expenseData = <String, dynamic>{
        'date': date,
        'amount': amount,
        'category': _selectedCategory,
        'description': description,
        'paymentMethod': _paymentMethod,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.expense == null) {
        expenseData['createdAt'] = FieldValue.serverTimestamp();
      }

      final expensesRef = FirebaseFirestore.instance
          .collection('expenses')
          .doc(user.uid)
          .collection('entries');

      if (widget.expense != null) {
        await expensesRef.doc(widget.expense!['id']).update(expenseData);
      } else {
        await expensesRef.add(expenseData);
      }

      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.expense != null
                ? (loc?.expenseUpdatedSuccessfully ??
                      'Expense updated successfully')
                : (loc?.expenseAddedSuccessfully ??
                      'Expense added successfully'),
          ),
        ),
      );
      Navigator.pop(context, {
        if (widget.expense != null) 'id': widget.expense!['id'],
        'date': date,
        'amount': amount,
        'category': _selectedCategory,
        'description': description,
        'paymentMethod': _paymentMethod,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isEditing = widget.expense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? (loc?.editExpense ?? 'Edit Expense')
              : (loc?.addExpense ?? 'Add Expense'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Adaptive.box(
                    context: context,
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    decoration: Adaptive.compactField(
                      label: loc?.date ?? 'Date',
                      icon: Icons.calendar_today_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc?.pleaseSelectDate ?? 'Please select date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: Adaptive.compactField(
                      label: loc?.amount ?? 'Amount',
                      hint: '0',
                      icon: Icons.currency_rupee,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc?.pleaseEnterAmount ?? 'Please enter amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return loc?.pleaseEnterValidAmount ??
                            'Please enter valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categoryController,
                    readOnly: true,
                    onTap: _selectCategory,
                    decoration:
                        Adaptive.compactField(
                          label: loc?.category ?? 'Category',
                          icon: Icons.category_outlined,
                        ).copyWith(
                          suffixIcon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: Adaptive.compactIconSize,
                            color: scheme.onSurfaceVariant,
                          ),
                          suffixIconConstraints:
                              Adaptive.compactPrefixConstraints,
                        ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return loc?.pleaseSelectCategory ??
                            'Please select category';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: Adaptive.compactField(
                      label: loc?.description ?? 'Description',
                      icon: Icons.notes_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc?.pleaseEnterDescription ??
                            'Please enter description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    (loc?.paymentMethod ?? 'Payment Method').toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: 'cash',
                          label: Text(loc?.cash ?? 'Cash'),
                        ),
                        ButtonSegment(
                          value: 'online',
                          label: Text(loc?.online ?? 'Online'),
                        ),
                        ButtonSegment(
                          value: 'card',
                          label: Text(loc?.card ?? 'Card'),
                        ),
                      ],
                      selected: {_paymentMethod},
                      onSelectionChanged: (value) {
                        setState(() => _paymentMethod = value.first);
                      },
                    ),
                  ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            Adaptive.sliverBottomAction(
              child: FilledButton(
                style: Adaptive.compactFilled,
                onPressed: _isLoading ? null : _saveExpense,
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: Adaptive.progress(color: scheme.onPrimary),
                      )
                    : Text(loc?.save ?? 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.title,
    required this.cancelLabel,
    required this.categories,
    required this.selected,
  });

  final String title;
  final String cancelLabel;
  final List<String> categories;
  final String selected;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (Adaptive.isCupertino) {
      return CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final category in categories)
            CupertinoActionSheetAction(
              isDefaultAction: category == selected,
              onPressed: () => Navigator.pop(context, category),
              child: Text(_categoryLabel(category, loc)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelLabel),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a category',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Adaptive.box(
              context: context,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    for (var i = 0; i < categories.length; i++) ...[
                      _CategoryTile(
                        category: categories[i],
                        label: _categoryLabel(categories[i], loc),
                        selected: categories[i] == selected,
                        scheme: scheme,
                        onTap: () => Navigator.pop(context, categories[i]),
                      ),
                      if (i != categories.length - 1)
                        const Divider(height: 1, indent: 64),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: Adaptive.compactOutlined.copyWith(
                  minimumSize: const WidgetStatePropertyAll(
                    Size.fromHeight(46),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(cancelLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.label,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final String category;
  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.45),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      minVerticalPadding: 4,
      leading: _squareIcon(_categoryIcon(category), scheme),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      trailing: Icon(
        Icons.check,
        size: 22,
        color: selected ? scheme.primary : Colors.transparent,
      ),
      onTap: onTap,
    );
  }
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

String _categoryLabel(String category, AppLocalizations? loc) {
  switch (category) {
    case 'Office':
      return loc?.office ?? category;
    case 'Travel':
      return loc?.travel ?? category;
    case 'Utilities':
      return loc?.utilities ?? category;
    case 'Food':
      return loc?.food ?? category;
    case 'Hospital':
      return loc?.hospital ?? category;
    case 'Other':
      return loc?.other ?? category;
    default:
      return category;
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Office':
      return Icons.business_outlined;
    case 'Travel':
      return Icons.directions_car_outlined;
    case 'Utilities':
      return Icons.electrical_services_outlined;
    case 'Food':
      return Icons.restaurant_outlined;
    case 'Hospital':
      return Icons.local_hospital_outlined;
    default:
      return Icons.category_outlined;
  }
}
