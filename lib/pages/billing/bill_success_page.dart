import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert' as convert;
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/l10n/app_localizations.dart';

class BillProductItem {
  final String productName;
  final String supplierName;
  final String unit;
  final double quantity;
  final int price;
  final int boughtPrice;
  final double total;
  final String batchId;
  final double profitMargin;
  final int initialQuantity;

  BillProductItem({
    required this.productName,
    required this.supplierName,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.boughtPrice,
    required this.total,
    required this.batchId,
    required this.profitMargin,
    required this.initialQuantity,
  });

  double get profitTotal => quantity * profitMargin;
}

class BillSuccessPage extends StatefulWidget {
  final String customerName;
  final String customerMobile;
  final String customerVehicle;
  final int totalAmount;
  final int amountPaid;
  final int amountRemaining;
  final List<BillProductItem> products;
  final String paymentMethod;
  final String nextPaymentDate;
  final int billNumber;
  final int deliveryCharges;
  final double previousDueAmount;
  final double previousPaidAmount;
  final String previousDueDescription;

  const BillSuccessPage({
    required this.customerName,
    required this.customerMobile,
    required this.customerVehicle,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountRemaining,
    required this.products,
    this.paymentMethod = 'cash',
    this.nextPaymentDate = '',
    required this.billNumber,
    this.deliveryCharges = 0,
    this.previousDueAmount = 0.0,
    this.previousPaidAmount = 0.0,
    this.previousDueDescription = '',
    super.key,
  });

  @override
  State<BillSuccessPage> createState() => _BillSuccessPageState();
}

class _BillSuccessPageState extends State<BillSuccessPage> {
  late String customerName;
  late String customerMobile;
  late String customerVehicle;
  late int totalAmount;
  late int amountPaid;
  late int amountRemaining;
  late List<BillProductItem> products;
  late String paymentMethod;
  late String nextPaymentDate;
  late int billNumber;
  late int deliveryCharges;
  late double previousDueAmount;
  late String previousDueDescription;
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    customerName = widget.customerName;
    customerMobile = widget.customerMobile;
    customerVehicle = widget.customerVehicle;
    totalAmount = widget.totalAmount;
    amountPaid = widget.amountPaid;
    amountRemaining = widget.amountRemaining;
    products = widget.products;
    paymentMethod = widget.paymentMethod;
    nextPaymentDate = widget.nextPaymentDate;
    billNumber = widget.billNumber;
    deliveryCharges = widget.deliveryCharges;
    previousDueAmount = widget.previousDueAmount;
    previousDueDescription = widget.previousDueDescription;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final cardColor = context.cardColor;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(localizations.billCreated),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Success Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 24),

                // Success Message
                Text(
                  localizations.billCreatedSuccessfully,
                  textAlign: TextAlign.center,
                  style: context.headingLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.billSavedToSystem,
                  textAlign: TextAlign.center,
                  style: context.subtitleMedium,
                ),
                const SizedBox(height: 40),

                // Bill Status Card
                Card(
                  color: cardColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color:
                          context.secondaryTextColor?.withOpacity(0.1) ??
                          Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.billStatus,
                          style: context.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow(
                          localizations.status,
                          localizations.completed,
                          Colors.green,
                          context,
                        ),
                        const SizedBox(height: 12),
                        _buildStatusRow(
                          localizations.payment,
                          amountRemaining > 0
                              ? localizations.partial
                              : localizations.full,
                          Colors.blue,
                          context,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          child: Text(
                            localizations.goToDashboard,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          onPressed: () {
                            // Share bill functionality
                            _shareBill(context, localizations);
                          },
                          icon: const Icon(Icons.share, color: Colors.blue),
                          label: Text(
                            localizations.shareBill,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
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
    );
  }

  void _shareBill(BuildContext context, AppLocalizations localizations) async {
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
                      style: context.bodyLargeText,
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
        ], text: localizations.billFromShop);
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

  Future<File> _generateBillPDF() async {
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
        final profileData = await _profileService.getCurrentUserProfile();
        if (profileData != null) {
          final data = profileData;
          ownerSignatureBase64 = data['ownerSignature'];
          shopName = data['shopName'] ?? '--';
          ownerName = data['ownerName'] ?? '--';
          shopAddress = data['shopAddress'] ?? '--';
          shopPhone = data['shopPhone'] ?? '--';
        }
      }
    } catch (e) {
      print('Error fetching owner signature: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (pw.Context context) {
          // Only show header on first page
          if (context.pageNumber > 1) {
            return pw.Container(); // Empty container for subsequent pages
          }

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
                        '# $billNumber',
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
              if (customerVehicle.isNotEmpty)
                pw.Text(
                  'Vehicle: $customerVehicle',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              pw.SizedBox(height: 15),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Products Table
            _buildProductTable(),
            pw.SizedBox(height: 40),

            // Footer content (only appears at the end)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Remaining Amount Instruction (if applicable)
                if (amountRemaining > 0) ...[
                  pw.Text(
                    'Please arrange payment of Rs. $amountRemaining on or before $nextPaymentDate to complete this transaction.',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 15),
                ],

                // Previous Due Information (if applicable)
                if (previousDueAmount > 0) ...[
                  pw.Text(
                    'Previous Due: Rs. ${previousDueAmount.toStringAsFixed(2)}}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                  pw.Text(
                    'Due against: ${widget.previousDueDescription.isNotEmpty ? '(${widget.previousDueDescription})' : ''}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.left,
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
                        pw.Text(
                          '_' * 20,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
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
            ),
          ];
        },
      ),
    );

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildProductTable() {
    // Table headers WITHOUT profit column (customer-facing)
    final headers = ['S.No.', 'Description', 'Qty', 'Rate', 'Amount'];

    // Table rows - format prices with 'Rs.' prefix
    final rows = <List<String>>[
      ...products.asMap().entries.map(
        (entry) => [
          '${entry.key + 1}',
          entry.value.productName,
          '${entry.value.quantity} ${entry.value.unit}',
          'Rs. ${entry.value.price}',
          'Rs. ${entry.value.total.toStringAsFixed(0)}',
        ],
      ),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          border: pw.TableBorder(
            top: const pw.BorderSide(width: 1),
            bottom: const pw.BorderSide(width: 1),
            left: const pw.BorderSide(width: 1),
            right: const pw.BorderSide(width: 1),
            horizontalInside: pw.BorderSide(width: 1),
            verticalInside: const pw.BorderSide(width: 1),
          ),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(1.2),
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
                      fontSize: 9,
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
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: entry.key == 0
                          ? pw.TextAlign.center
                          : pw.TextAlign.left,
                    ),
                  );
                }).toList(),
              );
            }).toList(),
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
            // Delivery Charges row (if applicable)
            if (deliveryCharges > 0) ...[
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      'Delivery Charges:',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      'Rs. $deliveryCharges',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
            // Total row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Total Amount:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Rs. $totalAmount',
                    style: pw.TextStyle(
                      fontSize: 9,
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
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Total Paid:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Rs. $amountPaid',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            // Remaining Amount row (if amounts don't match)
            if (amountRemaining > 0)
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      'Remaining:',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      'Rs. $amountRemaining',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusRow(
    String label,
    String value,
    Color valueColor,
    BuildContext context,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.subtitleMedium),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: context.titleMedium?.copyWith(color: valueColor),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _profileService.dispose();
    super.dispose();
  }
}
