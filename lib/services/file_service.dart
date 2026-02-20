import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert' as convert;
import 'package:path/path.dart' as p;

/// Service for managing and sharing files across different platforms
class FileService {
  static Future<FileResult> shareFile({
    required Uint8List fileBytes,
    required String fileName,
    String shareText = 'Shared from FlashBill',
    String? subFolder,
  }) async {
    try {
      // Create file in appropriate directory based on platform
      Directory dir;

      if (Platform.isWindows) {
        // For Windows: Use Documents folder for better accessibility
        final documentsPath = Platform.environment['USERPROFILE'] ?? '';
        String path = '$documentsPath\\Documents\\FlashBill';

        // Add subfolder if provided
        if (subFolder != null && subFolder.isNotEmpty) {
          path += '\\$subFolder';
        }

        dir = Directory(path);

        // Create FlashBill folder (and subfolder) if it doesn't exist
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } else {
        // For Android/iOS: Use temporary directory
        dir = await getTemporaryDirectory();

        // Add subfolder if provided (for consistency)
        if (subFolder != null && subFolder.isNotEmpty) {
          dir = Directory('${dir.path}/$subFolder');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
        }
      }

      // Create file path with platform-specific separator
      final filePath = '${dir.path}${Platform.isWindows ? '\\' : '/'}$fileName';
      final file = File(filePath);

      // Write bytes to file
      await file.writeAsBytes(fileBytes);

      // Share the file
      await Share.shareXFiles([XFile(filePath)], text: shareText);

      return FileResult(success: true, filePath: filePath);
    } catch (e) {
      return FileResult(success: false, errorMessage: e.toString());
    }
  }

  static String generateTimestampedFileName(String baseName, String extension) {
    final now = DateTime.now();
    final dateTimeString =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    // Sanitize base name - remove special characters and replace spaces with underscores
    final sanitizedBaseName = baseName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');

    return '${sanitizedBaseName}_$dateTimeString.$extension';
  }

  /// Get the FlashBill documents directory path
  /// Returns null if not on Windows or if user profile path is not available
  static String? getFlashBillDocumentsPath({String? subFolder}) {
    if (Platform.isWindows) {
      final documentsPath = Platform.environment['USERPROFILE'];
      if (documentsPath != null) {
        String path = '$documentsPath\\Documents\\FlashBill';
        if (subFolder != null && subFolder.isNotEmpty) {
          path += '\\$subFolder';
        }
        return path;
      }
    }
    return null;
  }

  /// Share an existing file
  ///
  /// Parameters:
  /// - [file]: The file to share
  /// - [shareText]: Optional text to accompany the share
  /// - [subFolder]: Optional subfolder name within FlashBill directory
  ///
  /// Returns:
  /// - A [FileResult] containing success status and optional error message
  static Future<FileResult> shareExistingFile({
    required File file,
    String shareText = 'Shared from FlashBill',
    String? subFolder,
  }) async {
    try {
      // Read the file bytes
      final fileBytes = await file.readAsBytes();

      // Extract filename from path using path package for cross-platform compatibility
      final fileName = p.basename(file.path);

      // Use the main shareFile method
      return await shareFile(
        fileBytes: fileBytes,
        fileName: fileName,
        shareText: shareText,
        subFolder: subFolder,
      );
    } catch (e) {
      return FileResult(success: false, errorMessage: e.toString());
    }
  }

  /// Generate a PDF for a bill
  ///
  /// Parameters:
  /// - [billNumber]: Sequential bill number
  /// - [billId]: Unique bill identifier
  /// - [customerName]: Customer's name
  /// - [customerMobile]: Customer's mobile number
  /// - [customerVehicle]: Optional vehicle number
  /// - [products]: List of products with name, qty, and price
  /// - [totalAmount]: Total bill amount (with ₹ symbol)
  /// - [amountPaid]: Amount paid (with ₹ symbol)
  /// - [amountRemaining]: Amount remaining (with ₹ symbol)
  /// - [discount]: Discount amount
  /// - [deliveryCharges]: Delivery charges amount
  /// - [nextPaymentDate]: Next payment date if applicable
  /// - [previousDueAmount]: Previous due amount
  /// - [previousPaidAmount]: Previous paid amount
  /// - [previousDueDescription]: Description of previous due
  /// - [ownerSignatureBase64]: Base64 encoded owner signature
  /// - [shopName]: Shop name
  /// - [ownerName]: Owner name
  /// - [shopAddress]: Shop address
  /// - [shopPhone]: Shop phone number
  /// - [ownerPhone]: Owner/second phone number (optional)
  ///
  /// Returns:
  /// - PDF file as Uint8List
  static Future<Uint8List> generateBillPDF({
    required int billNumber,
    required String billId,
    required String customerName,
    required String customerMobile,
    String? customerVehicle,
    required List<Map<String, String>> products,
    required String totalAmount,
    required String amountPaid,
    required String amountRemaining,
    required int discount,
    required int deliveryCharges,
    String? nextPaymentDate,
    required double previousDueAmount,
    required double previousPaidAmount,
    required String previousDueDescription,
    String? ownerSignatureBase64,
    String shopName = '--',
    String ownerName = '--',
    String shopAddress = '--',
    String shopPhone = '--',
    String ownerPhone = '',
  }) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final billDate = now.toString().split('.')[0];

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
                  if (shopPhone != '--' && ownerPhone.isNotEmpty)
                    pw.Text(
                      'Phone : $shopPhone / $ownerPhone',
                      style: const pw.TextStyle(fontSize: 9),
                    )
                  else if (shopPhone != '--')
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
              if (customerVehicle != null && customerVehicle.isNotEmpty)
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
            _buildProductTable(
              products,
              totalAmount,
              amountPaid,
              amountRemaining,
              discount,
              deliveryCharges,
            ),
            pw.SizedBox(height: 40),

            // Footer content (only appears at the end)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
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

                // Previous Due Information (if applicable)
                if (previousDueAmount > 0 || previousPaidAmount > 0) ...[
                  if (previousDueAmount > 0) ...[
                    pw.Text(
                      'Previous Due: Rs. ${previousDueAmount.toStringAsFixed(2)} ${previousDueDescription.isNotEmpty ? '($previousDueDescription)' : ''}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.left,
                    ),
                  ],
                  if (previousPaidAmount > 0) ...[
                    pw.Text(
                      'Previous Paid: Rs. ${previousPaidAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green,
                      ),
                      textAlign: pw.TextAlign.left,
                    ),
                  ],
                  if (previousDueDescription.isNotEmpty) ...[
                    pw.Text(
                      'Due against: $previousDueDescription',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.left,
                    ),
                  ],
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

    return await pdf.save();
  }

  /// Build the product table for the PDF
  static pw.Widget _buildProductTable(
    List<Map<String, String>> products,
    String totalAmount,
    String amountPaid,
    String amountRemaining,
    int discount,
    int deliveryCharges,
  ) {
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
        // Delivery Charges row (if applicable)
        if (deliveryCharges > 0) ...[
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey200),
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
                  'Delivery Charges:',
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
                  'Rs. $deliveryCharges',
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
}

/// Result object for file operations
class FileResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  FileResult({required this.success, this.filePath, this.errorMessage});

  @override
  String toString() {
    if (success) {
      return 'FileResult(success: true, filePath: $filePath)';
    } else {
      return 'FileResult(success: false, error: $errorMessage)';
    }
  }
}
