import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class BillProductItem {
  final String productName;
  final String supplierName;
  final String unit;
  final double quantity;
  final int price;
  final int boughtPrice;
  final double total;

  BillProductItem({
    required this.productName,
    required this.supplierName,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.boughtPrice,
    required this.total,
  });
}

class BillSuccessPage extends StatefulWidget {
  final String customerName;
  final String customerMobile;
  final String customerVehicle;
  final int totalAmount;
  final int amountPaid;
  final int amountRemaining;
  final List<BillProductItem> products;

  const BillSuccessPage({
    required this.customerName,
    required this.customerMobile,
    required this.customerVehicle,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountRemaining,
    required this.products,
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
  }

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Bill Created'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                  'Bill Created Successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your bill has been saved to the system',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 40),

                // Bill Status Card
                Card(
                  color: cardColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: secondaryTextColor?.withOpacity(0.1) ?? Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bill Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow('Status', 'Completed', Colors.green, context),
                        const SizedBox(height: 12),
                        _buildStatusRow('Payment', amountRemaining > 0 ? 'Partial' : 'Full', Colors.blue, context),
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
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          child: const Text(
                            'Go to Dashboard',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Colors.blue, width: 2),
                          ),
                          onPressed: () {
                            // Share bill functionality
                            _shareBill(context);
                          },
                          icon: const Icon(Icons.share, color: Colors.blue),
                          label: const Text(
                            'Share Bill',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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

    final billId = 'BILL-${now.millisecondsSinceEpoch}';
    final billDate = now.toString().split('.')[0];

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
                    'NKT Shop',
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
              if (customerVehicle.isNotEmpty) pw.Text('Vehicle: $customerVehicle', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 15),

              // Products Table
              _buildProductTable(),
              pw.SizedBox(height: 15),

              // Rupees in words
              pw.Text('Rupees in words: ' + _convertNumberToWords(totalAmount), 
                style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),

              // Terms & Conditions
              pw.Text('Terms & Conditions', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 30),

              // Signature
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Signature', style: const pw.TextStyle(fontSize: 10)),
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
    
    // Table rows
    final rows = <List<String>>[
      ...products.asMap().entries.map(
        (entry) => [
          '${entry.key + 1}',
          entry.value.productName,
          '${entry.value.quantity} ${entry.value.unit}',
          '₹${entry.value.price}',
          '₹${entry.value.total.toStringAsFixed(0)}',
        ],
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
              child: pw.Text('₹$totalAmount', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
      ],
    );
  }

  String _convertNumberToWords(int number) {
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
      return (ones[number ~/ 100] + ' Hundred' + (number % 100 != 0 ? ' ' + _convertNumberToWords(number % 100) : '')).toUpperCase();
    }
    return number.toString();
  }

  Widget _buildStatusRow(String label, String value, Color valueColor, BuildContext context) {
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: secondaryTextColor,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
