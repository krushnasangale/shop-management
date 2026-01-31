import 'dart:async';
import 'package:flashbill/pages/previous_due_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/services/bills_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/l10n/app_localizations.dart';

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
  String _sortBy = 'amount'; // 'amount', 'date', 'name'
  String _statusFilter = 'all'; // 'all', 'paid', 'partial', 'unpaid'
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
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
      // Get cached bills from BillsDataService
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

      // Sort by date (newest first)
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
      }
    } catch (e) {
      print('Error loading previous due payments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPayments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPayments = _previousDuePayments.where((payment) {
        final customerName = payment['customerName'].toString().toLowerCase();
        final matchesSearch = customerName.contains(query);

        // Apply status filter
        final status = _getPreviousDueStatus(payment);
        final matchesStatus =
            _statusFilter == 'all' ||
            (_statusFilter == 'paid' && status == 'paid') ||
            (_statusFilter == 'partial' && status == 'partial') ||
            (_statusFilter == 'unpaid' && status == 'unpaid');

        return matchesSearch && matchesStatus;
      }).toList();

      // Apply sorting
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

  Widget _buildFilterChip(String label, String filterValue, Color color) {
    final isSelected = _statusFilter == filterValue;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = selected ? filterValue : 'all';
          _filterPayments();
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: color,
      checkmarkColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : Colors.grey[300]!,
          width: 1,
        ),
      ),
    );
  }

  void _navigateToBillDetails(Map<String, dynamic> payment) async {
    await AppNavigator.push(context, PreviousDueDetailsPage(payment: payment));
    // Refresh data when returning from details page
    _loadPreviousDuePayments();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc?.previousDuePayments ?? 'Previous Due Payments',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.purple.withOpacity(0.3),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple[600]!, Colors.purple[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  _filterPayments();
                }
              });
            },
            tooltip: _showSearchBar
                ? (loc?.closeSearch ?? 'Close Search')
                : (loc?.search ?? 'Search'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _filterPayments();
              });
            },
            icon: const Icon(Icons.sort),
            tooltip: loc?.sort ?? 'Sort',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    Icon(
                      Icons.currency_rupee,
                      size: 18,
                      color: Colors.purple[600],
                    ),
                    const SizedBox(width: 8),
                    Text(loc?.sortByAmount ?? 'Sort by Amount'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Colors.purple[600],
                    ),
                    const SizedBox(width: 8),
                    Text(loc?.sortByDate ?? 'Sort by Date'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 18, color: Colors.purple[600]),
                    const SizedBox(width: 8),
                    Text(loc?.sortByName ?? 'Sort by Name'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? Colors.grey[900] : Colors.grey[50],
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    loc?.total ?? 'Total',
                    '₹${_formatCurrency(_totalPreviousDueAmount.toInt())}',
                    Colors.blue,
                    isDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSummaryCard(
                    loc?.collected ?? 'Collected',
                    '₹${_formatCurrency(_totalCollectedAmount.toInt())}',
                    Colors.green,
                    isDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildSummaryCard(
                    loc?.pending ?? 'Pending',
                    '₹${_formatCurrency(_totalPendingAmount.toInt())}',
                    Colors.orange,
                    isDark,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          if (_showSearchBar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    filled: false,
                    hintText: loc?.searchCustomers ?? 'Search customers...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.purple[600],
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey[500],
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _filterPayments();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                  onChanged: (_) => _filterPayments(),
                ),
              ),
            ),

          // Filter Chips
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', Colors.blue),
                  const SizedBox(width: 8),
                  _buildFilterChip('Paid', 'paid', Colors.green),
                  const SizedBox(width: 8),
                  _buildFilterChip('Partial', 'partial', Colors.orange),
                  const SizedBox(width: 8),
                  _buildFilterChip('Unpaid', 'unpaid', Colors.red),
                ],
              ),
            ),
          ),

          // Payments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPayments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet,
                            size: 40,
                            color: Colors.purple[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loc?.noPreviousDuePayments ??
                              'No previous due payments found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'All payments are up to date!',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    itemCount: _filteredPayments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final payment = _filteredPayments[index];
                      final status = _getPreviousDueStatus(payment);
                      final statusColor = _getStatusColor(status);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [Colors.grey[850]!, Colors.grey[800]!]
                                    : [Colors.white, Colors.grey[50]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: statusColor.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () => _navigateToBillDetails(payment),
                              borderRadius: BorderRadius.circular(16),
                              splashColor: statusColor.withOpacity(0.1),
                              highlightColor: statusColor.withOpacity(0.05),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            payment['customerName'],
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? Colors.grey[100]
                                                  : Colors.grey[900],
                                              letterSpacing: -0.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 12,
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              payment['billDate'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.grey[300]
                                                    : Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(
                                              0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            _getStatusText(status, loc),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '₹ ${payment['previousDueAmount']}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.grey[300]
                                                : Colors.grey[700],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.payment,
                                              size: 12,
                                              color: Colors.green[600],
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '₹${payment['previousPaidAmount']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.green[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if ((payment['previousDueAmount']
                                                as double) >
                                            (payment['previousPaidAmount']
                                                as double))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.orange
                                                    .withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              'Pending: ₹${((payment['previousDueAmount'] as double) - (payment['previousPaidAmount'] as double)).toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange[600],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Determine payment status for previous due
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

  // Get color for status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get status text
  String _getStatusText(String status, AppLocalizations? loc) {
    switch (status) {
      case 'paid':
        return loc?.paid ?? 'Paid';
      case 'partial':
        return loc?.partiallyPaid ?? 'Partially Paid';
      case 'unpaid':
        return loc?.unpaid ?? 'Unpaid';
      default:
        return 'Unknown';
    }
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_getSummaryIcon(title), color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSummaryIcon(String title) {
    final loc = AppLocalizations.of(context);
    if (title == (loc?.totalDue ?? 'Total Due')) {
      return Icons.account_balance_wallet;
    } else if (title == (loc?.collected ?? 'Collected')) {
      return Icons.check_circle;
    } else if (title == (loc?.pending ?? 'Pending')) {
      return Icons.schedule;
    }
    return Icons.info;
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
