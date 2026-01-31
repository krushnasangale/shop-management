import 'dart:async';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/services/bills_data_service.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/l10n/app_localizations.dart';

class PendingPaymentsPage extends StatefulWidget {
  const PendingPaymentsPage({super.key});

  @override
  State<PendingPaymentsPage> createState() => _PendingPaymentsPageState();
}

class _PendingPaymentsPageState extends State<PendingPaymentsPage> {
  List<Map<String, dynamic>> _pendingPayments = [];
  List<Map<String, dynamic>> _filteredPayments = [];
  bool _isLoading = true;
  int _totalPendingAmount = 0;
  String _searchQuery = '';
  String _sortBy = 'amount'; // 'amount', 'date', 'name'
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
      // Get cached bills from BillsDataService
      final cachedBills = _billsDataService.getCachedBills();

      final pendingBills = <Map<String, dynamic>>[];
      int totalPending = 0;

      for (var billData in cachedBills) {
        final totalAmountPaid = billData['totalAmountPaid'] as bool? ?? false;

        if (!totalAmountPaid) {
          final amountRemaining =
              (billData['amountRemaining'] as num?)?.toInt() ?? 0;

          if (amountRemaining > 0) {
            pendingBills.add({
              'id': billData['id'],
              'customerName': billData['customerName'] ?? 'Unknown',
              'customerMobile': billData['customerMobile'] ?? 'N/A',
              'customerVehicle': billData['customerVehicle'],
              'billDate': billData['billDate'] ?? 'N/A',
              'amountRemaining': amountRemaining,
              'totalAmount': billData['totalAmount'] ?? 0,
              'totalAmountPaid': false,
              'amountPaid': billData['amountPaid'] ?? 0,
              'products': billData['products'],
              'paymentMethod': billData['paymentMethod'] ?? 'cash',
            });
            totalPending += amountRemaining;
          }
        }
      }

      if (mounted) {
        setState(() {
          _pendingPayments = pendingBills;
          _filteredPayments = pendingBills;
          _totalPendingAmount = totalPending;
          _isLoading = false;
        });
        _sortPayments();
      }
    } catch (e) {
      print('Error loading pending payments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterPayments() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredPayments = _pendingPayments;
      } else {
        _filteredPayments = _pendingPayments.where((payment) {
          final name = payment['customerName'].toString().toLowerCase();
          final mobile = payment['customerMobile'].toString().toLowerCase();
          final vehicle = (payment['customerVehicle'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(_searchQuery) ||
              mobile.contains(_searchQuery) ||
              vehicle.contains(_searchQuery);
        }).toList();
      }
      _sortPayments();
    });
  }

  void _sortPayments() {
    setState(() {
      if (_sortBy == 'amount') {
        _filteredPayments.sort(
          (a, b) => (b['amountRemaining'] as int).compareTo(
            a['amountRemaining'] as int,
          ),
        );
      } else if (_sortBy == 'date') {
        _filteredPayments.sort((a, b) {
          try {
            final dateA = _parseDate(a['billDate']);
            final dateB = _parseDate(b['billDate']);
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });
      } else if (_sortBy == 'name') {
        _filteredPayments.sort(
          (a, b) => a['customerName'].toString().compareTo(
            b['customerName'].toString(),
          ),
        );
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
    // Convert products Map to List
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
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.pendingPayments ?? 'Pending Payments'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              _sortPayments();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    Icon(
                      Icons.currency_rupee,
                      size: 18,
                      color: _sortBy == 'amount'
                          ? Colors.blue
                          : Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      localizations?.sortByAmount ?? 'Sort by Amount',
                      style: TextStyle(
                        color: _sortBy == 'amount'
                            ? Colors.blue
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: _sortBy == 'amount'
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
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
                      color: _sortBy == 'date'
                          ? Colors.blue
                          : Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      localizations?.sortByDate ?? 'Sort by Date',
                      style: TextStyle(
                        color: _sortBy == 'date'
                            ? Colors.blue
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: _sortBy == 'date' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 18,
                      color: _sortBy == 'name'
                          ? Colors.blue
                          : Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      localizations?.sortByName ?? 'Sort by Name',
                      style: TextStyle(
                        color: _sortBy == 'name'
                            ? Colors.blue
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: _sortBy == 'name' ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.totalPending ?? 'Total Pending',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${_formatCurrency(_totalPendingAmount)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_filteredPayments.length} ${localizations?.bills ?? 'Bills'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- Search Bar (Toggle Visibility) ---
          if (_showSearchBar)
            Padding(
              padding: const EdgeInsets.only(
                left: 12.0,
                right: 12.0,
                bottom: 5.0,
              ),
              child: Card(
                child: TextField(
                  controller: _searchController,
                  style: context.bodyLargeText,
                  decoration: InputDecoration(
                    hintText:
                        localizations?.searchByNameMobile ??
                        'Search by name, mobile...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: false,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

          // Pending Payments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPayments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: Colors.green.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? (localizations?.noPendingPayments ??
                                    'No pending payments')
                              : (localizations?.noResultsFound ??
                                    'No results found'),
                          style: context.subtitleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _filteredPayments.length,
                    itemBuilder: (context, index) {
                      final payment = _filteredPayments[index];
                      final amountRemaining = payment['amountRemaining'] as int;
                      final totalAmount = payment['totalAmount'] as int;
                      final amountPaid = payment['amountPaid'] as int;
                      final percentage = totalAmount > 0
                          ? (amountPaid / totalAmount * 100).toInt()
                          : 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _navigateToBillDetails(payment),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            payment['customerName'],
                                            style: context.titleLarge,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (payment['customerMobile'] !=
                                                      null &&
                                                  payment['customerMobile']
                                                      .toString()
                                                      .isNotEmpty) ...[
                                                Icon(
                                                  Icons.phone,
                                                  size: 12,
                                                  color: context
                                                      .secondaryTextColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  payment['customerMobile'],
                                                  style: context.subtitleMedium
                                                      ?.copyWith(fontSize: 12),
                                                ),
                                              ],
                                              if (payment['customerVehicle'] !=
                                                      null &&
                                                  payment['customerVehicle']
                                                      .toString()
                                                      .isNotEmpty) ...[
                                                const SizedBox(width: 12),
                                                Icon(
                                                  Icons.directions_car,
                                                  size: 12,
                                                  color: context
                                                      .secondaryTextColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  payment['customerVehicle'],
                                                  style: context.subtitleMedium
                                                      ?.copyWith(fontSize: 12),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        '₹${_formatCurrency(amountRemaining)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          localizations?.billDate ??
                                              'Bill Date',
                                          style: context.subtitleMedium
                                              ?.copyWith(fontSize: 11),
                                        ),
                                        Text(
                                          payment['billDate'],
                                          style: context.bodySmallText
                                              ?.copyWith(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          localizations?.totalAmount ??
                                              'Total Amount',
                                          style: context.subtitleSmall
                                              ?.copyWith(fontSize: 11),
                                        ),
                                        Text(
                                          '₹$totalAmount',
                                          style: context.bodySmallText
                                              ?.copyWith(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          localizations?.paid ?? 'Paid',
                                          style: context.subtitleMedium
                                              ?.copyWith(fontSize: 11),
                                        ),
                                        Text(
                                          '₹$amountPaid',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Payment Progress Bar
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          localizations?.paymentProgress ??
                                              'Payment Progress',
                                          style: context.subtitleMedium
                                              ?.copyWith(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        Text(
                                          '$percentage%',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percentage / 100,
                                        backgroundColor: isDark
                                            ? Colors.grey[700]
                                            : Colors.grey[300],
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              percentage < 30
                                                  ? Colors.red
                                                  : percentage < 70
                                                  ? Colors.orange
                                                  : Colors.green,
                                            ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
}
