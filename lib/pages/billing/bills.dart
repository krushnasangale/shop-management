import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';

class Bills extends StatefulWidget {
  const Bills({super.key});

  @override
  State<Bills> createState() => _BillsState();
}

class _BillsState extends State<Bills> {
  PaymentFilter _selectedFilter = PaymentFilter.all;
  late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _billsSubscription;
  late String _userId;
  List<Bill> _allBills = [];
  List<Bill> _filteredBills = [];
  bool _isLoading = true;
  bool _showSearchBar = false;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterBills);
    _loadBills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _billsSubscription.cancel();
    super.dispose();
  }

  void _loadBills() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _userId = user.uid;

    _billsSubscription = FirebaseFirestore.instance
        .collection('bills')
        .doc(_userId)
        .collection('items')
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        try {
          final bills = <Bill>[];

          for (var billDoc in snapshot.docs) {
            final billData = billDoc.data();
            final totalAmount = (billData['totalAmount'] as num?)?.toInt() ?? 0;
            final totalAmountPaid = billData['totalAmountPaid'] as bool? ?? true;
            final amountRemaining = (billData['amountRemaining'] as num?)?.toInt() ?? 0;
            final amountPaid = (billData['amountPaid'] as num?)?.toInt() ?? 0;

            // Determine payment status
            PaymentFilter status;
            if (amountPaid == 0 && amountRemaining != 0) {
              status = PaymentFilter.unpaid;
            } else if (totalAmountPaid) {
              status = PaymentFilter.paid;
            } else if (amountRemaining == 0) {
              status = PaymentFilter.paid;
            } else {
              status = PaymentFilter.partial;
            }

            final productsMap = billData['products'] as Map<String, dynamic>?;
            final productsList = <Map<String, dynamic>>[];
            if (productsMap != null) {
              productsList.addAll(productsMap.values.cast<Map<String, dynamic>>());
            }

            bills.add(
              Bill(
                billDoc.id,
                billData['billDate'] ?? '',
                billData['customerName'] ?? 'Unknown',
                billData['customerMobile'] ?? '',
                billData['customerVehicle'],
                '₹${totalAmount}',
                status,
                billData['timestamp'] ?? '',
                totalAmount,
                totalAmountPaid,
                amountPaid,
                amountRemaining,
                productsList,
                billData['nextPaymentDate'],
              ),
            );
          }

          // Sort bills by timestamp (newest first)
          bills.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (mounted) {
            setState(() {
              _allBills = bills;
              _filterBills();
              _isLoading = false;
            });
          }
        } catch (e) {
          print('Error loading bills: $e');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      },
      onError: (error) {
        print('Firebase error: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  // Filter bills based on search query and payment status
  void _filterBills() {
    final query = _searchController.text.toLowerCase();

    List<Bill> filtered = _allBills;

    // Apply payment filter
    if (_selectedFilter != PaymentFilter.all) {
      filtered = filtered
          .where((bill) => bill.status == _selectedFilter)
          .toList();
    }

    // Apply search filter
    if (query.isNotEmpty) {
      filtered = filtered.where((bill) {
        return bill.customerName.toLowerCase().contains(query) ||
            bill.customerMobile.toLowerCase().contains(query);
      }).toList();
    }

    if (mounted) {
      setState(() {
        _filteredBills = filtered;
      });
    }
  }

  // Helper to convert Enum to display string
  String _getStatusText(PaymentFilter filter) {
    switch (filter) {
      case PaymentFilter.all:
        return 'All';
      case PaymentFilter.paid:
        return 'Paid';
      case PaymentFilter.partial:
        return 'Partial Payment';
      case PaymentFilter.unpaid:
        return 'Unpaid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Bills'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
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
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Icon(Icons.more_vert),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
            : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. Search Bar (Toggle Visibility) ---
                if (_showSearchBar)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12.0,
                      right: 12.0,
                      top: 0,
                      bottom: 8.0,
                    ),
                    child: Card(
                      elevation: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by customer name',
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
                          fillColor: Theme.of(
                            context,
                          ).inputDecorationTheme.fillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),

                // --- 2. Filter Chips Row ---
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12.0,
                    right: 12.0,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.0,
                      vertical: 2.0,
                    ),
                    child: Row(
                      children: [
                        _buildFilterChip(PaymentFilter.all),
                        const SizedBox(width: 8),
                        _buildFilterChip(PaymentFilter.paid),
                        const SizedBox(width: 8),
                        _buildFilterChip(PaymentFilter.partial),
                        const SizedBox(width: 8),
                        _buildFilterChip(PaymentFilter.unpaid),
                      ],
                    ),
                  ),
                ),                // --- 3. Filtered Bills List ---
                Expanded(
                  child: _filteredBills.isEmpty
                      ? Center(
                          child: Text(
                            'No bills found',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredBills.length,
                          itemBuilder: (context, index) {
                            return _buildBillCard(_filteredBills[index]);
                          },
                        ),
                ),

                const SizedBox(height: 16),
              ],
            ),
    );
  }

  // Helper to build the status badge
  Widget _buildStatusBadge(PaymentFilter status) {
    Color color;
    String text;

    switch (status) {
      case PaymentFilter.paid:
        color = Colors.green;
        text = 'Paid';
        break;
      case PaymentFilter.partial:
        color = Colors.orange;
        text = 'Partial Payment';
        break;
      case PaymentFilter.unpaid:
        color = Colors.red;
        text = 'Unpaid';
        break;
      default:
        return const SizedBox.shrink(); // Hide 'All' filter on card
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build a single filter chip
  Widget _buildFilterChip(PaymentFilter filter) {
    final isSelected = _selectedFilter == filter;
    final cardColor = Theme.of(context).cardTheme.color;

    return FilterChip(
      label: Text(_getStatusText(filter)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
          _filterBills();
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: cardColor,
      selectedColor: Colors.blue.withOpacity(0.3),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.5),
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // Helper to build a single bill card
  Widget _buildBillCard(Bill bill) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      elevation: 1,
      child: InkWell(
        onTap: () {
          AppNavigator.push(
            context,
            ViewBillDetailsScreen(
              billId: bill.billId,
              billDate: bill.date,
              customerName: bill.customerName,
              customerMobile: bill.customerMobile,
              customerVehicle: bill.customerVehicle,
              totalAmount: bill.totalAmount,
              totalAmountPaid: bill.totalAmountPaid,
              amountPaid: bill.amountPaid,
              amountRemaining: bill.amountRemaining,
              products: bill.products,
              nextPaymentDate: bill.nextPaymentDate,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottom Row: Customer Name and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bill.customerName,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  _buildStatusBadge(bill.status),
                ],
              ),
              // Top Row: Date and Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill Date: ${bill.date}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 14),
                  ),
                  Text(
                    bill.amount,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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

// --- Data Model for Bill Status ---
enum PaymentFilter { all, paid, partial, unpaid }

// --- Product Data Structure (Simplified) ---
class Bill {
  final String billId;
  final String date;
  final String customerName;
  final String customerMobile;
  final String? customerVehicle;
  final String amount;
  final PaymentFilter status;
  final String timestamp;
  final int totalAmount;
  final bool totalAmountPaid;
  final int amountPaid;
  final int amountRemaining;
  final List<Map<String, dynamic>>? products;
  final String? nextPaymentDate;

  Bill(
    this.billId,
    this.date,
    this.customerName,
    this.customerMobile,
    this.customerVehicle,
    this.amount,
    this.status,
    this.timestamp,
    this.totalAmount,
    this.totalAmountPaid,
    this.amountPaid,
    this.amountRemaining,
    this.products,
    this.nextPaymentDate,
  );
}
