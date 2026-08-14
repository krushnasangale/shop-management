import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/previous_due_details_page.dart';
import 'package:flashbill/services/bills_data_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:material_ui/material_ui.dart';

class PreviousDuePaymentsPage extends StatefulWidget {
  const PreviousDuePaymentsPage({super.key});

  @override
  State<PreviousDuePaymentsPage> createState() =>
      _PreviousDuePaymentsPageState();
}

class _PreviousDuePaymentsPageState extends State<PreviousDuePaymentsPage> {
  List<Map<String, dynamic>> _previousDuePayments = [];
  List<Map<String, dynamic>> _filteredPayments = [];
  bool _isLoading = true;
  double _totalPreviousDueAmount = 0.0;
  double _totalCollectedAmount = 0.0;
  double _totalPendingAmount = 0.0;
  String _sortBy = 'amount';
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  late BillsDataService _billsDataService;
  StreamSubscription? _billsDataServiceSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBillsDataService();
    _searchController.addListener(_filterPayments);
  }

  void _initializeBillsDataService() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _billsDataService = BillsDataService();
      _billsDataService.initialize(user.uid);
      _billsDataServiceSubscription = _billsDataService.billsStream.listen((_) {
        _loadPreviousDuePayments();
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _billsDataServiceSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreviousDuePayments() async {
    try {
      final cachedBills = _billsDataService.getCachedBills();

      final payments = <Map<String, dynamic>>[];
      double totalPreviousDue = 0.0;
      double totalCollected = 0.0;
      double totalPending = 0.0;

      for (final billData in cachedBills) {
        final previousDueAmount =
            (billData['previousDueAmount'] as num?)?.toDouble() ?? 0.0;

        if (previousDueAmount > 0) {
          final previousPaidAmount =
              (billData['previousPaidAmount'] as num?)?.toDouble() ?? 0.0;
          final isFullyPaid = billData['totalAmountPaid'] ?? false;
          final customerName = billData['customerName'] ?? 'Unknown';
          final billDate = billData['billDate'] ?? '';

          payments.add({
            'billId': billData['id'],
            'customerName': customerName,
            'billDate': billDate,
            'previousDueAmount': previousDueAmount,
            'previousPaidAmount': previousPaidAmount,
            'isFullyPaid': isFullyPaid,
            'totalAmount': billData['totalAmount'] ?? 0,
            'amountPaid': billData['amountPaid'] ?? 0,
            'amountRemaining': billData['amountRemaining'] ?? 0,
          });

          totalPreviousDue += previousDueAmount;
          totalCollected += previousPaidAmount;
          totalPending += previousDueAmount - previousPaidAmount;
        }
      }

      payments.sort(
        (a, b) => (b['billDate'] as String).compareTo(a['billDate'] as String),
      );

      if (mounted) {
        setState(() {
          _previousDuePayments = payments;
          _filteredPayments = payments;
          _totalPreviousDueAmount = totalPreviousDue;
          _totalCollectedAmount = totalCollected;
          _totalPendingAmount = totalPending;
          _isLoading = false;
        });
        _filterPayments();
      }
    } catch (e) {
      appLog('Error loading previous due payments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPayments() {
    final query = _searchController.text;
    setState(() {
      _filteredPayments = _previousDuePayments.where((payment) {
        final customerName = payment['customerName'].toString();
        final matchesSearch = SearchUtils.matchesSubsequence(
          customerName,
          query,
        );

        final status = _getPreviousDueStatus(payment);
        final matchesStatus =
            _statusFilter == 'all' ||
            (_statusFilter == 'paid' && status == 'paid') ||
            (_statusFilter == 'partial' && status == 'partial') ||
            (_statusFilter == 'unpaid' && status == 'unpaid');

        return matchesSearch && matchesStatus;
      }).toList();

      switch (_sortBy) {
        case 'amount':
          _filteredPayments.sort(
            (a, b) => (b['previousDueAmount'] as double).compareTo(
              a['previousDueAmount'] as double,
            ),
          );
          break;
        case 'date':
          _filteredPayments.sort(
            (a, b) =>
                (b['billDate'] as String).compareTo(a['billDate'] as String),
          );
          break;
        case 'name':
          _filteredPayments.sort(
            (a, b) => (a['customerName'] as String).compareTo(
              b['customerName'] as String,
            ),
          );
          break;
      }
    });
  }

  void _navigateToBillDetails(Map<String, dynamic> payment) async {
    await AppNavigator.push(context, PreviousDueDetailsPage(payment: payment));
    _loadPreviousDuePayments();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.previousDuePayments ?? 'Previous Due Payments'),
        actions: [
          IconButton(
            style: Adaptive.compactIconButton,
            icon: Icon(
              _showSearchBar ? CupertinoIcons.xmark : CupertinoIcons.search,
            ),
            tooltip: _showSearchBar
                ? (loc?.closeSearch ?? 'Close Search')
                : (loc?.search ?? 'Search'),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  _filterPayments();
                }
              });
            },
          ),
          AppContextMenu.iconButton(
            icon: Icons.sort,
            tooltip: loc?.sort ?? 'Sort',
            style: Adaptive.compactIconButton,
            items: () => [
              AppContextMenuItem(
                label: loc?.sortByAmount ?? 'Sort by Amount',
                icon: Icons.currency_rupee,
                selected: _sortBy == 'amount',
                onPressed: () {
                  setState(() => _sortBy = 'amount');
                  _filterPayments();
                },
              ),
              AppContextMenuItem(
                label: loc?.sortByDate ?? 'Sort by Date',
                icon: Icons.calendar_today,
                selected: _sortBy == 'date',
                onPressed: () {
                  setState(() => _sortBy = 'date');
                  _filterPayments();
                },
              ),
              AppContextMenuItem(
                label: loc?.sortByName ?? 'Sort by Name',
                icon: Icons.person_outline,
                selected: _sortBy == 'name',
                onPressed: () {
                  setState(() => _sortBy = 'name');
                  _filterPayments();
                },
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _SummaryTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: loc?.total ?? 'Total',
                  value: '₹${_formatCurrency(_totalPreviousDueAmount.toInt())}',
                ),
                const SizedBox(width: 8),
                _SummaryTile(
                  icon: Icons.check_circle_outline,
                  label: loc?.collected ?? 'Collected',
                  value: '₹${_formatCurrency(_totalCollectedAmount.toInt())}',
                  valueColor: scheme.primary,
                ),
                const SizedBox(width: 8),
                _SummaryTile(
                  icon: Icons.schedule_outlined,
                  label: loc?.pending ?? 'Pending',
                  value: '₹${_formatCurrency(_totalPendingAmount.toInt())}',
                  valueColor: scheme.error,
                ),
              ],
            ),
          ),
          if (_showSearchBar)
            Adaptive.searchField(
              controller: _searchController,
              query: _searchController.text,
              hint: loc?.searchCustomers ?? 'Search customers...',
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _statusChip(loc?.all ?? 'All', 'all'),
                  const SizedBox(width: 8),
                  _statusChip(loc?.paid ?? 'Paid', 'paid'),
                  const SizedBox(width: 8),
                  _statusChip(loc?.partial ?? 'Partial', 'partial'),
                  const SizedBox(width: 8),
                  _statusChip(loc?.unpaid ?? 'Unpaid', 'unpaid'),
                ],
              ),
            ),
          ),
          Expanded(child: _buildList(loc, scheme)),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _statusFilter == value,
      onSelected: (_) => _setFilter(value),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  void _setFilter(String value) {
    setState(() {
      _statusFilter = _statusFilter == value && value != 'all' ? 'all' : value;
    });
    _filterPayments();
  }

  Widget _buildList(AppLocalizations? loc, ColorScheme scheme) {
    if (_isLoading) {
      return Center(child: Adaptive.progress());
    }

    if (_filteredPayments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: scheme.primaryContainer,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loc?.noPreviousDuePayments ?? 'No previous due payments found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                loc?.upToDate ?? 'All payments are up to date!',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
      children: [
        Adaptive.fullWidthGroup(
          context: context,
          children: [
            for (final payment in _filteredPayments)
              _PaymentTile(
                payment: payment,
                status: _getPreviousDueStatus(payment),
                statusLabel: _getStatusText(
                  _getPreviousDueStatus(payment),
                  loc,
                ),
                pendingLabel: loc?.pending ?? 'Pending',
                collectedLabel: loc?.collected ?? 'Collected',
                onTap: () => _navigateToBillDetails(payment),
              ),
          ],
        ),
      ],
    );
  }

  String _getPreviousDueStatus(Map<String, dynamic> payment) {
    final previousDueAmount = payment['previousDueAmount'] as double;
    final previousPaidAmount = payment['previousPaidAmount'] as double;

    if (previousPaidAmount == 0) {
      return 'unpaid';
    } else if (previousPaidAmount >= previousDueAmount) {
      return 'paid';
    } else {
      return 'partial';
    }
  }

  String _getStatusText(String status, AppLocalizations? loc) {
    switch (status) {
      case 'paid':
        return loc?.paid ?? 'Paid';
      case 'partial':
        return loc?.partiallyPaid ?? 'Partially Paid';
      case 'unpaid':
        return loc?.unpaid ?? 'Unpaid';
      default:
        return loc?.unknown ?? 'Unknown';
    }
  }

  String _formatCurrency(int amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toString();
    }
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: scheme.primaryContainer,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      icon,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
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

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.status,
    required this.statusLabel,
    required this.pendingLabel,
    required this.collectedLabel,
    required this.onTap,
  });

  final Map<String, dynamic> payment;
  final String status;
  final String statusLabel;
  final String pendingLabel;
  final String collectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = payment['previousDueAmount'] as double;
    final paid = payment['previousPaidAmount'] as double;
    final pending = due - paid;
    final statusColor = status == 'paid'
        ? scheme.primary
        : status == 'unpaid'
        ? scheme.error
        : scheme.onSurfaceVariant;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
      minVerticalPadding: 4,
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: scheme.primaryContainer,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.person_outline,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
      title: Text(
        payment['customerName'],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: Text(
        '${payment['billDate']}  ·  ₹${due.toStringAsFixed(0)}  ·  $collectedLabel ₹${paid.toStringAsFixed(0)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              if (pending > 0)
                Text(
                  '$pendingLabel ₹${pending.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 11, color: scheme.error),
                ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
