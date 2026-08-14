import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';
import 'package:flashbill/services/bills_data_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:material_ui/material_ui.dart';

class PendingPaymentsPage extends StatefulWidget {
  const PendingPaymentsPage({super.key});

  @override
  State<PendingPaymentsPage> createState() => _PendingPaymentsPageState();
}

class _PendingPaymentsPageState extends State<PendingPaymentsPage> {
  List<Map<String, dynamic>> _pendingPayments = [];
  List<Map<String, dynamic>> _filteredPayments = [];
  bool _isLoading = true;
  int _totalAmount = 0;
  int _totalCollectedAmount = 0;
  int _totalPendingAmount = 0;
  String _sortBy = 'amount';
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  late BillsDataService _billsDataService;
  StreamSubscription? _billsDataServiceSubscription;
  bool _showSearchBar = false;

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
        _loadPendingPayments();
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

  Future<void> _loadPendingPayments() async {
    try {
      final cachedBills = _billsDataService.getCachedBills();

      final pendingBills = <Map<String, dynamic>>[];
      var totalAmount = 0;
      var totalCollected = 0;
      var totalPending = 0;

      for (final billData in cachedBills) {
        final totalAmountPaid = billData['totalAmountPaid'] as bool? ?? false;

        if (!totalAmountPaid) {
          final amountRemaining =
              (billData['amountRemaining'] as num?)?.toInt() ?? 0;

          if (amountRemaining > 0) {
            final billTotal = (billData['totalAmount'] as num?)?.toInt() ?? 0;
            final amountPaid = (billData['amountPaid'] as num?)?.toInt() ?? 0;

            pendingBills.add({
              'id': billData['id'],
              'customerName': billData['customerName'] ?? 'Unknown',
              'customerMobile': billData['customerMobile'] ?? 'N/A',
              'customerVehicle': billData['customerVehicle'],
              'billDate': billData['billDate'] ?? 'N/A',
              'amountRemaining': amountRemaining,
              'totalAmount': billTotal,
              'totalAmountPaid': false,
              'amountPaid': amountPaid,
              'products': billData['products'],
              'paymentMethod': billData['paymentMethod'] ?? 'cash',
              'previousDueAmount': billData['previousDueAmount'] ?? 0,
              'previousDueDescription':
                  billData['previousDueDescription'] ?? '',
            });
            totalAmount += billTotal;
            totalCollected += amountPaid;
            totalPending += amountRemaining;
          }
        }
      }

      if (mounted) {
        setState(() {
          _pendingPayments = pendingBills;
          _filteredPayments = pendingBills;
          _totalAmount = totalAmount;
          _totalCollectedAmount = totalCollected;
          _totalPendingAmount = totalPending;
          _isLoading = false;
        });
        _filterPayments();
      }
    } catch (e) {
      appLog('Error loading pending payments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPayments() {
    final query = _searchController.text;
    setState(() {
      _filteredPayments = _pendingPayments.where((payment) {
        final name = payment['customerName'].toString();
        final mobile = payment['customerMobile'].toString();
        final vehicle = (payment['customerVehicle'] ?? '').toString();
        final matchesSearch =
            SearchUtils.matchesSubsequence(name, query) ||
            SearchUtils.matchesSubsequence(mobile, query) ||
            SearchUtils.matchesSubsequence(vehicle, query);

        final paid = payment['amountPaid'] as int;
        final matchesStatus =
            _statusFilter == 'all' ||
            (_statusFilter == 'partial' && paid > 0) ||
            (_statusFilter == 'unpaid' && paid == 0);

        return matchesSearch && matchesStatus;
      }).toList();

      switch (_sortBy) {
        case 'amount':
          _filteredPayments.sort(
            (a, b) => (b['amountRemaining'] as int).compareTo(
              a['amountRemaining'] as int,
            ),
          );
          break;
        case 'date':
          _filteredPayments.sort((a, b) {
            try {
              return _parseDate(
                b['billDate'],
              ).compareTo(_parseDate(a['billDate']));
            } catch (e) {
              return 0;
            }
          });
          break;
        case 'name':
          _filteredPayments.sort(
            (a, b) => a['customerName'].toString().compareTo(
              b['customerName'].toString(),
            ),
          );
          break;
      }
    });
  }

  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (e) {
      // Handle parsing error
    }
    return DateTime.now();
  }

  void _navigateToBillDetails(Map<String, dynamic> payment) {
    final productsMap = payment['products'] as Map<String, dynamic>?;
    final productsList = productsMap?.entries.map((entry) {
      final product = entry.value as Map<String, dynamic>;
      return {...product, 'key': entry.key};
    }).toList();

    AppNavigator.push(
      context,
      ViewBillDetailsScreen(
        billId: payment['id'],
        billDate: payment['billDate'],
        customerName: payment['customerName'],
        customerMobile: payment['customerMobile'],
        customerVehicle: payment['customerVehicle'],
        totalAmount: payment['totalAmount'],
        totalAmountPaid: payment['totalAmountPaid'],
        amountPaid: payment['amountPaid'],
        amountRemaining: payment['amountRemaining'],
        products: productsList,
        nextPaymentDate: null,
        previousDueAmount: (payment['previousDueAmount'] ?? 0).toDouble(),
        previousDueDescription: payment['previousDueDescription'] ?? '',
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.pendingPayments ?? 'Pending Payments'),
        actions: [
          IconButton(
            style: Adaptive.compactIconButton,
            icon: Icon(
              _showSearchBar ? CupertinoIcons.xmark : CupertinoIcons.search,
              size: 28,
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
                  value: '₹${_formatCurrency(_totalAmount)}',
                ),
                const SizedBox(width: 8),
                _SummaryTile(
                  icon: Icons.check_circle_outline,
                  label: loc?.collected ?? 'Collected',
                  value: '₹${_formatCurrency(_totalCollectedAmount)}',
                  valueColor: scheme.primary,
                ),
                const SizedBox(width: 8),
                _SummaryTile(
                  icon: Icons.schedule_outlined,
                  label: loc?.pending ?? 'Pending',
                  value: '₹${_formatCurrency(_totalPendingAmount)}',
                  valueColor: scheme.error,
                ),
              ],
            ),
          ),
          if (_showSearchBar)
            Adaptive.searchField(
              controller: _searchController,
              query: _searchController.text,
              hint: loc?.searchByNameMobile ?? 'Search by name, mobile...',
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
      final searching = _searchController.text.isNotEmpty;
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
                      searching ? Icons.search_off : Icons.check_circle_outline,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                searching
                    ? (loc?.noResultsFound ?? 'No results found')
                    : (loc?.noPendingPayments ?? 'No pending payments'),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
      children: [
        Adaptive.fullWidthGroup(
          context: context,
          children: [
            for (final payment in _filteredPayments)
              _PaymentTile(
                payment: payment,
                pendingLabel: loc?.pending ?? 'Pending',
                paidLabel: loc?.paid ?? 'Paid',
                onTap: () => _navigateToBillDetails(payment),
              ),
          ],
        ),
      ],
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
    required this.pendingLabel,
    required this.paidLabel,
    required this.onTap,
  });

  final Map<String, dynamic> payment;
  final String pendingLabel;
  final String paidLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = payment['amountRemaining'] as int;
    final total = payment['totalAmount'] as int;
    final paid = payment['amountPaid'] as int;
    final mobile = payment['customerMobile']?.toString() ?? '';
    final vehicle = payment['customerVehicle']?.toString() ?? '';

    final details = <String>[
      payment['billDate']?.toString() ?? '',
      '₹$total',
      '$paidLabel ₹$paid',
      if (mobile.isNotEmpty && mobile != 'N/A') mobile,
      if (vehicle.isNotEmpty) vehicle,
    ];

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
        details.join('  ·  '),
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
                pendingLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.error,
                ),
              ),
              Text(
                '₹$remaining',
                style: TextStyle(fontSize: 11, color: scheme.error),
              ),
            ],
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
