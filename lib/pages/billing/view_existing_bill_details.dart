import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert' as convert;
import 'package:flashbill/pages/billing/create_new_bill.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:flashbill/l10n/app_localizations.dart';

// --- Payment Record Model ---
class PaymentRecord {
  final int amount;
  final String date;
  final String paymentMethod;

  PaymentRecord({
    required this.amount,
    required this.date,
    required this.paymentMethod,
  });

  factory PaymentRecord.fromMap(Map<dynamic, dynamic> map) {
    return PaymentRecord(
      amount: map['amount'] ?? 0,
      date: map['date'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'cash',
    );
  }

  Map<String, dynamic> toMap() {
    return {'amount': amount, 'date': date, 'paymentMethod': paymentMethod};
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
  final String paymentMethod;
  final String? nextPaymentDate;

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
    this.paymentMethod = 'cash',
    this.nextPaymentDate,
    super.key,
  });

  @override
  State<ViewBillDetailsScreen> createState() => _ViewBillDetailsScreenState();
}

class _ViewBillDetailsScreenState extends State<ViewBillDetailsScreen> {
  late String billId;
  int billNumber = 0; // Sequential bill number
  late String billDate;
  late String customerName;
  late String customerMobile;
  String? customerVehicle;
  List<Map<String, String>> products = const [];
  String totalItems = '0';
  late String totalAmount;
  late String amountPaid;
  late String amountRemaining;
  String paymentStatus = '';
  bool isTotalAmountPaid = false;
  List<PaymentRecord> paymentRecords = [];
  double totalProfit = 0;
  int discount = 0;
  late String paymentMethod;
  String? nextPaymentDate;
  late TextEditingController _nextPaymentDateController;
  late final AppLocalizations localizations;

  @override
  void initState() {
    super.initState();
    // Initialize from widget parameters
    billId = widget.billId;
    billDate = widget.billDate;
    customerName = widget.customerName;
    customerMobile = widget.customerMobile;
    customerVehicle = widget.customerVehicle;
    paymentMethod = widget.paymentMethod;
    nextPaymentDate = widget.nextPaymentDate;
    _nextPaymentDateController = TextEditingController(
      text: nextPaymentDate ?? '',
    );
    totalAmount = '₹ ${widget.totalAmount.toString()}';
    isTotalAmountPaid = widget.totalAmountPaid;
    amountPaid = '₹ ${widget.amountPaid.toString()}';
    amountRemaining = '₹ ${widget.amountRemaining.toString()}';

    // Convert products if provided
    if (widget.products != null && widget.products!.isNotEmpty) {
      products = widget.products!
          .map(
            (p) => {
              'name': (p['productName'] ?? 'Unknown').toString(),
              'qty': (p['quantity'] ?? 0).toString(),
              'price': '₹ ${(p['price'] ?? 0).toString()}',
              'boughtPrice': '₹ ${(p['boughtPrice'] ?? 0).toString()}',
              'batchId': (p['batchId'] as String?) ?? '',
              'profitTotal':
                  (p['profitTotal'] as num?)?.toStringAsFixed(2) ?? '0.00',
            },
          )
          .toList();
      totalItems = widget.products!.length.toString();

      // Calculate total profit using batch profit data if available
      // Discount will be subtracted after loading from Firebase
      totalProfit = _calculateBaseProfit();
    } else {
      products = [];
      totalItems = '0';
      totalProfit = 0;
    }

    // Set payment status
    if (isTotalAmountPaid) {
      paymentStatus = localizations.paid;
    } else if (widget.amountRemaining == 0) {
      paymentStatus = localizations.paid;
    } else {
      paymentStatus = localizations.partiallyPaid;
    }

    // Load discount and payment records from Firebase
    _loadPaymentRecords();
    _loadDiscount();
  }

  @override
  void dispose() {
    _nextPaymentDateController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context)!;
  }

  Future<void> _loadPaymentRecords() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        final payments = data?['payments'] as List<dynamic>? ?? [];
        if (payments.isNotEmpty) {
          setState(() {
            paymentRecords = payments
                .map(
                  (p) => PaymentRecord.fromMap(
                    Map<dynamic, dynamic>.from(p as Map),
                  ),
                )
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error loading payment records: $e');
    }
  }

  Future<void> _loadDiscount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        final loadedDiscount = (data?['discount'] as num?)?.toInt() ?? 0;
        int loadedBillNumber = (data?['billNumber'] as num?)?.toInt() ?? 0;

        setState(() {
          discount = loadedDiscount;
          billNumber = loadedBillNumber;
          // IMPORTANT: Discount ALWAYS reduces profit, never increases it
          // Formula: Profit = Base Profit - Discount
          // Ensure discount is positive (negative discount would incorrectly add to profit)
          final validDiscount = loadedDiscount > 0 ? loadedDiscount : 0;
          totalProfit = _calculateBaseProfit() - validDiscount;
        });
      }
    } catch (e) {
      print('Error loading discount: $e');
    }
  }

  // Helper method to calculate base profit from products
  double _calculateBaseProfit() {
    double baseProfit = 0;
    if (widget.products != null && widget.products!.isNotEmpty) {
      for (var product in widget.products!) {
        final quantity = (product['quantity'] ?? 0).toDouble();
        final sellingPrice = (product['price'] ?? 0).toDouble();
        final boughtPrice = (product['boughtPrice'] ?? 0).toDouble();

        // Always calculate profit from prices (not from stored profitTotal)
        final profit = (sellingPrice - boughtPrice) * quantity;
        baseProfit += profit;
      }
    }
    return baseProfit;
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
                      localizations.generatingPdf,
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
        await Share.shareXFiles([
          XFile(pdfFile.path),
        ], text: 'Bill from Shop');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.errorGeneratingBill}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editBill() {
    // Prepare the bill data for editing
    final billData = {
      'billId': billId,
      'billDate': billDate,
      'customerName': customerName,
      'customerMobile': customerMobile,
      'customerVehicle': customerVehicle,
      'paymentMethod': paymentMethod,
      'nextPaymentDate': nextPaymentDate,
      'products': widget.products,
      'totalAmount': widget.totalAmount,
      'amountPaid': widget.amountPaid,
      'amountRemaining': widget.amountRemaining,
      'totalAmountPaid': isTotalAmountPaid,
    };

    // Navigate to CreateNewBill with edit mode enabled
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateNewBill(
          isEditMode: true,
          billId: billId,
          existingBillData: billData,
        ),
      ),
    ).then((result) {
      // If bill was edited successfully, pop back to refresh the bills list
      if (result == true) {
        Navigator.pop(context, true);
      }
    });
  }

  Future<File> _generateBillPDF() async {
    // Ensure billNumber is loaded before generating PDF
    if (billNumber == 0) {
      await _loadDiscount(); // This will load or generate billNumber
    }

    final pdf = pw.Document();

    // Get temporary directory
    final dir = await getTemporaryDirectory();

    // Create filename with customer name and datetime
    final now = DateTime.now();
    final dateTimeString =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final sanitizedCustomerName = customerName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    final fileName = '${sanitizedCustomerName}_$dateTimeString.pdf';
    final file = File('${dir.path}/$fileName');

    final billDate = now.toString().split('.')[0];

    // Fetch owner signature and company details from Firebase
    String? ownerSignatureBase64;
    String shopName = '--';
    String ownerName = '--';
    String shopAddress = '--';
    String shopPhone = '--';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('shop-profile')
            .doc(user.uid)
            .get();
        if (snapshot.exists) {
          final data = snapshot.data();
          ownerSignatureBase64 = data?['ownerSignature'];
          shopName = data?['shopName'] ?? '--';
          ownerName = data?['ownerName'] ?? '--';
          shopAddress = data?['shopAddress'] ?? '--';
          shopPhone = data?['shopPhone'] ?? '--';
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

              // Company Details Section
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (shopAddress != '--')
                    pw.Text(
                      'Address: $shopAddress',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  if (shopPhone != '--')
                    pw.Text(
                      'Phone: $shopPhone',
                      style: const pw.TextStyle(fontSize: 9),
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
                      pw.Text(
                        'Invoice No.',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        billNumber > 0 ? '# $billNumber' : billId,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Invoice Date:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        billDate,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // Customer Details Section
              pw.Text(
                'BILL TO',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Name: $customerName',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Mobile: $customerMobile',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (customerVehicle != null && customerVehicle!.isNotEmpty)
                pw.Text(
                  'Vehicle: $customerVehicle',
                  style: const pw.TextStyle(fontSize: 10),
                ),

              pw.SizedBox(height: 15),

              // Products Table
              _buildProductTable(),
              pw.SizedBox(height: 40),

              // Remaining Amount Instruction (if applicable)
              if (amountRemaining != '₹ 0') ...[
                pw.Text(
                  'Please arrange payment of ${amountRemaining.replaceAll('₹', 'Rs.')} on or before $nextPaymentDate to complete this transaction.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 15),
              ],

              // Terms & Conditions
              pw.Text(
                'Terms & Conditions',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),

              // Signature Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Customer Signature',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Text('_' * 20, style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  if (ownerSignatureBase64 != null &&
                      ownerSignatureBase64.isNotEmpty)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(
                          width: 80,
                          height: 60,
                          child: pw.Image(
                            pw.MemoryImage(
                              convert.base64Decode(ownerSignatureBase64),
                            ),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Signature',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          ownerName,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    )
                  else
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SizedBox(height: 30),
                        pw.Text(
                          '_' * 20,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Signature',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          ownerName,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
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
      ...products.asMap().entries.map((entry) {
        String price = entry.value['price']!;
        String qty = entry.value['qty']!;

        // Remove rupee symbol and add 'Rs.' prefix for PDF
        price = price.replaceAll('₹', '').trim();

        // Calculate total amount (quantity × rate)
        final priceValue = int.tryParse(price.replaceAll(',', '')) ?? 0;
        final qtyValue = double.tryParse(qty) ?? 0;
        final totalAmount = (priceValue * qtyValue).toInt();

        final formattedPrice = 'Rs. $price';
        final formattedAmount = 'Rs. $totalAmount';

        return [
          '${entry.key + 1}',
          entry.value['name']!,
          qty,
          formattedPrice,
          formattedAmount,
        ];
      }),
    ];

    return pw.Table(
      border: pw.TableBorder(
        top: const pw.BorderSide(width: 1),
        bottom: const pw.BorderSide(width: 1),
        left: const pw.BorderSide(width: 1),
        right: const pw.BorderSide(width: 1),
        horizontalInside: pw.BorderSide(width: 1),
        verticalInside: const pw.BorderSide(width: 1),
      ),
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
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
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
                  textAlign: entry.key == 0
                      ? pw.TextAlign.center
                      : pw.TextAlign.left,
                ),
              );
            }).toList(),
          );
        }),
        // White space below last product item
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.white),
          children: [
            pw.SizedBox(height: 50),
            pw.SizedBox(height: 50),
            pw.SizedBox(height: 50),
            pw.SizedBox(height: 50),
            pw.SizedBox(height: 50),
          ],
        ),
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
              child: pw.Text(
                'Total Amount:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'Rs. ${totalAmount.replaceAll('₹', '').trim()}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        // Discount row (if discount is given)
        if (discount > 0)
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
                child: pw.Text(
                  'Discount:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  'Rs. $discount',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        // Total Amount Paid row
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
              child: pw.Text(
                'Total Paid:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'Rs. ${int.parse(amountPaid.replaceAll('₹ ', '')) - discount}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        // Remaining Amount row (if amounts don't match)
        if (amountRemaining != '₹ 0')
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
                child: pw.Text(
                  'Remaining:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  amountRemaining.replaceAll('₹', 'Rs.'),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _saveAmountPaid(
    String paymentAmountStr,
    String selectedPaymentMethod,
  ) async {
    try {
      final paymentAmount = int.parse(paymentAmountStr);

      // Validate payment amount
      if (paymentAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.paymentAmountMustBeGreaterThan0),
          ),
        );
        return;
      }

      final totalAmountInt = int.parse(totalAmount.replaceAll('₹ ', ''));
      final currentAmountPaid = int.parse(amountPaid.replaceAll('₹ ', ''));
      final newTotalAmountPaid = currentAmountPaid + paymentAmount;

      if (newTotalAmountPaid > totalAmountInt) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.totalPaymentCannotExceed.replaceAll(
                '%s',
                '₹$totalAmountInt',
              ),
            ),
          ),
        );
        return;
      }

      // Add new payment record with selected method
      await _addPaymentRecord(paymentAmount, selectedPaymentMethod);

      // Update bill totals
      final newRemaining = totalAmountInt - newTotalAmountPaid;
      final isFullyPaid = newTotalAmountPaid >= totalAmountInt;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId)
          .update({
            'amountPaid': newTotalAmountPaid,
            'amountRemaining': newRemaining,
            'totalAmountPaid': isFullyPaid,
            'paymentMethod': selectedPaymentMethod,
          });

      // Update local state
      setState(() {
        amountPaid = '₹ $newTotalAmountPaid';
        amountRemaining = '₹ $newRemaining';
        isTotalAmountPaid = isFullyPaid;
        paymentStatus = isFullyPaid
            ? localizations.paid
            : localizations.partiallyPaid;
        paymentMethod = selectedPaymentMethod;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.paymentRecordedSuccessfully)),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }

  Future<void> _addPaymentRecord(
    int amount,
    String selectedPaymentMethod,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final newPayment = PaymentRecord(
        amount: amount,
        date: DateFormat('dd MMM yyyy').format(DateTime.now()),
        paymentMethod: selectedPaymentMethod,
      );

      final billRef = FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId);

      // Append new payment to payments array
      await billRef.update({
        'payments': FieldValue.arrayUnion([newPayment.toMap()]),
      });

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
    final cardColor = Theme.of(context).cardTheme.color;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(localizations.billDetails),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editBill,
            tooltip: localizations.editBill,
          ),
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
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. Bill/Customer Info Card ---
                  _buildCustomerInfoCard(context, cardColor),
                  const SizedBox(height: 10),

                  // --- 2. Products List Card ---
                  _buildProductsCard(context, cardColor),
                  const SizedBox(height: 10),

                  // --- 3. Financial Summary Card ---
                  _buildSummaryCard(context, cardColor),
                  const SizedBox(height: 10),

                  // --- 4. Profit & Loss Card ---
                  _buildProfitLossCard(context, cardColor),
                  const SizedBox(height: 10),

                  // --- 5. Payment History Card ---
                  _buildPaymentHistoryCard(context, cardColor),

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
    final remainingAmount = int.parse(amountRemaining.replaceAll('₹ ', ''));
    String selectedPaymentMethod = 'cash';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                localizations.recordPayment,
                style: context.bodyLargeText?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                            localizations.amountRemaining,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
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
                        labelText: localizations.paymentAmount,
                        hintText: localizations.eg2000,
                        prefixText: '₹ ',
                        helperText: '${localizations.max}: ₹ $remainingAmount',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.paymentMethod,
                          style: context.titleMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(localizations.cash),
                                value: 'cash',
                                groupValue: selectedPaymentMethod,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (value) {
                                  setState(() {
                                    selectedPaymentMethod = value ?? 'cash';
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(localizations.online),
                                value: 'online',
                                groupValue: selectedPaymentMethod,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (value) {
                                  setState(() {
                                    selectedPaymentMethod = value ?? 'cash';
                                  });
                                },
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
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validate payment amount
                    final paymentAmountStr = amountController.text.trim();
                    if (paymentAmountStr.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.pleaseEnterAValidNumber),
                        ),
                      );
                      return;
                    }

                    final paymentAmount = int.tryParse(paymentAmountStr);
                    if (paymentAmount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.pleaseEnterAValidNumber),
                        ),
                      );
                      return;
                    }

                    if (paymentAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizations.paymentAmountMustBeGreaterThan0,
                          ),
                        ),
                      );
                      return;
                    }

                    if (paymentAmount > remainingAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizations.totalPaymentCannotExceed.replaceAll(
                              '%s',
                              '₹ $remainingAmount',
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    _saveAmountPaid(paymentAmountStr, selectedPaymentMethod);
                  },
                  child: Text(localizations.recordPayment),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditNextPaymentDateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            localizations.editNextPaymentDate,
            style: context.bodyLargeText?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: GestureDetector(
            onTap: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selectedDate != null) {
                final formattedDate = DateFormat(
                  'dd/MM/yyyy',
                ).format(selectedDate);
                _nextPaymentDateController.text = formattedDate;
              }
            },
            child: AbsorbPointer(
              child: TextField(
                controller: _nextPaymentDateController,
                decoration: InputDecoration(
                  labelText: localizations.nextPaymentDateLabel,
                  hintText: 'dd/MM/yyyy',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final newDate = _nextPaymentDateController.text.trim();
                if (newDate.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(localizations.pleaseSelectADate)),
                  );
                  return;
                }
                Navigator.of(context).pop();
                _updateNextPaymentDate(newDate);
              },
              child: Text(localizations.update),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateNextPaymentDate(String newDate) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId)
          .update({'nextPaymentDate': newDate});

      setState(() {
        nextPaymentDate = newDate;
        _nextPaymentDateController.text = newDate;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.nextPaymentDateUpdatedSuccessfully),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }

  void _showEditMobileDialog() {
    final TextEditingController mobileController = TextEditingController(
      text: customerMobile,
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                localizations.editMobileNumber,
                style: context.bodyLargeText?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                onChanged: (value) {
                  setState(() {
                    errorText = null;
                  });
                },
                decoration: InputDecoration(
                  labelText: localizations.mobileNumber,
                  hintText: localizations.tenDigitMobileNumber,
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newMobile = mobileController.text.trim();
                    if (newMobile.isEmpty) {
                      setState(() {
                        errorText = localizations.mobileNumberIsRequired;
                      });
                      return;
                    }
                    if (!RegExp(r'^[0-9]{10}$').hasMatch(newMobile)) {
                      setState(() {
                        errorText = localizations.mobileNumberMustBe10Digits;
                      });
                      return;
                    }
                    Navigator.of(context).pop();
                    _updateMobileNumber(newMobile);
                  },
                  child: Text(localizations.update),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateMobileNumber(String newMobile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId)
          .update({'customerMobile': newMobile});

      setState(() {
        customerMobile = newMobile;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.mobileNumberUpdatedSuccessfully)),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }

  void _showEditVehicleDialog() {
    final TextEditingController vehicleController = TextEditingController(
      text: customerVehicle ?? '',
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                localizations.editVehicleNumber,
                style: context.bodyLargeText?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: TextField(
                controller: vehicleController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  // Convert to uppercase and update controller
                  final upperValue = value.toUpperCase();
                  if (value != upperValue) {
                    vehicleController.value = vehicleController.value.copyWith(
                      text: upperValue,
                      selection: TextSelection.collapsed(
                        offset: upperValue.length,
                      ),
                    );
                  }
                  setState(() {
                    errorText = null;
                  });
                },
                decoration: InputDecoration(
                  labelText: localizations.vehicleNumber,
                  hintText: localizations.egKa01ab1234Optional,
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newVehicle = vehicleController.text
                        .trim()
                        .toUpperCase();
                    // Vehicle is optional, but if provided should match format
                    if (newVehicle.isNotEmpty &&
                        !RegExp(
                          r'^[A-Z]{2}[0-9]{2}[A-Z]{2}[0-9]{4}$',
                        ).hasMatch(newVehicle)) {
                      setState(() {
                        errorText = localizations.invalidFormatEgKa01ab1234;
                      });
                      return;
                    }
                    Navigator.of(context).pop();
                    _updateVehicleNumber(
                      newVehicle.isEmpty ? null : newVehicle,
                    );
                  },
                  child: Text(localizations.update),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateVehicleNumber(String? newVehicle) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId)
          .update({'customerVehicle': newVehicle ?? ''});

      setState(() {
        customerVehicle = newVehicle;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.vehicleNumberUpdatedSuccessfully)),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.couldNotLaunchPhoneDialer)),
        );
      }
    }
  }

  Future<void> _sendMessage(String phoneNumber) async {
    // Fetch shop name from Firebase
    String shopName = 'Our Shop';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('shop-profile')
            .doc(user.uid)
            .get();
        if (snapshot.exists) {
          shopName = snapshot.data()?['shopName'] ?? 'Our Shop';
        }
      }
    } catch (e) {
      print('Error fetching shop name: $e');
    }

    // Prepare message based on payment status
    String message;
    final remainingAmount = int.parse(amountRemaining.replaceAll('₹ ', ''));

    if (remainingAmount > 0) {
      // Pending payment reminder message
      message =
          '$shopName\n\n'
          'Dear $customerName,\n\n'
          'Thank you for shopping with us!\n\n'
          'This is a friendly reminder that you have a pending payment of ₹$remainingAmount '
          'for your purchase on $billDate.\n\n'
          '${nextPaymentDate != null && nextPaymentDate!.isNotEmpty ? "Please arrange payment by $nextPaymentDate.\n\n" : ""}'
          'We appreciate your business!\n\n'
          'Best regards,\n$shopName';
    } else {
      // Thank you message for completed payment
      message =
          '$shopName\n\n'
          'Dear $customerName,\n\n'
          'Thank you for your purchase on $billDate!\n\n'
          'We truly appreciate your business and hope you are satisfied with your products.\n\n'
          'Looking forward to serving you again soon!\n\n'
          'Best regards,\n$shopName';
    }

    // URI encode the message
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );

    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.couldNotLaunchMessagingApp)),
        );
      }
    }
  }

  void _showEditDiscountDialog() {
    final TextEditingController discountController = TextEditingController();
    String? errorText;
    final remainingAmountValue = int.parse(
      amountRemaining.replaceAll('₹ ', ''),
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                localizations.editDiscount,
                style: context.bodyLargeText?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
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
                          localizations.remainingAmount,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        Text(
                          '₹ $remainingAmountValue',
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
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        errorText = null;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: localizations.addDiscount,
                      hintText: localizations.eg100,
                      prefixText: '₹ ',
                      helperText:
                          '${localizations.max}: ₹ $remainingAmountValue',
                      prefixIcon: const Icon(Icons.discount),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newDiscount = int.tryParse(
                      discountController.text.trim(),
                    );
                    if (newDiscount == null) {
                      setState(() {
                        errorText = localizations.pleaseEnterAValidNumber;
                      });
                      return;
                    }
                    if (newDiscount < 0) {
                      setState(() {
                        errorText = localizations.discountCannotBeNegative;
                      });
                      return;
                    }
                    if (newDiscount > remainingAmountValue) {
                      setState(() {
                        errorText =
                            localizations.discountCannotExceedRemainingAmount;
                      });
                      return;
                    }
                    Navigator.of(context).pop();
                    _updateDiscount(newDiscount);
                  },
                  child: Text(localizations.update),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateDiscount(int additionalDiscount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final currentRemainingAmount = int.parse(
        amountRemaining.replaceAll('₹ ', ''),
      );
      final currentAmountPaid = int.parse(amountPaid.replaceAll('₹ ', ''));
      final totalAmountValue = int.parse(totalAmount.replaceAll('₹ ', ''));

      // Calculate new total discount (current + additional)
      final newTotalDiscount = discount + additionalDiscount;

      // Calculate new amounts with additional discount
      final newRemainingAmount = currentRemainingAmount - additionalDiscount;
      final newAmountPaid = currentAmountPaid + additionalDiscount;

      // Check if bill will be fully paid after discount
      final isFullyPaid = newRemainingAmount <= 0;

      final billRef = FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId);

      // Add new discount as a payment record
      await _addPaymentRecord(additionalDiscount, 'discount');

      // Update bill with new amounts and total discount
      await billRef.update({
        'discount': newTotalDiscount,
        'amountRemaining': isFullyPaid ? 0 : newRemainingAmount,
        'amountPaid': isFullyPaid ? totalAmountValue : newAmountPaid,
        'totalAmountPaid': isFullyPaid,
      });

      setState(() {
        discount = newTotalDiscount;
        amountRemaining = '₹ ${isFullyPaid ? 0 : newRemainingAmount}';
        amountPaid = '₹ ${isFullyPaid ? totalAmountValue : newAmountPaid}';
        isTotalAmountPaid = isFullyPaid;
        paymentStatus = isFullyPaid ? 'Paid' : 'Partially Paid';
        // IMPORTANT: Discount ALWAYS reduces profit
        // Ensure discount is positive (negative would incorrectly increase profit)
        final validDiscount = newTotalDiscount > 0 ? newTotalDiscount : 0;
        totalProfit = _calculateBaseProfit() - validDiscount;
      });

      // Reload payment records to show the discount
      await _loadPaymentRecords();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFullyPaid
                ? localizations.discountAddedBillFullyPaid.replaceAll(
                    '%s',
                    '₹$additionalDiscount',
                  )
                : localizations.discountAddedSuccessfully.replaceAll(
                    '%s',
                    '₹$additionalDiscount',
                  ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }

  // --- Helper 5: Payment History Card ---
  Widget _buildPaymentHistoryCard(BuildContext context, Color? cardColor) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 20, 10, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    localizations.paymentHistory,
                    style: context.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (amountRemaining != '₹ 0')
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: _showAddPaymentDialog,
                      icon: const Icon(
                        Icons.add,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        localizations.addPayment,
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
            Divider(
              color: context.secondaryTextColor?.withOpacity(0.3),
              height: 20,
            ),
            if (paymentRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    localizations.noPaymentsRecorded,
                    style: context.subtitleMedium,
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₹ ${payment.amount}',
                                    style: context.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (payment.amount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: payment.paymentMethod == 'cash'
                                            ? Colors.blue.withOpacity(0.15)
                                            : payment.paymentMethod ==
                                                  'discount'
                                            ? Colors.orange.withOpacity(0.15)
                                            : Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        payment.paymentMethod == 'cash'
                                            ? localizations.cash
                                            : payment.paymentMethod ==
                                                  'discount'
                                            ? localizations.discount
                                            : localizations.online,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: payment.paymentMethod == 'cash'
                                              ? Colors.blue[600]
                                              : payment.paymentMethod ==
                                                    'discount'
                                              ? Colors.orange[600]
                                              : Colors.green[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                payment.date,
                                style: context.subtitleMedium?.copyWith(
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
  Widget _buildCustomerInfoCard(BuildContext context, Color? cardColor) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill Date and Payment Method in one row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildDetailRow(
                    context,
                    localizations.billDate,
                    billDate,
                    Icons.calendar_month,
                  ),
                ),
                // Only show payment method if amount paid is greater than 0
                if (int.parse(amountPaid.replaceAll('₹ ', '')) > 0)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: paymentMethod == 'cash'
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: paymentMethod == 'cash'
                              ? Colors.blue
                              : Colors.green,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.paymentMethod,
                            style: context.subtitleMedium?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                paymentMethod == 'cash'
                                    ? Icons.money
                                    : Icons.credit_card,
                                color: paymentMethod == 'cash'
                                    ? Colors.blue
                                    : Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                paymentMethod == 'cash'
                                    ? localizations.cash
                                    : localizations.online,
                                style: TextStyle(
                                  color: paymentMethod == 'cash'
                                      ? Colors.blue
                                      : Colors.green,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Divider(
              color: context.secondaryTextColor?.withOpacity(0.3),
              height: 20,
            ),
            Text(
              localizations.customerName,
              style: context.subtitleMedium?.copyWith(fontSize: 14),
            ),
            Text(
              customerName,
              style: context.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              localizations.customerMobileNumber,
              style: context.subtitleMedium?.copyWith(fontSize: 14),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showEditMobileDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            customerMobile,
                            style: context.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          Icon(Icons.edit, size: 16, color: Colors.blue[600]),
                        ],
                      ),
                    ),
                  ),
                ),
                // Show call and message buttons only on mobile platforms
                if (Platform.isAndroid || Platform.isIOS) ...[
                  const SizedBox(width: 8),
                  // Call button
                  InkWell(
                    onTap: () => _makePhoneCall(customerMobile),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Message button
                  InkWell(
                    onTap: () => _sendMessage(customerMobile),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: const Icon(
                        Icons.message,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              localizations.customerVehicleNumber,
              style: context.subtitleMedium?.copyWith(fontSize: 14),
            ),
            GestureDetector(
              onTap: _showEditVehicleDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      customerVehicle ?? localizations.nA,
                      style: context.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    Icon(Icons.edit, size: 16, color: Colors.blue[600]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(title, style: context.subtitleMedium?.copyWith(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: context.bodyLargeText?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsCard(BuildContext context, Color? cardColor) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.products,
              style: context.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            ...products.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              final batchId = product['batchId']?.toString() ?? '';
              final quantity = double.tryParse(product['qty'] ?? '0') ?? 0;

              // Calculate profit per unit from prices
              final sellingPrice =
                  double.tryParse(
                    product['price']?.toString().replaceAll('₹', '').trim() ??
                        '0',
                  ) ??
                  0;
              final boughtPrice =
                  double.tryParse(
                    product['boughtPrice']
                            ?.toString()
                            .replaceAll('₹', '')
                            .trim() ??
                        '0',
                  ) ??
                  0;
              final profitPerUnit = sellingPrice - boughtPrice;
              final totalSellingPrice = sellingPrice * quantity;
              final totalProfit = profitPerUnit * quantity;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    backgroundColor: Colors.blue.withOpacity(0.02),
                    collapsedBackgroundColor: Colors.blue.withOpacity(0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Colors.blue.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Colors.blue.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '#${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                product['name']!,
                                style: context.titleMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Tile: Show only Qty and Total Selling Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${localizations.qty}: ${quantity.toInt()}',
                              style: context.subtitleMedium?.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${localizations.total}: ₹${totalSellingPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      // Expanded details
                      Divider(color: Colors.grey.withOpacity(0.2), height: 12),
                      const SizedBox(height: 8),

                      if (batchId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.purple.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${localizations.batch}: ${batchId.substring(0, 8)}...',
                              style: TextStyle(
                                color: Colors.purple[700],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      // Expanded info: Selling Price, Buying Price, Profit Per Unit, Total Profit
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailBox(
                            localizations.sellingPrice,
                            product['price']!,
                            Colors.green,
                          ),
                          _buildDetailBox(
                            localizations.buyingPrice,
                            product['boughtPrice']!,
                            Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailBox(
                            localizations.profitPerUnit,
                            '₹${profitPerUnit.toStringAsFixed(2)}',
                            profitPerUnit >= 0 ? Colors.green : Colors.red,
                          ),
                          _buildDetailBox(
                            localizations.totalProfit,
                            '₹${totalProfit.toStringAsFixed(0)}',
                            totalProfit >= 0 ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBox(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accentColor.withOpacity(0.15), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.secondaryTextColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Color? cardColor) {
    Color getStatusColor() {
      if (paymentStatus == 'Paid') return Colors.green;
      if (paymentStatus == 'Partially Paid') return Colors.orange;
      return Colors.red;
    }

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        localizations.totalItems,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      totalItems,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Discount row with edit functionality
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.discount,
                    style: context.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showEditDiscountDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            localizations.addDiscountLabel,
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit, size: 14, color: Colors.orange[600]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Final Amount after discount
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.finalAmount,
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹ ${int.parse(totalAmount.replaceAll('₹ ', '')) - discount}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              color: context.secondaryTextColor?.withOpacity(0.3),
              height: 16,
            ),
            _buildSummaryRow(localizations.amountPaid, amountPaid, null),

            _buildSummaryRow(
              localizations.amountRemaining,
              amountRemaining,
              (amountRemaining != '₹ 0')
                  ? Colors.red[400]!
                  : Colors.green[400]!,
              isBold: true,
            ),
            Divider(
              color: context.secondaryTextColor?.withOpacity(0.3),
              height: 16,
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizations.paymentStatus,
                  style: context.bodyLargeText?.copyWith(fontSize: 16),
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
            if ((amountRemaining != '₹ 0') &&
                nextPaymentDate != null &&
                nextPaymentDate!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(
                color: context.secondaryTextColor?.withOpacity(0.3),
                height: 16,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.nextPaymentDate,
                    style: context.bodyLargeText?.copyWith(fontSize: 16),
                  ),
                  GestureDetector(
                    onTap: _showEditNextPaymentDateDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nextPaymentDate!,
                            style: context.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit, size: 14, color: Colors.blue[600]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfitLossCard(BuildContext context, Color? cardColor) {
    final isProfitable = totalProfit >= 0;
    final profitColor = isProfitable ? Colors.green : Colors.red;
    final profitLossLabel = isProfitable
        ? localizations.profit
        : localizations.loss;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.profitLoss,
              style: context.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
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
                      const SizedBox(height: 4),
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
    Color? valueColor, {
    bool isBold = false,
  }) {
    Color displayColor =
        valueColor ??
        (isBold ? context.primaryTextColor! : context.secondaryTextColor!);
    double fontSize = isBold ? 18 : 16;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: context.bodyLargeText?.copyWith(
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
