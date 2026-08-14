import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/profile/customer/customer_history.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class Customers extends StatefulWidget {
  const Customers({super.key});

  @override
  State<Customers> createState() => _CustomersState();
}

class _CustomersState extends State<Customers> {
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _customersSubscription;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearchBar = false;
  final ScrollController _scrollController = ScrollController();
  final int _itemsPerPage = 100;
  int _currentlyLoadedItems = 100;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _currentlyLoadedItems = _itemsPerPage.clamp(
          0,
          _filteredCustomers.length,
        );
      });
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _customersSubscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    final totalCustomers = _filteredCustomers.length;
    if (_isLoadingMore || _currentlyLoadedItems >= totalCustomers) return;

    setState(() => _isLoadingMore = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _currentlyLoadedItems = (_currentlyLoadedItems + _itemsPerPage).clamp(
          0,
          totalCustomers,
        );
        _isLoadingMore = false;
      });
    });
  }

  void _loadCustomers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _customersSubscription = FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .collection('items')
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          final customers = snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'name': doc.data()['name'] ?? '',
              'mobileNumber': doc.data()['mobileNumber'] ?? '',
              'vehicleNumber': doc.data()['vehicleNumber'] ?? '',
            };
          }).toList();

          customers.sort(
            (a, b) => a['name'].toString().toLowerCase().compareTo(
              b['name'].toString().toLowerCase(),
            ),
          );

          setState(() {
            _customers = customers;
            _isLoading = false;
            _currentlyLoadedItems = _itemsPerPage.clamp(0, customers.length);
          });
        });
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((customer) {
      final name = customer['name'].toString();
      final mobile = customer['mobileNumber'].toString();
      final vehicle = customer['vehicleNumber'].toString();
      return SearchUtils.matchesSubsequence(name, _searchQuery) ||
          SearchUtils.matchesSubsequence(mobile, _searchQuery) ||
          SearchUtils.matchesSubsequence(vehicle, _searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc?.customers ?? 'Customers';

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
                onPressed: () => _showForm(),
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
              tooltip: loc?.addCustomer ?? 'Add Customer',
              onPressed: () => _showForm(),
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
    final visibleCount = _currentlyLoadedItems.clamp(
      0,
      _filteredCustomers.length,
    );

    return Column(
      children: [
        if (_showSearchBar)
          Adaptive.searchField(
            controller: _searchController,
            query: _searchQuery,
            hint: loc?.searchCustomers ?? 'Search Customers...',
          ),
        Expanded(
          child: _isLoading
              ? Center(child: Adaptive.progress())
              : _filteredCustomers.isEmpty
              ? _EmptyState(
                  icon: Icons.people_outline,
                  message: _searchQuery.isEmpty
                      ? (loc?.noCustomersAddedYet ?? 'No customers added yet')
                      : (loc?.noCustomersFound ?? 'No customers found'),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(0, 4, 8, 16),
                  itemCount: visibleCount + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= visibleCount) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(child: Adaptive.progress()),
                      );
                    }
                    final customer = _filteredCustomers[index];
                    return _CustomerTile(
                      customer: customer,
                      noVehicleLabel: loc?.noVehicle ?? 'No vehicle',
                      onOpen: () => _openHistory(customer),
                      onHistory: () => _openHistory(customer),
                      onEdit: () => _showForm(customer: customer),
                      onDelete: () => _confirmDelete(customer),
                      historyLabel: loc?.history ?? 'History',
                      editLabel: loc?.edit ?? 'Edit',
                      deleteLabel: loc?.delete ?? 'Delete',
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showForm({Map<String, dynamic>? customer}) async {
    final loc = AppLocalizations.of(context);
    final result = await Adaptive.showSheet<Map<String, String>>(
      context: context,
      builder: (sheetContext) {
        return _CustomerFormSheet(
          title: customer == null
              ? (loc?.addCustomer ?? 'Add Customer')
              : (loc?.editCustomer ?? 'Edit Customer'),
          saveLabel: customer == null
              ? (loc?.add ?? 'Add')
              : (loc?.update ?? 'Update'),
          cancelLabel: loc?.cancel ?? 'Cancel',
          nameLabel: loc?.nameRequired ?? 'Name*',
          nameHint: loc?.enterCustomerName ?? 'Enter customer name',
          mobileLabel: loc?.mobileNumberRequired ?? 'Mobile Number*',
          mobileHint: loc?.enterMobileNumber ?? 'Enter mobile number',
          vehicleLabel: loc?.vehicleNumber ?? 'Vehicle Number',
          vehicleHint: loc?.enterVehicleNumber ?? 'Enter vehicle number',
          nameRequired: loc?.nameIsRequired ?? 'Name is required',
          mobileRequired:
              loc?.mobileNumberIsRequired ?? 'Mobile number is required',
          mobileMinLength:
              loc?.mobileNumberMinLength ??
              'Mobile number must be at least 10 digits',
          initialName: customer?['name'] as String? ?? '',
          initialMobile: customer?['mobileNumber'] as String? ?? '',
          initialVehicle: customer?['vehicleNumber'] as String? ?? '',
        );
      },
    );
    if (result == null) return;
    await _saveCustomer(
      result['name']!,
      result['mobile']!,
      result['vehicle']!,
      customerId: customer?['id'] as String?,
    );
  }

  Future<void> _saveCustomer(
    String name,
    String mobileNumber,
    String vehicleNumber, {
    String? customerId,
  }) async {
    final loc = AppLocalizations.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final customerData = {
        'name': name,
        'mobileNumber': mobileNumber,
        'vehicleNumber': vehicleNumber,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      if (customerId != null) {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .collection('items')
            .doc(customerId)
            .update(customerData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loc?.customerUpdatedSuccessfully ??
                    'Customer updated successfully',
              ),
            ),
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .collection('items')
            .add(customerData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loc?.customerAddedSuccessfully ?? 'Customer added successfully',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc?.errorSavingCustomer ?? 'Error saving customer'}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> customer) async {
    final loc = AppLocalizations.of(context);
    final confirmed = Adaptive.isCupertino
        ? await showCupertinoDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return CupertinoAlertDialog(
                title: Text(loc?.deleteCustomer ?? 'Delete Customer'),
                content: Text(
                  loc?.confirmDeleteCustomer ??
                      'Are you sure you want to delete this customer?',
                ),
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
          )
        : await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: Text(loc?.deleteCustomer ?? 'Delete Customer'),
                content: Text(
                  loc?.confirmDeleteCustomer ??
                      'Are you sure you want to delete this customer?',
                ),
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

    if (confirmed == true) {
      await _deleteCustomer(customer['id'] as String);
    }
  }

  Future<void> _deleteCustomer(String customerId) async {
    final loc = AppLocalizations.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .collection('items')
          .doc(customerId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc?.customerDeletedSuccessfully ?? 'Customer deleted successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc?.errorDeletingCustomer ?? 'Error deleting customer'}: $e',
          ),
        ),
      );
    }
  }

  void _openHistory(Map<String, dynamic> customer) {
    AppNavigator.push(
      context,
      CustomerHistoryScreen(
        customerId: customer['id'] as String,
        customerName: customer['name'] as String,
        customerMobile: customer['mobileNumber'] as String,
        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      ),
    );
  }
}

String _customerInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.noVehicleLabel,
    required this.onOpen,
    required this.onHistory,
    required this.onEdit,
    required this.onDelete,
    required this.historyLabel,
    required this.editLabel,
    required this.deleteLabel,
  });

  final Map<String, dynamic> customer;
  final String noVehicleLabel;
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
    final vehicle = (customer['vehicleNumber'] as String).isEmpty
        ? noVehicleLabel
        : customer['vehicleNumber'] as String;
    final details = '${customer['mobileNumber']}  ·  $vehicle';
    final name = customer['name'] as String;
    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: scheme.primaryContainer,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              _customerInitials(name),
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
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
        subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: CupertinoButton(
          padding: const EdgeInsets.only(right: 4),
          onPressed: () => _showCupertinoActions(context),
          child: const Icon(CupertinoIcons.ellipsis),
        ),
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
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: nameStyle,
      ),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton<String>(
        padding: const EdgeInsets.all(8),
        onSelected: (value) {
          switch (value) {
            case 'history':
              onHistory();
            case 'edit':
              onEdit();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'history', child: Text(historyLabel)),
          PopupMenuItem(value: 'edit', child: Text(editLabel)),
          PopupMenuItem(value: 'delete', child: Text(deleteLabel)),
        ],
      ),
      onTap: onOpen,
    );
  }

  Future<void> _showCupertinoActions(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: Text(customer['name'] as String),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                onHistory();
              },
              child: Text(historyLabel),
            ),
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
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }
}

class _CustomerFormSheet extends StatefulWidget {
  const _CustomerFormSheet({
    required this.title,
    required this.saveLabel,
    required this.cancelLabel,
    required this.nameLabel,
    required this.nameHint,
    required this.mobileLabel,
    required this.mobileHint,
    required this.vehicleLabel,
    required this.vehicleHint,
    required this.nameRequired,
    required this.mobileRequired,
    required this.mobileMinLength,
    required this.initialName,
    required this.initialMobile,
    required this.initialVehicle,
  });

  final String title;
  final String saveLabel;
  final String cancelLabel;
  final String nameLabel;
  final String nameHint;
  final String mobileLabel;
  final String mobileHint;
  final String vehicleLabel;
  final String vehicleHint;
  final String nameRequired;
  final String mobileRequired;
  final String mobileMinLength;
  final String initialName;
  final String initialMobile;
  final String initialVehicle;

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _vehicleController;
  String? _nameError;
  String? _mobileError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _mobileController = TextEditingController(text: widget.initialMobile);
    _vehicleController = TextEditingController(text: widget.initialVehicle);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _vehicleController.dispose();
    super.dispose();
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

  void _save() {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    var hasError = false;
    setState(() {
      _nameError = name.isEmpty ? widget.nameRequired : null;
      if (mobile.isEmpty) {
        _mobileError = widget.mobileRequired;
      } else if (mobile.length < 10) {
        _mobileError = widget.mobileMinLength;
      } else {
        _mobileError = null;
      }
      hasError = _nameError != null || _mobileError != null;
    });
    if (hasError) return;

    Navigator.pop(context, {
      'name': name,
      'mobile': mobile,
      'vehicle': _vehicleController.text.trim(),
    });
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
                      controller: _nameController,
                      prefix: Text(widget.nameLabel),
                      placeholder: widget.nameHint,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => _upper(_nameController),
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _mobileController,
                      prefix: Text(widget.mobileLabel),
                      placeholder: widget.mobileHint,
                      keyboardType: TextInputType.phone,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _vehicleController,
                      prefix: Text(widget.vehicleLabel),
                      placeholder: widget.vehicleHint,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      onChanged: (_) => _upper(_vehicleController),
                    ),
                  ],
                ),
                if (_nameError != null || _mobileError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      _nameError ?? _mobileError ?? '',
                      style: const TextStyle(
                        color: CupertinoColors.destructiveRed,
                      ),
                    ),
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
                  icon: Icons.person_outline,
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: Adaptive.compactField(
                  label: widget.mobileLabel,
                  hint: widget.mobileHint,
                  icon: Icons.phone_outlined,
                  errorText: _mobileError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vehicleController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                onChanged: (_) => _upper(_vehicleController),
                decoration: Adaptive.compactField(
                  label: widget.vehicleLabel,
                  hint: widget.vehicleHint,
                  icon: Icons.directions_car_outlined,
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
