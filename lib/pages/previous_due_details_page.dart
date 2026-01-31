import 'dart:async';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/services/bills_data_service.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PreviousDueDetailsPage extends StatefulWidget {
  final Map<String, dynamic> payment;

  const PreviousDueDetailsPage({super.key, required this.payment});

  @override
  State<PreviousDueDetailsPage> createState() => _PreviousDueDetailsPageState();
}

class _PreviousDueDetailsPageState extends State<PreviousDueDetailsPage> {
  List<Map<String, dynamic>> paymentRecords = [];
  bool isLoadingPayments = true;
  Map<String, dynamic>? currentBillData;
  late BillsDataService _billsDataService;
  StreamSubscription? _billsDataServiceSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBillsDataService();
  }

  void _initializeBillsDataService() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _billsDataService = BillsDataService();
      _billsDataService.initialize(user.uid);
      _billsDataServiceSubscription = _billsDataService.billsStream.listen((_) {
        _loadBillData();
      });
    } else {
      setState(() => isLoadingPayments = false);
    }
  }

  Future<void> _loadBillData() async {
    try {
      // Get cached bills from BillsDataService
      final cachedBills = _billsDataService.getCachedBills();
      final billData = cachedBills.firstWhere(
        (bill) => bill['id'] == widget.payment['billId'],
        orElse: () => <String, dynamic>{},
      );

      if (billData.isNotEmpty) {
        setState(() {
          currentBillData = billData;
        });
        await _loadPaymentRecords();
      } else {
        setState(() => isLoadingPayments = false);
      }
    } catch (e) {
      debugPrint('Error loading bill data: $e');
      setState(() => isLoadingPayments = false);
    }
  }

  Future<void> _loadPaymentRecords() async {
    try {
      if (currentBillData != null) {
        final payments =
            currentBillData!['previousDuePayments'] as List<dynamic>? ?? [];
        setState(() {
          paymentRecords = payments
              .map((p) => Map<String, dynamic>.from(p))
              .toList()
              .reversed
              .toList();
          isLoadingPayments = false;
        });
      } else {
        setState(() => isLoadingPayments = false);
      }
    } catch (e) {
      debugPrint('Error loading payment records: $e');
      setState(() => isLoadingPayments = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use current bill data if available, otherwise fall back to widget data
    final previousDueAmount =
        (currentBillData?['previousDueAmount'] as num?)?.toDouble() ??
        widget.payment['previousDueAmount'] as double;
    final previousPaidAmount =
        (currentBillData?['previousPaidAmount'] as num?)?.toDouble() ??
        widget.payment['previousPaidAmount'] as double;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (previousPaidAmount >= previousDueAmount) {
      statusColor = Colors.green;
      statusText = loc?.paid ?? 'Paid';
      statusIcon = Icons.check_circle;
    } else if (previousPaidAmount > 0) {
      statusColor = Colors.orange;
      statusText = loc?.partiallyPaid ?? 'Partially Paid';
      statusIcon = Icons.pending;
    } else {
      statusColor = Colors.red;
      statusText = loc?.unpaid ?? 'Unpaid';
      statusIcon = Icons.cancel;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.previousDue ?? 'Previous Due'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        actions: [
          if (previousPaidAmount < previousDueAmount)
            TextButton(
              child: const Text(
                'Add Payment',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => _showAddPaymentDialog(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(statusIcon, size: 40, color: statusColor),
                  const SizedBox(height: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${previousDueAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                  if (previousPaidAmount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Paid: ₹${previousPaidAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  if (previousPaidAmount < previousDueAmount) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Remaining: ₹${(previousDueAmount - previousPaidAmount).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Customer Information
            Text(
              loc?.customerInformation ?? 'Customer Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[100] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800]! : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.person,
                    loc?.customerName ?? 'Customer Name',
                    widget.payment['customerName'],
                    isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Previous Due Details
            Text(
              loc?.previousDue ?? 'Previous Due',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[100] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800]! : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Two items per row
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          Icons.history,
                          loc?.previousDue ?? 'Previous Due Amount',
                          '₹${previousDueAmount.toStringAsFixed(2)}',
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoRow(
                          Icons.payment,
                          loc?.paid ?? 'Amount Paid',
                          '₹${previousPaidAmount.toStringAsFixed(2)}',
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  if (previousPaidAmount < previousDueAmount) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            Icons.pending,
                            loc?.pending ?? 'Amount Pending',
                            '₹${(previousDueAmount - previousPaidAmount).toStringAsFixed(2)}',
                            isDark,
                          ),
                        ),
                        const Expanded(
                          child: SizedBox(),
                        ), // Empty space for balance
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Bill Date takes full width
                  _buildInfoRow(
                    Icons.calendar_today,
                    loc?.billDate ?? 'Bill Date',
                    widget.payment['billDate'],
                    isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payment History
            Text(
              loc?.paymentHistory ?? 'Payment History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[100] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800]! : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: isLoadingPayments
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : paymentRecords.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          loc?.noPaymentsRecorded ?? 'No payments recorded',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paymentRecords.length,
                      separatorBuilder: (context, index) => Divider(
                        color: isDark ? Colors.grey[700] : Colors.grey[200],
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final paymentRecord = paymentRecords[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.payment,
                              color: Colors.purple,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '₹${paymentRecord['amount']}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey[100]
                                  : Colors.grey[900],
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paymentRecord['date'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                              Text(
                                paymentRecord['paymentMethod'] ?? 'cash',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 32),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToBillDetails(context),
                icon: const Icon(Icons.receipt_long),
                label: Text(loc?.viewBillDetails ?? 'View Bill Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.purple[600]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[100] : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToBillDetails(BuildContext context) {
    // Convert products Map to List (products are stored as Map in Firestore)
    List<Map<String, dynamic>>? products;
    if (currentBillData?['products'] is Map) {
      final productsMap = currentBillData!['products'] as Map<String, dynamic>;
      products = productsMap.entries.map((entry) {
        final product = entry.value as Map<String, dynamic>;
        return Map<String, dynamic>.from(product);
      }).toList();
    } else if (widget.payment['products'] is Map) {
      final productsMap = widget.payment['products'] as Map<String, dynamic>;
      products = productsMap.entries.map((entry) {
        final product = entry.value as Map<String, dynamic>;
        return Map<String, dynamic>.from(product);
      }).toList();
    } else {
      products = <Map<String, dynamic>>[];
    }

    AppNavigator.push(
      context,
      ViewBillDetailsScreen(
        billId: widget.payment['billId'],
        billDate: widget.payment['billDate'],
        customerName: widget.payment['customerName'],
        customerMobile: '',
        customerVehicle: '',
        totalAmount: widget.payment['totalAmount'],
        totalAmountPaid: widget.payment['isFullyPaid'],
        amountPaid: widget.payment['amountPaid'],
        amountRemaining: widget.payment['amountRemaining'],
        products: products,
        nextPaymentDate: '',
        previousDueAmount: widget.payment['previousDueAmount'],
        previousPaidAmount: widget.payment['previousPaidAmount'],
        previousDueDescription: '',
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final TextEditingController amountController = TextEditingController();
    final previousDueAmount =
        (currentBillData?['previousDueAmount'] as num?)?.toDouble() ??
        widget.payment['previousDueAmount'] as double;
    final previousPaidAmount =
        (currentBillData?['previousPaidAmount'] as num?)?.toDouble() ??
        widget.payment['previousPaidAmount'] as double;
    final remainingAmount = previousDueAmount - previousPaidAmount;
    String selectedPaymentMethod = 'cash';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                loc?.addPayment ?? 'Add Payment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc?.pending ?? 'Amount Pending',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                          Text(
                            '₹${remainingAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc?.paymentAmount ?? 'Payment Amount',
                        hintText: '1000',
                        prefixText: '₹',
                        helperText:
                            '${loc?.max ?? 'Max'}: ₹${remainingAmount.toStringAsFixed(2)}',
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final enteredAmount = double.tryParse(value);
                          if (enteredAmount != null &&
                              enteredAmount > remainingAmount) {
                            // Reset to maximum allowed amount
                            amountController.text = remainingAmount
                                .toStringAsFixed(2);
                            amountController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(
                                    offset: amountController.text.length,
                                  ),
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Amount cannot exceed ₹${remainingAmount.toStringAsFixed(2)}',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc?.paymentMethod ?? 'Payment Method',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioMenuButton<String>(
                                value: 'cash',
                                groupValue: selectedPaymentMethod,
                                onChanged: (value) {
                                  setState(() {
                                    selectedPaymentMethod = value ?? 'cash';
                                  });
                                },
                                child: Text(loc?.cash ?? 'Cash'),
                              ),
                            ),
                            Expanded(
                              child: RadioMenuButton<String>(
                                value: 'online',
                                groupValue: selectedPaymentMethod,
                                onChanged: (value) {
                                  setState(() {
                                    selectedPaymentMethod = value ?? 'online';
                                  });
                                },
                                child: Text(loc?.online ?? 'Online'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc?.cancel ?? 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final paymentAmountStr = amountController.text.trim();
                    if (paymentAmountStr.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            loc?.pleaseEnterAValidNumber ??
                                'Please enter a valid number',
                          ),
                        ),
                      );
                      return;
                    }

                    final paymentAmount = double.tryParse(paymentAmountStr);
                    if (paymentAmount == null || paymentAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            loc?.pleaseEnterAValidNumber ??
                                'Please enter a valid number',
                          ),
                        ),
                      );
                      return;
                    }

                    if (paymentAmount > remainingAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Payment amount cannot exceed pending amount of ₹${remainingAmount.toStringAsFixed(2)}',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    await _addPayment(paymentAmount, selectedPaymentMethod);
                  },
                  child: Text(loc?.addPayment ?? 'Add Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addPayment(double amount, String paymentMethod) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newPayment = {
        'amount': amount,
        'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
        'paymentMethod': paymentMethod,
      };

      final billRef = FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(widget.payment['billId']);

      // First, get the current previousPaidAmount from the database
      final billDoc = await billRef.get();
      final currentPreviousPaid =
          (billDoc.data()?['previousPaidAmount'] as num?)?.toDouble() ?? 0.0;

      // Add payment to previousDuePayments array
      await billRef.update({
        'previousDuePayments': FieldValue.arrayUnion([newPayment]),
      });

      // Update previousPaidAmount with the current value from database
      final newPreviousPaidAmount = currentPreviousPaid + amount;

      await billRef.update({'previousPaidAmount': newPreviousPaidAmount});

      // Reload bill data and payment records to update the UI
      await _loadBillData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _billsDataServiceSubscription?.cancel();
    super.dispose();
  }
}
