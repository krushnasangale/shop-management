import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:material_ui/material_ui.dart';

class UnitOfMeasure {
  final String id;
  final String name;

  UnitOfMeasure({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'name': name};

  factory UnitOfMeasure.fromMap(String id, Map<dynamic, dynamic> data) {
    return UnitOfMeasure(id: id, name: data['name'] ?? '');
  }
}

class MeasurementUnitsScreen extends StatefulWidget {
  const MeasurementUnitsScreen({super.key});

  @override
  State<MeasurementUnitsScreen> createState() => _MeasurementUnitsScreenState();
}

class _MeasurementUnitsScreenState extends State<MeasurementUnitsScreen> {
  String _userId = '';
  List<UnitOfMeasure> _units = [];
  List<UnitOfMeasure> _filteredUnits = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late TextEditingController _searchController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _unitsSubscription;
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterUnits);
    _getUserAndLoadUnits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _unitsSubscription?.cancel();
    super.dispose();
  }

  List<UnitOfMeasure> _applyFilter(List<UnitOfMeasure> units, String query) {
    if (query.isEmpty) return units;
    return units
        .where((unit) => SearchUtils.matchesSubsequence(unit.name, query))
        .toList();
  }

  void _filterUnits() {
    setState(() {
      _searchQuery = _searchController.text;
      _filteredUnits = _applyFilter(_units, _searchQuery);
    });
  }

  void _getUserAndLoadUnits() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      _loadUnitsFromDatabase();
    } else {
      setState(() {
        _isLoading = false;
        _units = [];
        _filteredUnits = [];
      });
    }
  }

  void _loadUnitsFromDatabase() {
    _unitsSubscription = FirebaseFirestore.instance
        .collection('units')
        .doc(_userId)
        .collection('items')
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          final loadedUnits = snapshot.docs
              .map((doc) => UnitOfMeasure.fromMap(doc.id, doc.data()))
              .toList();
          loadedUnits.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          setState(() {
            _units = loadedUnits;
            _filteredUnits = _applyFilter(loadedUnits, _searchController.text);
            _isLoading = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc?.measurementUnits ?? 'Measurement Units';

    if (Adaptive.isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _toggleSearch,
                child: Icon(
                  _showSearchBar ? CupertinoIcons.xmark : CupertinoIcons.search,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.only(left: 8),
                onPressed: _showAddUnit,
                child: const Icon(CupertinoIcons.add),
              ),
            ],
          ),
        ),
        child: SafeArea(child: _buildBody(loc)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            style: Adaptive.compactIconButton,
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: IconButton(
              style: Adaptive.compactIconButton,
              icon: const Icon(Icons.add),
              tooltip: loc?.addNewUnit ?? 'Add New Unit',
              onPressed: _showAddUnit,
            ),
          ),
        ],
      ),
      body: _buildBody(loc),
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) _searchController.clear();
    });
  }

  Widget _buildBody(AppLocalizations? loc) {
    if (_isLoading) {
      return Center(child: Adaptive.progress());
    }

    return Column(
      children: [
        if (_showSearchBar)
          Adaptive.searchField(
            controller: _searchController,
            query: _searchQuery,
            hint: loc?.searchUnits ?? 'Search units...',
          ),
        Expanded(
          child: _filteredUnits.isEmpty
              ? _DirectoryEmptyState(
                  icon: Icons.straighten_outlined,
                  message: _searchQuery.isEmpty
                      ? (loc?.noUnitsYet ??
                            'No units yet. Add one to get started!')
                      : '${loc?.noUnitsFound ?? 'No units found for'} "$_searchQuery"',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
                  children: [
                    Adaptive.fullWidthGroup(
                      context: context,
                      children: [
                        for (final unit in _filteredUnits)
                          _UnitTile(
                            unit: unit,
                            onEdit: () => _showEditUnit(unit),
                            onDelete: () => _confirmDelete(unit),
                            editLabel: loc?.edit ?? 'Edit',
                            deleteLabel: loc?.delete ?? 'Delete',
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showAddUnit() async {
    final loc = AppLocalizations.of(context);
    final name = await _showNameSheet(
      title: loc?.addNewUnit ?? 'Add New Unit',
      saveLabel: loc?.add ?? 'Add',
      fieldLabel: loc?.unitNameExample ?? 'Unit Name (e.g., METER, PIECE)',
      fieldHint: loc?.enterUnitName ?? 'Enter unit name',
    );
    if (name == null || name.isEmpty || _userId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('units')
          .doc(_userId)
          .collection('items')
          .add({'name': name});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc?.errorAddingUnit ?? 'Error adding unit'}: $e'),
        ),
      );
    }
  }

  Future<void> _showEditUnit(UnitOfMeasure unit) async {
    final loc = AppLocalizations.of(context);
    final name = await _showNameSheet(
      title: loc?.editUnit ?? 'Edit Unit',
      saveLabel: loc?.save ?? 'Save',
      fieldLabel: loc?.unitNameExample ?? 'Unit Name (e.g., METER, PIECE)',
      fieldHint: loc?.enterUnitName ?? 'Enter unit name',
      initialValue: unit.name,
    );
    if (name == null || name.isEmpty || _userId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('units')
          .doc(_userId)
          .collection('items')
          .doc(unit.id)
          .update({'name': name});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc?.errorUpdatingUnit ?? 'Error updating unit'}: $e',
          ),
        ),
      );
    }
  }

  Future<String?> _showNameSheet({
    required String title,
    required String saveLabel,
    required String fieldLabel,
    required String fieldHint,
    String initialValue = '',
  }) {
    final loc = AppLocalizations.of(context);
    return Adaptive.showSheet<String>(
      context: context,
      builder: (sheetContext) {
        return _NameFormSheet(
          title: title,
          saveLabel: saveLabel,
          cancelLabel: loc?.cancel ?? 'Cancel',
          fieldLabel: fieldLabel,
          fieldHint: fieldHint,
          initialValue: initialValue,
        );
      },
    );
  }

  Future<void> _confirmDelete(UnitOfMeasure unit) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await _confirmDestructive(
      context: context,
      title: loc?.deleteUnit ?? 'Delete Unit',
      message:
          '${loc?.confirmDeleteUnit ?? 'Are you sure you want to remove'} ${unit.name}?',
      confirmLabel: loc?.delete ?? 'Delete',
      cancelLabel: loc?.cancel ?? 'Cancel',
    );
    if (confirmed != true || _userId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('units')
          .doc(_userId)
          .collection('items')
          .doc(unit.id)
          .delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc?.errorDeletingUnit ?? 'Error deleting unit'}: $e',
          ),
        ),
      );
    }
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    required this.unit,
    required this.onEdit,
    required this.onDelete,
    required this.editLabel,
    required this.deleteLabel,
  });

  final UnitOfMeasure unit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editLabel;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: scheme.primaryContainer,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              unit.name.isNotEmpty ? unit.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
    final nameStyle = TextStyle(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    );

    if (Adaptive.isCupertino) {
      return CupertinoListTile(
        padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        leading: avatar,
        title: Text(
          unit.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
        trailing: CupertinoButton(
          padding: const EdgeInsets.only(right: 4),
          onPressed: () => _showCupertinoActions(context),
          child: const Icon(CupertinoIcons.ellipsis),
        ),
        onTap: onEdit,
      );
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
      minVerticalPadding: 4,
      leading: avatar,
      title: Text(
        unit.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: nameStyle,
      ),
      trailing: PopupMenuButton<String>(
        padding: const EdgeInsets.all(8),
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'edit', child: Text(editLabel)),
          PopupMenuItem(value: 'delete', child: Text(deleteLabel)),
        ],
      ),
      onTap: onEdit,
    );
  }

  Future<void> _showCupertinoActions(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: Text(unit.name),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                onEdit();
              },
              child: Text(editLabel),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(sheetContext);
                onDelete();
              },
              child: Text(deleteLabel),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(
              AppLocalizations.of(sheetContext)?.cancel ?? 'Cancel',
            ),
          ),
        );
      },
    );
  }
}

class _NameFormSheet extends StatefulWidget {
  const _NameFormSheet({
    required this.title,
    required this.saveLabel,
    required this.cancelLabel,
    required this.fieldLabel,
    required this.fieldHint,
    required this.initialValue,
  });

  final String title;
  final String saveLabel;
  final String cancelLabel;
  final String fieldLabel;
  final String fieldHint;
  final String initialValue;

  @override
  State<_NameFormSheet> createState() => _NameFormSheetState();
}

class _NameFormSheetState extends State<_NameFormSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }

  void _upper() {
    final value = _controller.text;
    final upper = value.toUpperCase();
    if (value != upper) {
      _controller.value = _controller.value.copyWith(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    if (Adaptive.isCupertino) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Material(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoNavigationBar(
                  automaticallyImplyLeading: false,
                  middle: Text(widget.title),
                  leading: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Text(widget.cancelLabel),
                  ),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _save,
                    child: Text(widget.saveLabel),
                  ),
                ),
                CupertinoFormSection.insetGrouped(
                  children: [
                    CupertinoTextFormFieldRow(
                      controller: _controller,
                      prefix: Text(widget.fieldLabel),
                      placeholder: widget.fieldHint,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => _upper(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => _upper(),
                decoration: Adaptive.compactField(
                  label: widget.fieldLabel,
                  hint: widget.fieldHint,
                  icon: Icons.straighten_outlined,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: Adaptive.compactOutlined,
                      child: Text(widget.cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: Adaptive.compactFilled,
                      child: Text(widget.saveLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryEmptyState extends StatelessWidget {
  const _DirectoryEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmDestructive({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) {
  if (Adaptive.isCupertino) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}
