import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, File;
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flashbill/pages/purchase/purchase_entry_details.dart';
import 'package:flashbill/pages/purchase/add_purchase_entry.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flashbill/pages/purchase/invoice_review_screen.dart';

class PurchaseItemsList extends StatefulWidget {
  const PurchaseItemsList({super.key});

  @override
  State<PurchaseItemsList> createState() => _PurchaseItemsListState();
}

class _PurchaseItemsListState extends State<PurchaseItemsList> {
  late CollectionReference _boughtRef;
  List<Map<String, dynamic>> _boughtEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  late TextEditingController _searchController;
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterEntries);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _boughtRef = FirebaseFirestore.instance
          .collection('purchases')
          .doc(user.uid)
          .collection('items');
      _loadBoughtEntriesRealtime();
    }
  }

  void _loadBoughtEntriesRealtime() {
    _streamSubscription = _boughtRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              final entries = snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();

              setState(() {
                _boughtEntries = entries;
                _filteredEntries = entries;
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            print('Error loading bought entries: $error');
            setState(() {
              _isLoading = false;
            });
          },
        );
  }

  void _filterEntries() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredEntries = _boughtEntries;
      });
    } else {
      setState(() {
        _filteredEntries = _boughtEntries.where((entry) {
          final supplierName = (entry['supplierName'] ?? '')
              .toString()
              .toLowerCase();
          final totalAmount = (entry['totalAmount'] ?? '').toString();
          return supplierName.contains(query) || totalAmount.contains(query);
        }).toList();
      });
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildTotalQuantityBadge(Map<String, dynamic> entry) {
    // Get total quantity from entry
    final totalQuantity = (entry['totalUnits'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.purple),
          const SizedBox(width: 4),
          Text(
            '$totalQuantity Qty',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchased Entries'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          // Scan Invoice Button
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan Invoice',
            onPressed: () {
              _showScanOptions(context);
            },
          ),
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.grey.withOpacity(0.2),
            ),
            height: 40,
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.account_circle, size: 35),
              onPressed: () async {
                AppNavigator.push(context, const MyProfile());
              },
              tooltip: 'My Profile',
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _boughtEntries.isEmpty
          ? const Center(child: Text('No purchased entries yet'))
          : Column(
              children: [
                // Search Bar
                if (_showSearchBar)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12.0,
                      right: 12.0,
                      top: 5,
                      bottom: 0,
                    ),
                    child: Card(
                      elevation: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by supplier or amount',
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
                // List
                Expanded(
                  child: _filteredEntries.isEmpty
                      ? const Center(child: Text('No matching entries found'))
                      : ListView.builder(
                          itemCount: _filteredEntries.length,
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                          itemBuilder: (context, index) {
                            final entry = _filteredEntries[index];
                            final date = entry['date'] ?? 'N/A';
                            final supplierName =
                                entry['supplierName'] ?? 'Unknown';
                            final totalAmount = entry['totalAmount'] ?? 0;
                            final totalProducts = entry['totalProducts'] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Card(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PurchaseEntryDetails(
                                                entry: entry,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Header Row
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
                                                      supplierName,
                                                      style: context
                                                          .bodyLargeText
                                                          ?.copyWith(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.calendar_today,
                                                          size: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          date,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '₹$totalAmount',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Divider
                                          Divider(
                                            height: 1,
                                            color: Colors.grey.withOpacity(0.3),
                                          ),
                                          const SizedBox(height: 8),
                                          // Bottom Section with Details
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$totalProducts Products',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Purchased',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.blue[400],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // display total quantity bought
                                              _buildTotalQuantityBadge(entry),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.check_circle,
                                                      size: 14,
                                                      color: Colors.green,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Text(
                                                      'Received',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  ],
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

  void _showScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Scan Invoice', style: context.headingMedium),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Capture invoice with camera'),
                onTap: () {
                  Navigator.pop(context);
                  _scanFromCamera();
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select invoice from photos'),
                onTap: () {
                  Navigator.pop(context);
                  _scanFromGallery();
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                ),
                title: const Text('Select PDF'),
                subtitle: const Text('Choose PDF invoice'),
                onTap: () {
                  Navigator.pop(context);
                  _scanFromPDF();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      print('Opening camera...');

      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      print('Photo captured: ${image?.path}');

      if (image != null && mounted) {
        await _processImage(image.path);
      } else {
        print('No photo captured or widget not mounted');
      }
    } catch (e, stackTrace) {
      print('Error in _scanFromCamera: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _scanFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      print('Opening gallery picker...');

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      print('Image selected: ${image?.path}');

      if (image != null && mounted) {
        await _processImage(image.path);
      } else {
        print('No image selected or widget not mounted');
      }
    } catch (e, stackTrace) {
      print('Error in _scanFromGallery: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _scanFromPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PDF processing requires additional setup. Please use image scanning for now.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processImage(String imagePath) async {
    print('Starting image processing for: $imagePath');

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing invoice...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      String extractedText = '';

      // Check if running on mobile platforms (Android/iOS)
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // Mobile: Use Google ML Kit
        print('Initializing Google ML Kit text recognizer...');
        final textRecognizer = TextRecognizer(
          script: TextRecognitionScript.latin,
        );

        print('Creating input image...');
        final inputImage = InputImage.fromFilePath(imagePath);

        print('Processing image with OCR...');
        final RecognizedText recognizedText = await textRecognizer.processImage(
          inputImage,
        );
        extractedText = recognizedText.text;

        // Clean up
        await textRecognizer.close();
        print('Text recognizer closed');
      } else {
        // Desktop/Web: OCR not supported
        throw Exception(
          'Invoice scanning with OCR is only available on Android and iOS devices. '
          'Please run this app on a mobile device to use the invoice scanning feature.',
        );
      }

      print('Extracted text length: ${extractedText.length}');
      print(
        'Extracted text preview: ${extractedText.substring(0, extractedText.length > 200 ? 200 : extractedText.length)}',
      );

      // Parse invoice data
      print('Parsing invoice data...');
      final invoiceData = _parseInvoiceText(extractedText);
      print('Parsed ${invoiceData['products'].length} products');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Show review screen
        final confirmedData = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                InvoiceReviewScreen(extractedData: invoiceData),
          ),
        );

        if (confirmedData != null) {
          // Navigate to purchase entry form with pre-filled invoice data
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddPurchaseEntry(existingEntry: confirmedData),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error in _processImage: $e');
      print('Stack trace: $stackTrace');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing invoice: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Map<String, dynamic> _parseInvoiceText(String text) {
    // Enhanced parser with better pattern matching
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? supplierName;
    String? date;
    double? total;
    List<Map<String, dynamic>> products = [];

    // Enhanced patterns for better detection
    final datePatterns = [
      RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})'), // DD-MM-YYYY or DD/MM/YYYY
      RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})'), // YYYY-MM-DD
      RegExp(
        r'date[:\s]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
        caseSensitive: false,
      ),
    ];

    final totalPatterns = [
      RegExp(r'total[:\s]*₹?\s*([0-9,]+\.?\d*)', caseSensitive: false),
      RegExp(r'sub\s*total[:\s]*₹?\s*([0-9,]+\.?\d*)', caseSensitive: false),
      RegExp(r'amount[:\s]*₹?\s*([0-9,]+\.?\d*)', caseSensitive: false),
      RegExp(r'₹\s*([0-9,]+\.?\d*)\s*total', caseSensitive: false),
    ];

    // Pattern to detect product lines with quantity and price
    final productLinePattern = RegExp(
      r'(.+?)\s+(\d+)\s+(?:pcs?|pc|nos?|no|piece|unit|-)?\s*₹?\s*([0-9,]+\.?\d*)\s*₹?\s*([0-9,]+\.?\d*)',
      caseSensitive: false,
    );

    // Alternative product pattern for simpler formats
    final simpleProductPattern = RegExp(r'₹?\s*([0-9,]+\.?\d*)');

    // Extract supplier name - look for company/business names
    // Usually in first few lines, longer text without keywords
    for (int i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i];
      // Skip headers and keywords
      if (line.toLowerCase().contains('invoice') ||
          line.toLowerCase().contains('bill') ||
          line.toLowerCase().contains('order') ||
          line.toLowerCase().contains('date') ||
          line.toLowerCase().contains('phone') && line.length < 20) {
        continue;
      }

      // Look for business name patterns (usually all caps or title case, no numbers)
      if (line.length > 3 && line.length < 100) {
        final hasNumber = RegExp(r'\d').hasMatch(line);
        if (!hasNumber ||
            (line.contains('TRADERS') ||
                line.contains('ENT') ||
                line.contains('CORPORATION') ||
                line.contains('COMPANY'))) {
          supplierName = line;
          break;
        }
      }
    }

    // Extract date
    for (var line in lines) {
      if (date != null) break;
      for (var pattern in datePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          date = match.group(1) ?? match.group(0);
          // Convert to standard format if needed
          if (date!.contains('-')) {
            // Already in good format
          }
          break;
        }
      }
    }

    // Extract total amount
    for (int i = lines.length - 1; i >= 0 && i >= lines.length - 20; i--) {
      final line = lines[i];
      if (total != null) break;

      for (var pattern in totalPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final totalStr = match.group(1)?.replaceAll(',', '') ?? '';
          total = double.tryParse(totalStr);
          if (total != null && total > 0) break;
        }
      }
    }

    // Extract products - try structured approach first
    bool inProductSection = false;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Detect start of product section
      if (line.toLowerCase().contains('item') &&
          (line.toLowerCase().contains('name') ||
              line.toLowerCase().contains('quantity'))) {
        inProductSection = true;
        continue;
      }

      // Detect end of product section
      if (line.toLowerCase().contains('total') &&
          (line.toLowerCase().contains('sub') ||
              line.toLowerCase().contains('grand'))) {
        break;
      }

      if (!inProductSection) continue;

      // Try to match product line pattern
      final match = productLinePattern.firstMatch(line);
      if (match != null) {
        final productName = match.group(1)?.trim() ?? '';
        final quantityStr = match.group(2) ?? '1';
        final priceStr = match.group(3)?.replaceAll(',', '') ?? '0';

        if (productName.isNotEmpty &&
            !productName.toLowerCase().contains('total')) {
          products.add({
            'name': productName,
            'quantity': int.tryParse(quantityStr) ?? 1,
            'price': double.tryParse(priceStr) ?? 0.0,
          });
        }
      } else {
        // Try alternative pattern - look for lines with multiple numbers
        final numbers = simpleProductPattern.allMatches(line).toList();
        if (numbers.length >= 2 && numbers.length <= 4) {
          // Extract product name by removing numbers
          String productName = line;
          for (var match in numbers) {
            productName = productName
                .replaceFirst(match.group(0) ?? '', '')
                .trim();
          }

          // Clean up product name
          productName = productName
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAll(RegExp(r'^[\d\s.,-]+'), '')
              .trim();

          if (productName.isNotEmpty &&
              productName.length > 2 &&
              !productName.toLowerCase().contains('total') &&
              !productName.toLowerCase().contains('amount')) {
            // Extract quantity and price
            final numberValues = numbers
                .map((m) => m.group(1)?.replaceAll(',', '') ?? '0')
                .toList();
            int quantity = 1;
            double price = 0.0;

            // Usually: quantity is first small number, price is larger number
            if (numberValues.length >= 2) {
              final firstNum = double.tryParse(numberValues[0]) ?? 1;
              final lastNum = double.tryParse(numberValues.last) ?? 0;

              if (firstNum < 1000) {
                quantity = firstNum.toInt();
                price = lastNum;
              } else {
                quantity = 1;
                price = firstNum;
              }
            }

            if (price > 0) {
              products.add({
                'name': productName,
                'quantity': quantity,
                'price': price,
              });
            }
          }
        }
      }
    }

    // If no date found, use current date
    if (date == null || date.isEmpty) {
      final now = DateTime.now();
      date =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    }

    return {
      'supplierName': supplierName ?? 'Unknown Supplier',
      'date': date,
      'total': total ?? 0.0,
      'products': products,
      'rawText': text, // Store raw text for debugging
    };
  }
}
