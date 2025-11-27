import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert' as convert;

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
  
  // Profit calculation
  double totalProfit = 0;

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
      
      // Calculate total profit
      totalProfit = 0;
      for (var product in widget.products!) {
        final quantity = (product['quantity'] ?? 0).toDouble();
        final sellingPrice = (product['price'] ?? 0).toDouble();
        final boughtPrice = (product['boughtPrice'] ?? 0).toDouble();
        final profit = (sellingPrice - boughtPrice) * quantity;
        totalProfit += profit;
      }
    } else {
      products = [];
      totalItems = '0';
      totalProfit = 0;
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

  void _shareBill(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Generating PDF...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // Generate PDF
      final pdfFile = await _generateBillPDF();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Open share dialog
        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          text: 'Bill from NKT Shop',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<File> _generateBillPDF() async {
    final pdf = pw.Document();

    // Get temporary directory
    final dir = await getTemporaryDirectory();
    
    // Create filename with customer name and datetime
    final now = DateTime.now();
    final dateTimeString = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final sanitizedCustomerName = customerName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final fileName = '${sanitizedCustomerName}_${dateTimeString}.pdf';
    final file = File('${dir.path}/$fileName');

    final billDate = now.toString().split('.')[0];

    // Fetch owner signature from Firebase
    String? ownerSignatureBase64;
    String shopName = 'NKT Shop';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final database = FirebaseDatabase.instance;
        final snapshot = await database.ref('shop-profile/${user.uid}').get();
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          ownerSignatureBase64 = data['ownerSignature'];
          shopName = data['shopName'] ?? 'NKT Shop';
        }
      }
    } catch (e) {
      print('Error fetching owner signature: $e');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with Company Name and Invoice Title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    shopName,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // Bill ID and Date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Invoice No.', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(billId, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice Date:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(billDate, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // Customer Details Section
              pw.Text('BILL TO', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Name: $customerName', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Mobile: $customerMobile', style: const pw.TextStyle(fontSize: 10)),
              if (customerVehicle != null && customerVehicle!.isNotEmpty) pw.Text('Vehicle: $customerVehicle', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 15),

              // Products Table
              _buildProductTable(),
              pw.SizedBox(height: 15),

              // Rupees in words
              pw.Text('Rupees in words: ' + _convertNumberToWords(), 
                style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),

              // Terms & Conditions
              pw.Text('Terms & Conditions', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),

              // Signature Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 30),
                      pw.Text('_' * 20, style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  if (ownerSignatureBase64 != null && ownerSignatureBase64.isNotEmpty)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(
                          width: 80,
                          height: 60,
                          child: pw.Image(
                            pw.MemoryImage(convert.base64Decode(ownerSignatureBase64)),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text('Owner Signature', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    )
                  else
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(height: 30),
                        pw.Text('_' * 20, style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 5),
                        pw.Text('Owner Signature', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildProductTable() {
    // Table headers
    final headers = ['S.No.', 'Description', 'Qty', 'Rate', 'Amount'];
    
    // Table rows - format prices with rupee text
    final rows = <List<String>>[
      ...products.asMap().entries.map(
        (entry) {
          String price = entry.value['price']!;
          // Remove rupee symbol and add 'Rs.' prefix for PDF
          price = price.replaceAll('₹', '').trim();
          price = 'Rs. $price';
          return [
            '${entry.key + 1}',
            entry.value['name']!,
            entry.value['qty']!,
            price,
            price,
          ];
        },
      ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(width: 1),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: headers.map((header) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                header,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            );
          }).toList(),
        ),
        // Data rows
        ...rows.map((row) {
          return pw.TableRow(
            children: row.asMap().entries.map((entry) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  entry.value,
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: entry.key == 0 ? pw.TextAlign.center : pw.TextAlign.left,
                ),
              );
            }).toList(),
          );
        }).toList(),
        // Total row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('', style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('', style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('', style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Total:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'Rs. ${totalAmount.replaceAll('₹', '').trim()}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _convertNumberToWords() {
    try {
      final totalAmountInt = int.parse(totalAmount.replaceAll('₹ ', '').replaceAll(',', ''));
      
      return _numberToWords(totalAmountInt);
    } catch (e) {
      return 'Unable to convert';
    }
  }

  String _numberToWords(int number) {
    final ones = [
      '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
      'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
      'seventeen', 'eighteen', 'nineteen'
    ];
    final tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

    if (number == 0) return 'Zero';
    if (number < 20) return ones[number].toUpperCase();
    if (number < 100) {
      return (tens[number ~/ 10] + (number % 10 != 0 ? ' ' + ones[number % 10] : '')).toUpperCase();
    }
    if (number < 1000) {
      return (ones[number ~/ 100] + ' Hundred' + (number % 100 != 0 ? ' ' + _numberToWords(number % 100) : '')).toUpperCase();
    }
    if (number < 1000000) {
      return (_numberToWords(number ~/ 1000) + ' Thousand' + (number % 1000 != 0 ? ' ' + _numberToWords(number % 1000) : '')).toUpperCase();
    }
    return number.toString();
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
            icon: const Icon(Icons.share),
            onPressed: () => _shareBill(context),
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

                  // --- 4. Profit & Loss Card ---
                  _buildProfitLossCard(
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

  Widget _buildProfitLossCard(
    BuildContext context,
    Color? cardColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    final isProfitable = totalProfit >= 0;
    final profitColor = isProfitable ? Colors.green : Colors.red;
    final profitLossLabel = isProfitable ? 'Profit' : 'Loss';

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profit & Loss',
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: profitColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: profitColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profitLossLabel,
                        style: TextStyle(
                          color: profitColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹ ${totalProfit.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: profitColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isProfitable
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 48,
                    color: profitColor.withOpacity(0.6),
                  ),
                ],
              ),
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
