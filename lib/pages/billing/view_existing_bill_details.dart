import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// --- Payment Record Model ---
class PaymentRecord {
  final int amount;
  final String date;

  PaymentRecord({
    required this.amount,
    required this.date,
  });

  factory PaymentRecord.fromMap(Map<dynamic, dynamic> map) {
    return PaymentRecord(
      amount: map['amount'] ?? 0,
      date: map['date'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': date,
    };
  }
}

// Assuming this is a mock implementation for demonstration
class ViewBillDetailsScreen extends StatefulWidget {
  final String billId;
  final String billDate;
  final String customerName;
  final String customerMobile;
  final String? customerVehicle;
  final int totalAmount;
  final bool totalAmountPaid;
  final int amountPaid;
  final int amountRemaining;
  final List<Map<String, dynamic>>? products;

  const ViewBillDetailsScreen({
    required this.billId,
    required this.billDate,
    required this.customerName,
    required this.customerMobile,
    this.customerVehicle,
    required this.totalAmount,
    required this.totalAmountPaid,
    required this.amountPaid,
    required this.amountRemaining,
    this.products,
    super.key,
  });

  @override
  State<ViewBillDetailsScreen> createState() => _ViewBillDetailsScreenState();
}

class _ViewBillDetailsScreenState extends State<ViewBillDetailsScreen> {
  // --- STATE VARIABLES (Simulated Data) ---
  // Note: In a real app, this data would come from a database query.
  late String billId;
  late String billDate;
  late String customerName;
  late String customerMobile;
  String? customerVehicle;
  List<Map<String, String>> products = const [
    {'name': 'Product Alpha', 'qty': '5', 'price': '₹ 5,000'},
    {'name': 'Service Beta', 'qty': '2', 'price': '₹ 1,500'},
    {'name': 'Component Gamma', 'qty': '10', 'price': '₹ 3,500'},
  ];
  String totalItems = '17';
  late String totalAmount;
  late String amountPaid;
  late String amountRemaining;
  String paymentStatus = 'Partially Paid';

  // New state variable for the boolean status
  bool isTotalAmountPaid = false;
  
  // Payment records
  List<PaymentRecord> paymentRecords = [];

  @override
  void initState() {
    super.initState();
    // Initialize from widget parameters
    billId = widget.billId;
    billDate = widget.billDate;
    customerName = widget.customerName;
    customerMobile = widget.customerMobile;
    customerVehicle = widget.customerVehicle;
    totalAmount = '₹ ${widget.totalAmount.toString()}';
    isTotalAmountPaid = widget.totalAmountPaid;
    amountPaid = '₹ ${widget.amountPaid.toString()}';
    amountRemaining = '₹ ${widget.amountRemaining.toString()}';
    
    // Convert products if provided
    if (widget.products != null && widget.products!.isNotEmpty) {
      products = widget.products!.map((p) => {
        'name': (p['productName'] ?? 'Unknown').toString(),
        'qty': (p['quantity'] ?? 0).toString(),
        'price': '₹ ${(p['price'] ?? 0).toString()}',
      }).toList();
      totalItems = widget.products!.length.toString();
    } else {
      products = [];
      totalItems = '0';
    }
    
    // Set payment status
    if (isTotalAmountPaid) {
      paymentStatus = 'Paid';
    } else if (widget.amountRemaining == 0) {
      paymentStatus = 'Paid';
    } else {
      paymentStatus = 'Partially Paid';
    }
    
    // Load payment records from Firebase
    _loadPaymentRecords();
  }
  
  Future<void> _loadPaymentRecords() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final database = FirebaseDatabase.instance;
      final snapshot = await database
          .ref('bills/${user.uid}/$billId/payments')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as List<dynamic>?;
        if (data != null) {
          setState(() {
            paymentRecords = data
                .map((p) => PaymentRecord.fromMap(Map<dynamic, dynamic>.from(p as Map)))
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error loading payment records: $e');
    }
  }

  Future<void> _saveAmountPaid(String paymentAmountStr, [String notes = 'Payment received']) async {
    try {
      final paymentAmount = int.parse(paymentAmountStr);
      
      // Validate payment amount
      if (paymentAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment amount must be greater than 0')),
        );
        return;
      }

      final totalAmountInt = int.parse(totalAmount.replaceAll('₹ ', ''));
      final currentAmountPaid = int.parse(amountPaid.replaceAll('₹ ', ''));
      final newTotalAmountPaid = currentAmountPaid + paymentAmount;

      if (newTotalAmountPaid > totalAmountInt) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Total payment cannot exceed ₹$totalAmountInt')),
        );
        return;
      }

      // Add new payment record
      await _addPaymentRecord(paymentAmount, notes);

      // Update bill totals
      final newRemaining = totalAmountInt - newTotalAmountPaid;
      final isFullyPaid = newTotalAmountPaid >= totalAmountInt;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final database = FirebaseDatabase.instance;
      await database
          .ref('bills/${user.uid}/$billId')
          .update({
            'amountPaid': newTotalAmountPaid,
            'amountRemaining': newRemaining,
            'totalAmountPaid': isFullyPaid,
          });

      // Update local state
      setState(() {
        amountPaid = '₹ $newTotalAmountPaid';
        amountRemaining = '₹ $newRemaining';
        isTotalAmountPaid = isFullyPaid;
        paymentStatus = isFullyPaid ? 'Paid' : 'Partially Paid';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _addPaymentRecord(int amount, [String notes = 'Payment received']) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final newPayment = PaymentRecord(
        amount: amount,
        date: DateFormat('dd MMM yyyy').format(DateTime.now()),
      );

      final database = FirebaseDatabase.instance;
      final paymentsRef = database.ref('bills/${user.uid}/$billId/payments');
      
      // Get current payments
      final snapshot = await paymentsRef.get();
      final payments = <Map<String, dynamic>>[];
      
      if (snapshot.exists) {
        final data = snapshot.value as List<dynamic>?;
        if (data != null) {
          for (var p in data) {
            payments.add(Map<String, dynamic>.from(p as Map));
          }
        }
      }
      
      // Add new payment
      payments.add(newPayment.toMap());
      
      // Save back to Firebase
      await paymentsRef.set(payments);
      
      // Update local state
      setState(() {
        paymentRecords.add(newPayment);
      });
    } catch (e) {
      print('Error adding payment record: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the color scheme for dynamic styling
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Bill Details'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => print('More options tapped'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. Bill/Customer Info Card ---
                  _buildCustomerInfoCard(
                    context,
                    cardColor,
                    primaryTextColor,
                    secondaryTextColor,
                  ),
                  const SizedBox(height: 16),

                  // --- 2. Products List Card ---
                  _buildProductsCard(
                    context,
                    cardColor,
                    primaryTextColor,
                    secondaryTextColor,
                  ),
                  const SizedBox(height: 16),

                  // --- 3. Financial Summary Card ---
                  _buildSummaryCard(
                    context,
                    cardColor,
                    primaryTextColor,
                    secondaryTextColor,
                  ),
                  const SizedBox(height: 16),

                  // --- 5. Payment History Card ---
                  _buildPaymentHistoryCard(
                    context,
                    cardColor,
                    primaryTextColor,
                    secondaryTextColor,
                  ),

                  // --- 6. Fixed Bottom Action (e.g., Record Payment) ---
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    final remainingAmount = int.parse(amountRemaining.replaceAll('₹ ', ''));
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount Left',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      Text(
                        '₹ $remainingAmount',
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
                    labelText: 'Payment Amount',
                    hintText: 'e.g., 2000',
                    prefixText: '₹ ',
                    helperText: 'Max: ₹ $remainingAmount',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Cheque #, reference, etc.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate payment amount
                final paymentAmountStr = amountController.text.trim();
                if (paymentAmountStr.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter payment amount')),
                  );
                  return;
                }

                final paymentAmount = int.tryParse(paymentAmountStr);
                if (paymentAmount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number')),
                  );
                  return;
                }

                if (paymentAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment amount must be greater than 0')),
                  );
                  return;
                }

                if (paymentAmount > remainingAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment cannot exceed ₹ $remainingAmount'),
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();
                _saveAmountPaid(paymentAmountStr, notesController.text);
              },
              child: const Text('Record'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePayment(int index) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Remove from list
      final updatedPayments = List<PaymentRecord>.from(paymentRecords);
      final deletedAmount = updatedPayments[index].amount;
      updatedPayments.removeAt(index);

      // Update Firebase
      final database = FirebaseDatabase.instance;
      await database
          .ref('bills/${user.uid}/$billId/payments')
          .set(updatedPayments.map((p) => p.toMap()).toList());

      // Recalculate totals
      int newTotalAmountPaid = 0;
      for (var payment in updatedPayments) {
        newTotalAmountPaid += payment.amount;
      }

      final totalAmountInt = int.parse(totalAmount.replaceAll('₹ ', ''));
      final newRemaining = totalAmountInt - newTotalAmountPaid;
      final isFullyPaid = newTotalAmountPaid >= totalAmountInt;

      await database
          .ref('bills/${user.uid}/$billId')
          .update({
            'amountPaid': newTotalAmountPaid,
            'amountRemaining': newRemaining,
            'totalAmountPaid': isFullyPaid,
          });

      // Update local state
      setState(() {
        paymentRecords = updatedPayments;
        amountPaid = '₹ $newTotalAmountPaid';
        amountRemaining = '₹ $newRemaining';
        isTotalAmountPaid = isFullyPaid;
        paymentStatus = isFullyPaid ? 'Paid' : 'Partially Paid';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment of ₹$deletedAmount removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // --- Helper 5: Payment History Card ---
  Widget _buildPaymentHistoryCard(
    BuildContext context,
    Color? cardColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment History',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (amountRemaining != '₹ 0')
                  ElevatedButton.icon(
                    onPressed: _showAddPaymentDialog,
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text('Add Payment', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
              ],
            ),
            Divider(color: secondaryTextColor?.withOpacity(0.3), height: 20),
            if (paymentRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No payments recorded',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paymentRecords.length,
                itemBuilder: (context, index) {
                  final payment = paymentRecords[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹ ${payment.amount}',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                payment.date,
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _deletePayment(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- REST OF THE PREVIOUS HELPERS (Unchanged) ---
  Widget _buildCustomerInfoCard(
    BuildContext context,
    Color? cardColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              context,
              'Bill Date',
              billDate,
              Icons.calendar_month,
              primaryTextColor,
              secondaryTextColor,
            ),
            Divider(color: secondaryTextColor?.withOpacity(0.3), height: 30),
            Text(
              'Customer Name',
              style: TextStyle(color: secondaryTextColor, fontSize: 14),
            ),
            Text(
              customerName,
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Customer Mobile Number',
              style: TextStyle(color: secondaryTextColor, fontSize: 14),
            ),
            Text(
              customerMobile,
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Customer Vehicle Number',
              style: TextStyle(color: secondaryTextColor, fontSize: 14),
            ),
            Text(
              'AB12 CD3456',
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.blue),
      title: Text(
        title,
        style: TextStyle(color: secondaryTextColor, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildProductsCard(
    BuildContext context,
    Color? cardColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Products',
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            ...products.map((product) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name']!,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Qty: ${product['qty']!}',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          product['price']!,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (products.last != product)
                      Divider(
                        color: secondaryTextColor?.withOpacity(0.3),
                        height: 16,
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    Color? cardColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    Color getStatusColor() {
      if (paymentStatus == 'Paid') return Colors.green;
      if (paymentStatus == 'Partially Paid') return Colors.orange;
      return Colors.red;
    }

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildSummaryRow(
              'Total Items',
              totalItems,
              primaryTextColor,
              secondaryTextColor,
            ),
            _buildSummaryRow(
              'Total Amount',
              totalAmount,
              primaryTextColor,
              secondaryTextColor,
              isBold: true,
            ),
            Divider(color: secondaryTextColor?.withOpacity(0.3), height: 32),
            _buildSummaryRow(
              'Amount Paid',
              amountPaid,
              primaryTextColor,
              secondaryTextColor,
            ),

            _buildSummaryRow(
              'Amount Remaining',
              amountRemaining,
              (amountRemaining != '₹ 0')
                  ? Colors.red[400]!
                  : Colors.green[400]!,
              secondaryTextColor,
              isBold: true,
            ),
            Divider(color: secondaryTextColor?.withOpacity(0.3), height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Status',
                  style: TextStyle(color: primaryTextColor, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: getStatusColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    paymentStatus,
                    style: TextStyle(
                      color: getStatusColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    String value,
    Color? primaryTextColor,
    Color? secondaryTextColor, {
    bool isBold = false,
  }) {
    Color displayColor = isBold
        ? (title == 'Amount Remaining' ? primaryTextColor! : primaryTextColor!)
        : secondaryTextColor!;
    double fontSize = isBold ? 18 : 16;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: primaryTextColor,
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: displayColor,
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
