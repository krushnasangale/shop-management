import 'package:flashbill/pages/previous_due_details_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousDuePayments();
    _searchController.addListener(_filterPayments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreviousDuePayments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userId = user.uid;
      final firestore = FirebaseFirestore.instance;
      final billsSnapshot = await firestore
          .collection('bills')
          .doc(userId)
          .collection('items')
          .get();

      final payments = <Map<String, dynamic>>[];
      double totalPreviousDue = 0.0;
      double totalCollected = 0.0;
      double totalPending = 0.0;

      for (final billDoc in billsSnapshot.docs) {
        final billData = billDoc.data();
        final previousDueAmount =
            (billData['previousDueAmount'] as num?)?.toDouble() ?? 0.0;

        if (previousDueAmount > 0) {
          final previousPaidAmount =
              (billData['previousPaidAmount'] as num?)?.toDouble() ?? 0.0;
          final isFullyPaid = billData['totalAmountPaid'] ?? false;
          final customerName = billData['customerName'] ?? 'Unknown';
          final billDate = billData['billDate'] ?? '';

          payments.add({
            'billId': billDoc.id,
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
        return customerName.contains(query);
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
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.purple.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: loc?.searchCustomers ?? 'Search customers...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                    fontSize: 16,
                  ),
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.search,
                      color: Colors.purple[600],
                      size: 20,
                    ),
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
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
                onChanged: (_) => _filterPayments(),
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
                    padding: const EdgeInsets.all(12),
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
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            status == 'paid'
                                                ? Icons.check_circle
                                                : status == 'partial'
                                                ? Icons.pending
                                                : Icons.cancel,
                                            color: statusColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                payment['customerName'],
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark
                                                      ? Colors.grey[100]
                                                      : Colors.grey[900],
                                                  letterSpacing: -0.5,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  _getStatusText(status, loc),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: statusColor,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          payment['billDate'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.grey[300]
                                                : Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          height: 3,
                                          width: 3,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[400],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.currency_rupee,
                                          size: 14,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '₹${payment['previousDueAmount']}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
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
