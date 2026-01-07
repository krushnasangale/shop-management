import 'dart:async';
import 'dart:io' show Platform, File;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flashbill/pages/purchase/add_purchase_entry.dart';
import 'package:flashbill/pages/purchase/purchase_entry_details.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PurchaseItemsList extends StatefulWidget {
  const PurchaseItemsList({super.key});

  @override
  State<PurchaseItemsList> createState() => _PurchaseItemsListState();
}

class _PurchaseItemsListState extends State<PurchaseItemsList> {
  late CollectionReference _boughtRef;
  List<Map<String, dynamic>> _boughtEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  List<Map<String, dynamic>> _displayedEntries = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  late TextEditingController _searchController;
  bool _showSearchBar = false;
  final ScrollController _scrollController = ScrollController();
  int _displayedItemCount = 50;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterEntries);
    _scrollController.addListener(_onScroll);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _boughtRef = FirebaseFirestore.instance
          .collection('purchases')
          .doc(user.uid)
          .collection('items');
      _loadBoughtEntriesRealtime();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore || _displayedItemCount >= _filteredEntries.length) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _displayedItemCount = (_displayedItemCount + 50).clamp(
            0,
            _filteredEntries.length,
          );
          _displayedEntries = _filteredEntries
              .take(_displayedItemCount)
              .toList();
          _isLoadingMore = false;
        });
      }
    });
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
                _displayedItemCount = 50;
                _displayedEntries = entries.take(_displayedItemCount).toList();
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
        _displayedItemCount = 50;
        _displayedEntries = _filteredEntries.take(_displayedItemCount).toList();
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
        _displayedItemCount = 50;
        _displayedEntries = _filteredEntries.take(_displayedItemCount).toList();
      });
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
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
                          controller: _scrollController,
                          itemCount:
                              _displayedEntries.length +
                              (_isLoadingMore ? 1 : 0),
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                          itemBuilder: (context, index) {
                            if (index == _displayedEntries.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final entry = _displayedEntries[index];
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
        maxWidth: 3000, // Increase max resolution for better OCR
        maxHeight: 4000,
        preferredCameraDevice: CameraDevice.rear,
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
        maxWidth: 3000, // Increase max resolution for better OCR
        maxHeight: 4000,
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

  // Helper method to show limited data detection dialog
  void _showLimitedDataDialog(
    int textLength,
    Map<String, dynamic> invoiceData,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Limited Data Detected')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detected only $textLength characters from the document.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'For better results, try:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              _buildSuggestionRow(
                Icons.camera_alt,
                Colors.blue,
                'Take a clear photo with good lighting',
              ),
              SizedBox(height: 8),
              _buildSuggestionRow(
                Icons.picture_as_pdf,
                Colors.orange,
                'Use PDF scan for better table extraction',
              ),
              SizedBox(height: 8),
              _buildSuggestionRow(
                Icons.zoom_in,
                Colors.purple,
                'Ensure text is large and readable in photo',
              ),
              SizedBox(height: 8),
              _buildSuggestionRow(
                Icons.edit,
                Colors.green,
                'Manually enter the purchase details',
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: PDF scanning works best for table-based invoices',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Retry Scan'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddPurchaseEntry(existingEntry: invoiceData),
                ),
              );
            },
            child: Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
      ],
    );
  }

  Future<void> _scanFromPDF() async {
    try {
      print('Opening PDF picker...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        print('PDF selected: ${file.path}');

        if (file.path != null && mounted) {
          await _processPDF(file.path!);
        } else {
          print('PDF path is null');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not access PDF file'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print('No PDF selected');
      }
    } catch (e, stackTrace) {
      print('Error in _scanFromPDF: $e');
      print('Stack trace: $stackTrace');

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

  Future<void> _processPDF(String pdfPath) async {
    print('Starting PDF processing for: $pdfPath');

    // Show loading dialog with enhanced UI
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Processing Invoice',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Extracting text from PDF...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please wait',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      // Load the PDF document
      print('Loading PDF file...');
      final File file = File(pdfPath);
      final bytes = await file.readAsBytes();

      print('Parsing PDF document...');
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      print('PDF has ${document.pages.count} pages');

      // Extract text from all pages
      String extractedText = '';
      final PdfTextExtractor extractor = PdfTextExtractor(document);

      for (int i = 0; i < document.pages.count; i++) {
        print('Extracting text from page ${i + 1}...');
        final String pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        extractedText += pageText + '\n';
      }

      // Clean up
      document.dispose();

      print('Total extracted text length: ${extractedText.length}');
      print(
        'Extracted text preview: ${extractedText.substring(0, extractedText.length > 300 ? 300 : extractedText.length)}',
      );

      // Parse invoice data
      print('Parsing invoice data...');
      final invoiceData = _parseInvoiceText(extractedText);
      print('Parsed ${invoiceData['products'].length} products');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Check if PDF extraction failed to get meaningful data
        if (invoiceData['products'].length == 0 && extractedText.length < 500) {
          // Show helpful dialog
          _showLimitedDataDialog(extractedText.length, invoiceData);
        } else {
          // Navigate directly to purchase entry form with parsed invoice data
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddPurchaseEntry(existingEntry: invoiceData),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error in _processPDF: $e');
      print('Stack trace: $stackTrace');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _processImage(String imagePath) async {
    print('Starting image processing for: $imagePath');

    // Show loading dialog with enhanced UI
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Scanning Invoice',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Analyzing image with OCR...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please wait',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
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

        // IMPROVED: Extract text at multiple levels for better table detection
        print('OCR completed - Total blocks: ${recognizedText.blocks.length}');

        // Method 1: Get simple text (original method)
        String simpleText = recognizedText.text;
        print('Method 1 - Simple text length: ${simpleText.length}');

        // Method 2: Extract line by line from all blocks (better for tables)
        StringBuffer detailedText = StringBuffer();
        int totalLines = 0;

        for (int i = 0; i < recognizedText.blocks.length; i++) {
          final block = recognizedText.blocks[i];
          print('Block $i: ${block.text}');

          // Process each line in the block
          for (int j = 0; j < block.lines.length; j++) {
            final line = block.lines[j];
            totalLines++;

            // Extract elements (words) from the line
            List<String> lineElements = [];
            for (var element in line.elements) {
              lineElements.add(element.text);
            }

            // Join elements with spaces for this line
            String lineText = lineElements.join(' ');
            if (lineText.isNotEmpty) {
              detailedText.writeln(lineText);
              if (totalLines <= 20) {
                // Log first 20 lines
                print('  Line $j: $lineText');
              }
            }
          }
        }

        print('Method 2 - Detailed extraction: $totalLines lines');

        // Use the method that extracted more text
        if (detailedText.length > simpleText.length) {
          extractedText = detailedText.toString();
          print('Using detailed extraction (${extractedText.length} chars)');
        } else {
          extractedText = simpleText;
          print('Using simple extraction (${extractedText.length} chars)');
        }

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
      print('=== FULL EXTRACTED TEXT START ===');
      print(extractedText);
      print('=== FULL EXTRACTED TEXT END ===');
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

        // Check if OCR failed to extract meaningful data
        if (invoiceData['products'].length == 0 && extractedText.length < 500) {
          _showLimitedDataDialog(extractedText.length, invoiceData);
        } else {
          // Navigate directly to purchase entry form with parsed invoice data
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddPurchaseEntry(existingEntry: invoiceData),
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
    print('=== Starting Invoice Parsing ===');
    print('Raw text length: ${text.length}');

    // Enhanced parser with better pattern matching
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    print('Total lines: ${lines.length}');

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
      RegExp(
        r'invoice\s*amount[:\s]*₹?\$?\s*([0-9,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(r'total[:\s]*₹?\$?\s*([0-9,]+\.?\d*)', caseSensitive: false),
      RegExp(r'sub\s*total[:\s]*₹?\$?\s*([0-9,]+\.?\d*)', caseSensitive: false),
      RegExp(
        r'grand\s*total[:\s]*₹?\$?\s*([0-9,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(
        r'net\s*amount[:\s]*₹?\$?\s*([0-9,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(r'amount[:\s]*₹?\$?\s*([0-9,]+\.?\d*)', caseSensitive: false),
      RegExp(r'₹\s*([0-9,]+\.?\d*)\s*total', caseSensitive: false),
      RegExp(r'\$\s*([0-9,]+\.?\d*)\s*total', caseSensitive: false),
    ];

    // Enhanced product name patterns to catch fragmented names
    final productNamePatterns = [
      RegExp(
        r'^[A-Z][A-Z\s]{2,}$',
      ), // ALL CAPS product names (e.g., "TEFLON WONDER")
      RegExp(r'^[A-Z][a-zA-Z\s]{2,}$'), // Title case names
    ];

    // Multiple product line patterns to handle various formats
    final productPatterns = [
      // Format: "Product Name 2 pcs $100.00"
      RegExp(
        r'^(.+?)\s+(\d+)\s*(?:pcs?|pc|nos?|no|piece|units?|hrs?|hours?)\s*(?:at\s*)?[\$₹]?\s*([0-9,]+\.?\d*)',
        caseSensitive: false,
      ),
      // Format: "Product Name $100.00"
      RegExp(r'^(.+?)[\$₹]\s*([0-9,]+\.?\d*)$', caseSensitive: false),
      // Format: "Product: 5 hours at $75/hr"
      RegExp(
        r'^(.+?):\s*(\d+)\s*(?:hours?|hrs?)\s*at\s*[\$₹]?\s*([0-9,]+\.?\d*)',
        caseSensitive: false,
      ),
    ];

    // Extract supplier name - look for company/business names
    // Usually in first few lines, longer text without keywords
    for (int i = 0; i < lines.length && i < 10; i++) {
      final line = lines[i];
      print('Line $i: $line');

      // Skip common headers and keywords
      if (line.toLowerCase().contains('invoice') ||
          line.toLowerCase().contains('bill to') ||
          line.toLowerCase().contains('ship to') ||
          line.toLowerCase().contains('order') ||
          line.toLowerCase().contains('date') ||
          line.toLowerCase().contains('phone') ||
          line.toLowerCase().contains('address') ||
          line.toLowerCase().contains('city') ||
          line.toLowerCase().contains('description') ||
          line.contains('[') ||
          line.contains('(000)') ||
          line.length < 3 ||
          line.length > 100) {
        continue;
      }

      // Look for business name patterns
      if (supplierName == null) {
        final hasNumber = RegExp(r'\d').hasMatch(line);
        final hasSpecialChars = RegExp(r'[!@#%^&*()]').hasMatch(line);

        if (!hasNumber && !hasSpecialChars) {
          supplierName = line;
          print('Found supplier name: $supplierName');
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
          print('Found date: $date');
          break;
        }
      }
    }

    // Extract total amount - scan more lines and check adjacent lines
    print('=== Searching for Total Amount ===');
    for (int i = lines.length - 1; i >= 0 && i >= lines.length - 30; i--) {
      final line = lines[i];
      if (total != null) break;

      // Check if line contains total-related keywords
      if (line.toLowerCase().contains('total') ||
          line.toLowerCase().contains('amount') ||
          line.toLowerCase().contains('payable')) {
        print('Total keyword found at line $i: $line');

        // Check current line and next 3 lines for amount
        for (int j = i; j < i + 4 && j < lines.length; j++) {
          final checkLine = lines[j];
          final amountMatch = RegExp(
            r'₹\s*([0-9,]+\.?\d*)',
          ).firstMatch(checkLine);
          if (amountMatch != null) {
            final totalStr = amountMatch.group(1)?.replaceAll(',', '') ?? '';
            final potentialTotal = double.tryParse(totalStr);
            if (potentialTotal != null && potentialTotal > 100) {
              total = potentialTotal;
              print(
                'Found total at line $j: ₹$total (after keyword at line $i)',
              );
              break;
            }
          }
        }
        if (total != null) break;
      }

      // Also try existing patterns
      for (var pattern in totalPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final totalStr = match.group(1)?.replaceAll(',', '') ?? '';
          total = double.tryParse(totalStr);
          if (total != null && total > 0) {
            print('Found total via pattern: $total at line $i');
            break;
          }
        }
      }
    }

    if (total == null || total == 0.0) {
      print('WARNING: Total not found in last 30 lines');
      print('Last 10 lines of document:');
      for (int i = lines.length - 10; i < lines.length && i >= 0; i++) {
        print('  Line $i: ${lines[i]}');
      }

      // NEW: Try to find any large amount with ₹ symbol as potential total
      // Scan entire document for amounts > 1000
      List<double> largeAmounts = [];
      for (var line in lines) {
        final amountMatches = RegExp(r'₹\s*([0-9,]+\.?\d*)').allMatches(line);
        for (var match in amountMatches) {
          final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 500) {
            largeAmounts.add(amount);
            print('Found large amount: ₹$amount in line: $line');
          }
        }
      }

      // Use the largest amount as total if available
      if (largeAmounts.isNotEmpty) {
        total = largeAmounts.reduce((a, b) => a > b ? a : b);
        print('Using largest amount as total: ₹$total');
      }
    }

    // Extract products - improved approach for both inline and tabular formats
    print('=== Extracting Products ===');

    // NEW: Try to extract products from fragmented/incomplete OCR text
    // Look for potential product names (ALL CAPS or Title Case lines)
    // followed by numbers that could be quantities or prices
    List<String> potentialProductNames = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Skip too short or header lines
      if (line.length < 3) continue;
      if (line.toLowerCase().contains('invoice') ||
          line.toLowerCase().contains('bill to') ||
          line.toLowerCase().contains('ship to') ||
          line.toLowerCase().contains('thanks') ||
          line.toLowerCase().contains('hsn') ||
          line.toLowerCase().contains('sac') ||
          line.toLowerCase().contains('driver') ||
          line.toLowerCase().contains('round'))
        continue;

      // Check if line looks like a product name
      for (var pattern in productNamePatterns) {
        if (pattern.hasMatch(line)) {
          // Check if it's not the supplier name (already captured)
          if (supplierName != null &&
              line.toLowerCase().contains(
                supplierName.toLowerCase().split('/')[0].toLowerCase(),
              )) {
            continue;
          }

          // Additional validation - should not be address/location terms
          if (line.toLowerCase().contains('nagar') ||
              line.toLowerCase().contains('road') ||
              line.toLowerCase().contains('street') ||
              line.toLowerCase().contains('city') ||
              line.contains('%')) {
            continue;
          }

          potentialProductNames.add(line);
          print('Potential product name found at line $i: $line');

          // Look at next few lines for quantity/price information
          double foundPrice = 0.0;
          int foundQuantity = 1;

          for (int j = i + 1; j < i + 5 && j < lines.length; j++) {
            final nextLine = lines[j].trim();

            // Look for standalone numbers that could be quantity
            if (foundQuantity == 1 && RegExp(r'^\d{1,3}$').hasMatch(nextLine)) {
              final qty = int.tryParse(nextLine);
              if (qty != null && qty > 0 && qty < 1000) {
                foundQuantity = qty;
                print('  Found quantity: $foundQuantity');
              }
            }

            // Look for price with ₹ symbol
            final priceMatch = RegExp(
              r'₹\s*([0-9,]+\.?\d*)',
            ).firstMatch(nextLine);
            if (priceMatch != null && foundPrice == 0.0) {
              final priceStr = priceMatch.group(1)?.replaceAll(',', '') ?? '0';
              final price = double.tryParse(priceStr);
              if (price != null && price > 0 && price < 100000) {
                foundPrice = price;
                print('  Found price: ₹$foundPrice');
              }
            }
          }

          // Add product if we have enough information
          if (foundPrice > 0) {
            products.add({
              'name': line,
              'quantity': foundQuantity,
              'price': foundPrice,
              'unit': 'Pcs',
            });
            print(
              'Product added (fragmented): $line x$foundQuantity @ ₹$foundPrice',
            );
          }

          break;
        }
      }
    }

    // Continue with existing extraction methods if no products found yet
    bool inProductSection = false;
    int productCount = products.length; // Start from existing count
    int productSectionStartLine = -1;

    // First, find where the product section starts (only if no products found yet)
    if (products.isEmpty) {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        if (line.toLowerCase().contains('item name') ||
            line.toLowerCase().contains('description') ||
            (line.toLowerCase().contains('item') &&
                (line.toLowerCase().contains('quantity') ||
                    line.toLowerCase().contains('unit')))) {
          inProductSection = true;
          productSectionStartLine = i;
          print('Product section started at line $i: $line');
          break;
        }
      }
    }

    if (inProductSection && productSectionStartLine >= 0) {
      // Try to detect if this is a tabular format (PDF table extracted line-by-line)
      // Look for pattern: number, name, then other values
      int expectedRowNumber = 1; // Track sequential row numbers

      for (int i = productSectionStartLine + 1; i < lines.length - 7; i++) {
        final line = lines[i].trim();

        // Stop if we've reached the totals/footer section
        if (line.toLowerCase().contains('sub total') ||
            line.toLowerCase().contains('subtotal') ||
            line.toLowerCase().contains('grand total') ||
            line.toLowerCase().contains('invoice amount') ||
            line.toLowerCase().contains('net amount') ||
            line.toLowerCase().contains('taxable') ||
            line.toLowerCase().contains('cgst') ||
            line.toLowerCase().contains('sgst') ||
            line.toLowerCase().contains('igst') ||
            (line.toLowerCase().contains('total') &&
                RegExp(r'₹\s*[0-9,]+\.?\d*').hasMatch(line))) {
          print(
            'Reached totals section at line $i: $line - stopping product extraction',
          );
          break;
        }

        // Check if line is a row number (1, 2, 3, etc.)
        // Must be sequential to avoid confusing quantities with row numbers
        final isRowNumber = RegExp(r'^\d{1,3}$').hasMatch(line);
        final lineNumber = int.tryParse(line) ?? -1;
        final isSequentialRowNumber =
            isRowNumber && lineNumber == expectedRowNumber;

        if (isSequentialRowNumber) {
          print('Processing row $lineNumber at line $i');

          // Tabular format detected - next line should be product name
          var productName = (i + 1 < lines.length) ? lines[i + 1].trim() : '';

          // Skip if product name looks like header or invalid
          if (productName.isEmpty ||
              productName.length < 2 ||
              productName.toLowerCase().contains('total') ||
              productName.toLowerCase().contains('sub total') ||
              productName.toLowerCase().contains('invoice amount') ||
              productName.toLowerCase().contains('terns') ||
              productName.toLowerCase().contains('payment') ||
              // Also skip if product name is just a unit marker
              RegExp(
                r'^(pcs?|nos?|piece|unit|hrs?|hours?|box|boxes|kg|kgs|ltr|litre|rolls?|rol|-|set|sets|pair|pairs|mtr|meter|metres)$',
                caseSensitive: false,
              ).hasMatch(productName)) {
            print(
              'Skipping invalid product name at row $lineNumber: $productName (false row match)',
            );
            // Don't increment expectedRowNumber - this was a false match
            continue;
          }

          // Check if next line might be a continuation of product name (not a number or unit)
          if (i + 2 < lines.length) {
            final nextLine = lines[i + 2].trim();
            final isNotNumber = !RegExp(r'^\d+(\.\d+)?$').hasMatch(nextLine);
            final isNotUnit = !RegExp(
              r'^(pcs?|nos?|piece|unit|hrs?|hours?|box|boxes|kg|kgs|ltr|litre|rolls?|rol|-|set|sets|pair|pairs|mtr|meter|metres|₹)$',
              caseSensitive: false,
            ).hasMatch(nextLine);
            final isNotPrice = !nextLine.contains('₹');

            if (isNotNumber &&
                isNotUnit &&
                isNotPrice &&
                nextLine.length > 1 &&
                nextLine.length < 50) {
              // Likely a continuation of product name
              productName = '$productName $nextLine';
              print('Multi-line product detected: combined to $productName');
            }
          }

          print('Valid product name found: $productName');

          // In tabular format, look ahead for quantity and price
          // Expected pattern after product name:
          // [HSN/SAC], [MRP], Quantity, Unit (Pcs), Price/Unit (₹), Amount (₹)
          int quantity = 1;
          double price = 0.0;
          bool foundUnit = false;
          String unitMarker = 'Pcs'; // Default unit
          // Scan next 10 lines to find Unit marker (Pcs, Nos, Roll, etc.) first
          // Then get quantity before it and price after it
          for (int j = i + 2; j < i + 12 && j < lines.length; j++) {
            final nextLine = lines[j].trim();

            // Look for unit marker (Pcs, Nos, Unit, Roll, Rol, -, Box, etc.)
            if (!foundUnit &&
                RegExp(
                  r'^(pcs?|nos?|piece|unit|hrs?|hours?|box|boxes|kg|kgs|ltr|litre|rolls?|rol|-|set|sets|pair|pairs|mtr|meter|metres)$',
                  caseSensitive: false,
                ).hasMatch(nextLine)) {
              foundUnit = true;
              unitMarker = nextLine; // Store the actual unit marker
              print('Found unit marker at line $j: $nextLine');

              // Quantity should be 1-2 lines before the unit marker
              for (int k = j - 1; k >= i + 2 && k >= j - 3; k--) {
                final prevLine = lines[k].trim();
                final qtyMatch = RegExp(
                  r'^(\d{1,4})(?:\.0)?$',
                ).firstMatch(prevLine);
                if (qtyMatch != null) {
                  final potentialQty =
                      int.tryParse(qtyMatch.group(1) ?? '1') ?? 1;
                  if (potentialQty > 0 && potentialQty < 10000) {
                    quantity = potentialQty;
                    print('Found quantity at line $k: $quantity (before unit)');
                    break;
                  }
                }
              }

              // Price/Unit should be 1-2 lines after unit marker with ₹ symbol
              for (int k = j + 1; k < j + 4 && k < lines.length; k++) {
                final afterLine = lines[k].trim();
                // Look specifically for price with ₹ symbol
                final priceMatch = RegExp(
                  r'₹\s*([0-9,]+\.?\d*)',
                ).firstMatch(afterLine);
                if (priceMatch != null) {
                  final priceStr =
                      priceMatch.group(1)?.replaceAll(',', '') ?? '0';
                  final potentialPrice = double.tryParse(priceStr) ?? 0.0;
                  // First ₹ value after unit is Price/Unit (not Amount)
                  if (potentialPrice > 0 &&
                      potentialPrice < 100000 &&
                      price == 0.0) {
                    price = potentialPrice;
                    // After price, there's usually amount
                    print('Found price at line $k: ₹$price (after unit)');
                    break;
                  }
                }
              }

              break; // Found unit, no need to continue
            }
          }

          // Add product if we have valid data
          if (productName.isNotEmpty && price > 0) {
            products.add({
              'name': productName,
              'quantity': quantity,
              'price': price,
              'unit': unitMarker,
            });
            productCount++;
            print(
              'Product $productCount (table): $productName x$quantity $unitMarker @ ₹$price',
            );

            // Increment expected row number for next product
            expectedRowNumber++;

            // Don't skip - just continue normally, the sequential check will handle it
          }
        }
      }
    }

    // If no products found with tabular method, try inline patterns
    if (products.isEmpty) {
      print('Trying inline pattern extraction...');
      inProductSection = false;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        // Skip empty or very short lines
        if (line.length < 3) continue;

        // Detect start of product section
        if (line.toLowerCase().contains('description') ||
            line.toLowerCase().contains('item') ||
            line.toLowerCase().contains('product') ||
            line.toLowerCase().contains('service')) {
          inProductSection = true;
          print('Product section started at line $i');
          continue;
        }

        // Detect end of product section
        if ((line.toLowerCase().contains('total') ||
                line.toLowerCase().contains('subtotal') ||
                line.toLowerCase().contains('tax') ||
                line.toLowerCase().contains('discount')) &&
            RegExp(r'[\$₹]\s*[0-9,]+\.?\d*').hasMatch(line)) {
          print('Product section ended at line $i');
          break;
        }

        // Skip header-like lines
        if (!inProductSection) continue;

        // Skip lines that are clearly not products
        if (line.toLowerCase().contains('phone') ||
            line.toLowerCase().contains('email') ||
            line.toLowerCase().contains('address') ||
            line.toLowerCase().contains('payment') ||
            line.contains('[') ||
            line.contains(']')) {
          continue;
        }

        // Try each product pattern
        bool matched = false;

        for (var pattern in productPatterns) {
          final match = pattern.firstMatch(line);
          if (match != null) {
            String productName = '';
            int quantity = 1;
            double price = 0.0;

            // Handle different pattern groups
            if (match.groupCount >= 3) {
              // Pattern with quantity: "Product 5 pcs $100"
              productName = match.group(1)?.trim() ?? '';
              quantity = int.tryParse(match.group(2) ?? '1') ?? 1;
              final priceStr = match.group(3)?.replaceAll(',', '') ?? '0';
              price = double.tryParse(priceStr) ?? 0.0;
            } else if (match.groupCount == 2) {
              // Pattern without quantity: "Product $100"
              productName = match.group(1)?.trim() ?? '';
              quantity = 1;
              final priceStr = match.group(2)?.replaceAll(',', '') ?? '0';
              price = double.tryParse(priceStr) ?? 0.0;
            }

            // Validate and add product
            if (productName.isNotEmpty &&
                price > 0 &&
                !productName.toLowerCase().contains('total') &&
                !productName.toLowerCase().contains('tax') &&
                productName.length > 2) {
              products.add({
                'name': productName,
                'quantity': quantity,
                'price': price,
                'unit': 'Pcs', // Default unit for inline products
              });
              productCount++;
              print('Product $productCount: $productName x$quantity @ ₹$price');
              matched = true;
              break;
            }
          }
        }

        // If no pattern matched, try flexible extraction
        if (!matched && inProductSection) {
          // Look for any line with a price ($ or ₹ followed by number)
          final priceMatch = RegExp(
            r'[\$₹]\s*([0-9,]+\.?\d*)',
          ).firstMatch(line);

          if (priceMatch != null) {
            final priceStr = priceMatch.group(1)?.replaceAll(',', '') ?? '0';
            final price = double.tryParse(priceStr) ?? 0.0;

            if (price > 0) {
              // Extract product name by removing the price part
              String productName = line
                  .replaceAll(priceMatch.group(0) ?? '', '')
                  .trim();

              // Try to extract quantity if present
              int quantity = 1;
              final qtyMatch = RegExp(
                r'(\d+)\s*(?:pcs?|pc|nos?|no|piece|units?|hrs?|hours?)',
                caseSensitive: false,
              ).firstMatch(productName);

              if (qtyMatch != null) {
                quantity = int.tryParse(qtyMatch.group(1) ?? '1') ?? 1;
                // Remove quantity from product name
                productName = productName
                    .replaceAll(qtyMatch.group(0) ?? '', '')
                    .trim();
              }

              // Clean up product name
              productName = productName
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .replaceAll(RegExp(r'^[\d\s.,:;-]+'), '')
                  .replaceAll(RegExp(r'[\d\s.,:;-]+$'), '')
                  .trim();

              if (productName.isNotEmpty &&
                  productName.length > 2 &&
                  !productName.toLowerCase().contains('total') &&
                  !productName.toLowerCase().contains('tax') &&
                  !productName.toLowerCase().contains('subtotal')) {
                products.add({
                  'name': productName,
                  'quantity': quantity,
                  'price': price,
                  'unit': 'Pcs', // Default unit for flexible extraction
                });
                productCount++;
                print(
                  'Product $productCount (flexible): $productName x$quantity @ ₹$price',
                );
              }
            }
          }
        }
      }
    } // End of if (products.isEmpty) block

    print('=== Parsing Complete ===');
    print('Supplier: ${supplierName ?? "Unknown"}');
    print('Date: ${date ?? "Not found"}');
    print('Total: ${total ?? 0}');
    print('Products found: ${products.length}');

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
