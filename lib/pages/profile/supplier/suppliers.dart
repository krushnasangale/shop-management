import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/profile/supplier/supplier_history.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flashbill/services/subscription_guard.dart';

class Supplier {
  final String id;
  final String name;
  final String contact;
  final String location;

  Supplier({
    required this.id,
    required this.name,
    required this.contact,
    required this.location,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'contact': contact, 'location': location};
  }

  factory Supplier.fromMap(String id, Map<dynamic, dynamic> data) {
    return Supplier(
      id: id,
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      location: data['location'] ?? '',
    );
  }
}

class Suppliers extends StatefulWidget {
  const Suppliers({super.key});

  @override
  State<Suppliers> createState() => _SuppliersState();
}

class _SuppliersState extends State<Suppliers> {
  String _userId = '';
  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late TextEditingController _searchController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _suppliersSubscription;
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterSuppliers);
    _getUserAndLoadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _suppliersSubscription?.cancel();
    super.dispose();
  }

  List<Supplier> _applyFilter(List<Supplier> suppliers, String query) {
    if (query.isEmpty) return suppliers;
    return suppliers
        .where(
          (supplier) =>
              SearchUtils.matchesSubsequence(supplier.name, query) ||
              SearchUtils.matchesSubsequence(supplier.contact, query) ||
              SearchUtils.matchesSubsequence(supplier.location, query),
        )
        .toList();
  }

  void _filterSuppliers() {
    setState(() {
      _searchQuery = _searchController.text;
      _filteredSuppliers = _applyFilter(_suppliers, _searchQuery);
    });
  }

  void _getUserAndLoadSuppliers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      _loadSuppliersFromDatabase();
    } else {
      setState(() {
        _isLoading = false;
        _suppliers = [];
        _filteredSuppliers = [];
      });
    }
  }

  void _loadSuppliersFromDatabase() {
    _suppliersSubscription = FirebaseFirestore.instance
        .collection('suppliers')
        .doc(_userId)
        .collection('items')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
          if (!mounted) return;

          final loadedSuppliers = snapshot.docs
              .map((doc) => Supplier.fromMap(doc.id, doc.data()))
              .toList();

          loadedSuppliers.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          if (mounted) {
            setState(() {
              _suppliers = loadedSuppliers;
              _filteredSuppliers = _applyFilter(
                loadedSuppliers,
                _searchController.text,
              );
              _isLoading = false;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc?.suppliers ?? 'Suppliers';

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
                  size: 28,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.only(left: 8),
                onPressed: _showAddSupplier,
                child: const Icon(CupertinoIcons.add, size: 32),
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
            icon: Icon(
              _showSearchBar ? Icons.close : Icons.search,
              size: 28,
            ),
            onPressed: _toggleSearch,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, size: 32),
              tooltip: loc?.addSupplier ?? 'Add Supplier',
              onPressed: _showAddSupplier,
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
      if (!_showSearchBar) {
        _searchController.clear();
      }
    });
  }

  Widget _buildBody(AppLocalizations? loc) {
    if (_isLoading) {
      return Center(child: Adaptive.progress());
    }

    return Column(
      children: [
        if (_showSearchBar) _buildSearchField(loc),
        Expanded(
          child: _filteredSuppliers.isEmpty
              ? _EmptyState(
                  message: _searchQuery.isEmpty
                      ? (loc?.noSuppliersYet ??
                            'No suppliers yet. Add one to get started!')
                      : '${loc?.noSuppliersFound ?? 'No suppliers found for'} "$_searchQuery"',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
                  children: [
                    Adaptive.fullWidthGroup(
                      context: context,
                      children: [
                        for (final supplier in _filteredSuppliers)
                          _SupplierTile(
                            supplier: supplier,
                            onOpen: () => _showSupplierHistory(supplier),
                            onHistory: () => _showSupplierHistory(supplier),
                            onEdit: () => _showEditSupplier(supplier),
                            onDelete: () => _confirmDelete(supplier),
                            historyLabel: loc?.history ?? 'History',
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

  Widget _buildSearchField(AppLocalizations? loc) {
    return Adaptive.searchField(
      controller: _searchController,
      hint: loc?.searchSuppliers ?? 'Search Suppliers...',
      query: _searchQuery,
    );
  }

  Future<void> _showAddSupplier() async {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final result = await _showSupplierForm();
    if (result == null || _userId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('suppliers')
        .doc(_userId)
        .collection('items')
        .add(result);
  }

  Future<void> _showEditSupplier(Supplier supplier) async {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final result = await _showSupplierForm(supplier: supplier);
    if (result == null || _userId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('suppliers')
        .doc(_userId)
        .collection('items')
        .doc(supplier.id)
        .update(result);
  }

  Future<Map<String, String>?> _showSupplierForm({Supplier? supplier}) {
    final loc = AppLocalizations.of(context);
    return Adaptive.showSheet<Map<String, String>>(
      context: context,
      builder: (sheetContext) {
        return _SupplierFormSheet(
          title: supplier == null
              ? (loc?.addSupplier ?? 'Add Supplier')
              : (loc?.editSupplier ?? 'Edit Supplier'),
          saveLabel: supplier == null
              ? (loc?.add ?? 'Add')
              : (loc?.save ?? 'Save'),
          cancelLabel: loc?.cancel ?? 'Cancel',
          nameLabel: loc?.supplierName ?? 'Supplier Name',
          nameHint: loc?.enterSupplierName ?? 'Enter Supplier Name',
          contactLabel: loc?.supplierContact ?? 'Supplier Contact',
          contactHint: loc?.enterContactNumber ?? 'Enter Contact Number',
          locationLabel: loc?.supplierLocation ?? 'Supplier Location',
          locationHint: loc?.enterLocation ?? 'Enter Location',
          initialName: supplier?.name ?? '',
          initialContact: supplier?.contact ?? '',
          initialLocation: supplier?.location ?? '',
        );
      },
    );
  }

  void _showSupplierHistory(Supplier supplier) {
    AppNavigator.push(
      context,
      SupplierHistoryScreen(
        supplierId: supplier.id,
        supplierName: supplier.name,
        userId: _userId,
      ),
    );
  }

  Future<void> _confirmDelete(Supplier supplier) async {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final loc = AppLocalizations.of(context);
    final confirmed = await _showDeleteDialog(supplier, loc);
    if (confirmed != true || _userId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('suppliers')
        .doc(_userId)
        .collection('items')
        .doc(supplier.id)
        .delete();
  }

  Future<bool?> _showDeleteDialog(Supplier supplier, AppLocalizations? loc) {
    final title = loc?.deleteSupplier ?? 'Delete Supplier';
    final message =
        '${loc?.confirmDeleteSupplier ?? 'Are you sure you want to delete'} ${supplier.name}?';

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
                child: Text(loc?.cancel ?? 'Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(loc?.delete ?? 'Delete'),
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
              child: Text(loc?.cancel ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(loc?.delete ?? 'Delete'),
            ),
          ],
        );
      },
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  if (parts.isNotEmpty) {
    return parts[0][0].toUpperCase();
  }
  return '?';
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({
    required this.supplier,
    required this.onOpen,
    required this.onHistory,
    required this.onEdit,
    required this.onDelete,
    required this.historyLabel,
    required this.editLabel,
    required this.deleteLabel,
  });

  final Supplier supplier;
  final VoidCallback onOpen;
  final VoidCallback onHistory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String historyLabel;
  final String editLabel;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = [
      if (supplier.contact.isNotEmpty) supplier.contact,
      if (supplier.location.isNotEmpty) supplier.location,
    ].join('  ·  ');
    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: scheme.primaryContainer,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              _initials(supplier.name),
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
        padding: const EdgeInsets.fromLTRB(16, 5, 12, 5),
        leading: avatar,
        title: Text(
          supplier.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
        subtitle: details.isEmpty
            ? null
            : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: _menuButton(),
        onTap: onOpen,
      );
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 1, 12, 1),
      minVerticalPadding: 3,
      leading: avatar,
      title: Text(
        supplier.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: nameStyle,
      ),
      subtitle: details.isEmpty
          ? null
          : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: _menuButton(),
      onTap: onOpen,
    );
  }

  Widget _menuButton() {
    return AppContextMenu.iconButton(
      dense: true,
      width: 168,
      items: () => [
        AppContextMenuItem(
          label: historyLabel,
          icon: CupertinoIcons.clock,
          onPressed: onHistory,
        ),
        AppContextMenuItem(
          label: editLabel,
          icon: CupertinoIcons.pencil,
          onPressed: onEdit,
        ),
        AppContextMenuItem(
          label: deleteLabel,
          icon: CupertinoIcons.delete,
          onPressed: onDelete,
          destructive: true,
        ),
      ],
    );
  }
}

class _SupplierFormSheet extends StatefulWidget {
  const _SupplierFormSheet({
    required this.title,
    required this.saveLabel,
    required this.cancelLabel,
    required this.nameLabel,
    required this.nameHint,
    required this.contactLabel,
    required this.contactHint,
    required this.locationLabel,
    required this.locationHint,
    required this.initialName,
    required this.initialContact,
    required this.initialLocation,
  });

  final String title;
  final String saveLabel;
  final String cancelLabel;
  final String nameLabel;
  final String nameHint;
  final String contactLabel;
  final String contactHint;
  final String locationLabel;
  final String locationHint;
  final String initialName;
  final String initialContact;
  final String initialLocation;

  @override
  State<_SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends State<_SupplierFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _contactController = TextEditingController(text: widget.initialContact);
    _locationController = TextEditingController(text: widget.initialLocation);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final contact = _contactController.text.trim();
    final location = _locationController.text.trim();
    if (name.isEmpty || contact.isEmpty || location.isEmpty) return;

    Navigator.pop(context, {
      'name': name,
      'contact': contact,
      'location': location,
    });
  }

  void _upper(TextEditingController controller) {
    final value = controller.text;
    final upper = value.toUpperCase();
    if (value != upper) {
      controller.value = controller.value.copyWith(
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
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
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
                      controller: _nameController,
                      prefix: Text(widget.nameLabel),
                      placeholder: widget.nameHint,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => _upper(_nameController),
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _contactController,
                      prefix: Text(widget.contactLabel),
                      placeholder: widget.contactHint,
                      keyboardType: TextInputType.phone,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _locationController,
                      prefix: Text(widget.locationLabel),
                      placeholder: widget.locationHint,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => _upper(_locationController),
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
        child: SingleChildScrollView(
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
                controller: _nameController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => _upper(_nameController),
                decoration: Adaptive.compactField(
                  label: widget.nameLabel,
                  hint: widget.nameHint,
                  icon: Icons.storefront_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: Adaptive.compactField(
                  label: widget.contactLabel,
                  hint: widget.contactHint,
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => _upper(_locationController),
                decoration: Adaptive.compactField(
                  label: widget.locationLabel,
                  hint: widget.locationHint,
                  icon: Icons.location_on_outlined,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

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
            Icon(
              Icons.local_shipping_outlined,
              size: 48,
              color: scheme.onSurfaceVariant,
            ),
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
