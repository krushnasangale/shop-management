import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/services/file_service.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/products/available_product_item_detail.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    hide FileService;
import 'package:flashbill/utils/search_utils.dart';
import 'package:image/image.dart' as img;
import 'package:flashbill/utils/app_logger.dart';

class AvailableProducts extends StatefulWidget {
  const AvailableProducts({super.key});

  @override
  State<AvailableProducts> createState() => _AvailableProductsState();
}

class _AvailableProductsState extends State<AvailableProducts> {
  late String _userId;
  late List<BoughtProduct> _boughtProducts;
  late List<BoughtProduct> _filteredProducts;
  bool _isLoading = true;
  bool _showSearchBar = false;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // Use key instead of localized string
  late TextEditingController _searchController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _productsSubscription;
  String _shopName = '--';
  String get _currentUserId => FirebaseAuth.instance.currentUser!.uid;

  // Infinite scroll variables
  final ScrollController _scrollController = ScrollController();
  final int _itemsPerPage = 100;
  int _currentlyLoadedItems = 100;
  bool _isLoadingMore = false;
  bool _isGeneratingReport = false;
  double _generationProgress = 0.0;
  bool _cancelGeneration = false;

  AppLocalizations? localizations;
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterProducts);
    _scrollController.addListener(_onScroll);
    _getUserAndLoadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _productsSubscription?.cancel();
    _profileService.dispose();
    super.dispose();
  }

  // Get filter label from key
  String _getFilterLabel(String key) {
    final option = _filterOptions.firstWhere(
      (option) => option['key'] == key,
      orElse: () => {'key': key, 'label': key},
    );
    return option['label']!;
  }

  // Get filter options with keys and localized labels
  List<Map<String, String>> get _filterOptions => [
    {'key': 'all', 'label': localizations!.all},
    {'key': 'reorder_now', 'label': localizations!.reorderNow},
    {'key': 'order_soon', 'label': localizations!.orderSoon},
    {'key': 'well_stocked', 'label': localizations!.wellStocked},
    {'key': 'expiring_soon', 'label': localizations!.expiringSoon},
    {'key': 'expired', 'label': localizations!.expired},
  ];

  // Handle scroll events for infinite loading
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreItems();
    }
  }

  // Load more items when scrolled near bottom
  void _loadMoreItems() {
    // Get the total count of unique products (grouped by name)
    Map<String, List<BoughtProduct>> groupedByName = {};
    for (var product in _filteredProducts) {
      if (!groupedByName.containsKey(product.productName)) {
        groupedByName[product.productName] = [];
      }
      groupedByName[product.productName]!.add(product);
    }
    final totalProducts = groupedByName.keys.length;

    if (_isLoadingMore || _currentlyLoadedItems >= totalProducts) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    // Simulate loading delay for smooth UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _currentlyLoadedItems = (_currentlyLoadedItems + _itemsPerPage).clamp(
            0,
            totalProducts,
          );
          _isLoadingMore = false;
        });
      }
    });
  }

  void _getUserAndLoadProducts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      _loadShopName();
      _loadProductsFromDatabase();
    } else {
      setState(() {
        _isLoading = false;
        _boughtProducts = [];
        _filteredProducts = [];
      });
    }
  }

  Future<void> _loadShopName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profileData = await _profileService.getCurrentUserProfile();
        if (profileData != null) {
          if (mounted) {
            setState(() {
              _shopName = (profileData['shopName'] as String?) ?? '--';
            });
          }
        }
      }
    } catch (e) {
      appLog('Error loading shop name: $e');
    }
  }

  // Ensure shop name is loaded before generating reports
  Future<void> _ensureShopNameLoaded() async {
    if (_shopName == '--') {
      await _loadShopName();
    }
  }

  void _loadProductsFromDatabase() {
    _productsSubscription = FirebaseFirestore.instance
        .collection('purchased-products')
        .doc(_userId)
        .collection('items')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
          if (!mounted) return;

          final loadedProducts = snapshot.docs
              .map((doc) => BoughtProduct.fromMap(doc.id, doc.data()))
              .toList();

          if (mounted) {
            setState(() {
              _boughtProducts = loadedProducts;
              _isLoading = false;
            });
            _filterProducts();
          }
        });
  }

  void _filterProducts() {
    _searchQuery = _searchController.text.toLowerCase();
    if (!mounted) return;
    setState(() {
      // Group products by name and consolidate quantities across all suppliers/batches
      Map<String, List<BoughtProduct>> groupedByName = {};

      for (var product in _boughtProducts) {
        if (!groupedByName.containsKey(product.productName)) {
          groupedByName[product.productName] = [];
        }
        groupedByName[product.productName]!.add(product);
      }

      // Apply search filter
      var filtered = <BoughtProduct>[];
      if (_searchQuery.isNotEmpty) {
        groupedByName.forEach((productName, batches) {
          // Check if product name contains search query as subsequence (characters in order, not necessarily consecutive)
          if (SearchUtils.matchesSubsequence(productName, _searchQuery)) {
            filtered.addAll(batches);
          }
        });
      } else {
        for (var batches in groupedByName.values) {
          filtered.addAll(batches);
        }
      }

      // Apply status filter - check consolidated quantity
      if (_selectedFilter != 'all') {
        filtered = filtered.where((product) {
          // Handle Expired filter separately
          if (_selectedFilter == 'expired') {
            // Check if product has expiry date and if it's expired
            if (product.expiryDate == null || product.expiryDate!.isEmpty) {
              return false; // No expiry date, not expired
            }
            try {
              // Parse the expiry date (format: dd/MM/yyyy)
              final parts = product.expiryDate!.split('/');
              if (parts.length == 3) {
                final day = int.parse(parts[0]);
                final month = int.parse(parts[1]);
                final year = int.parse(parts[2]);
                final expiryDate = DateTime(year, month, day);
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                return expiryDate.isBefore(today); // Expired if before today
              }
              return false;
            } catch (e) {
              return false; // Invalid date format
            }
          }

          // Handle Expiring Soon filter
          if (_selectedFilter == 'expiring_soon') {
            // Check if product has expiry date and if it's expiring within 90 days
            if (product.expiryDate == null || product.expiryDate!.isEmpty) {
              return false; // No expiry date
            }
            try {
              // Parse the expiry date (format: dd/MM/yyyy)
              final parts = product.expiryDate!.split('/');
              if (parts.length == 3) {
                final day = int.parse(parts[0]);
                final month = int.parse(parts[1]);
                final year = int.parse(parts[2]);
                final expiryDate = DateTime(year, month, day);
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final ninetyDaysFromNow = today.add(const Duration(days: 90));
                // Expiring soon if not yet expired and within 90 days
                return !expiryDate.isBefore(today) &&
                    expiryDate.isBefore(ninetyDaysFromNow);
              }
              return false;
            } catch (e) {
              return false; // Invalid date format
            }
          }

          // Get all batches for this product
          final allBatches = groupedByName[product.productName] ?? [];

          // Filter only available batches (quantity > 0)
          final availableBatches = allBatches
              .where((p) => p.quantity > 0)
              .toList();

          // Calculate total quantity from available batches only
          final totalQty = availableBatches.fold(
            0,
            (int sum, p) => sum + p.quantity,
          );

          // Get min limit from the one batch that stores it (minLimit > 0)
          final minLimitForStatus = availableBatches.isNotEmpty
              ? (availableBatches
                    .firstWhere(
                      (batch) => batch.minLimit > 0,
                      orElse: () => availableBatches.first,
                    )
                    .minLimit)
              : 0;

          return _getStockStatusKey(totalQty, minLimitForStatus) ==
              _selectedFilter;
        }).toList();
      }

      _filteredProducts = filtered;

      // Reset loaded items count for infinite scroll
      // Reuse the existing groupedByName map to count unique products
      _currentlyLoadedItems = _itemsPerPage.clamp(0, groupedByName.keys.length);
    });
  }

  void _showReportOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            localizations!.generateReport,
            style: context.bodyLargeText,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localizations!.selectFormatToExport),
              const SizedBox(height: 16),
              // Share Products Catalogue - First option
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Share Products Catalogue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showCatalogueOptionsDialog();
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(localizations!.exportAsPdf),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _generateAndSharePDF();
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: Text(localizations!.exportAsCsvExcel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _generateAndShareCSV();
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations!.cancel),
            ),
          ],
        );
      },
    );
  }

  void _showCatalogueOptionsDialog() {
    bool includePrices = true; // Default to include prices

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Catalogue Options',
                style: TextStyle(color: context.bodyLargeText!.color),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choose what to include in your catalogue:'),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Include Product Prices'),
                    value: includePrices,
                    onChanged: (bool? value) {
                      setState(() {
                        includePrices = value ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _generateAndShareCatalogue(includePrices);
                  },
                  child: const Text('Generate Catalogue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Uint8List> _generateProductsCatalogue(bool includePrices) async {
    // Check for immediate cancellation
    if (_cancelGeneration) {
      throw Exception('Generation cancelled by user');
    }

    // Initialize progress
    setState(() {
      _generationProgress = 0.1; // 10% - Starting
    });

    final pdf = pw.Document();
    final now = DateTime.now();
    debugPrint('Generating product catalogue PDF');

    // Group all products by name and calculate total quantities
    setState(() {
      _generationProgress = 0.2; // 20% - Grouping products
    });

    // Check for cancellation after grouping
    if (_cancelGeneration) {
      throw Exception('Generation cancelled by user');
    }

    Map<String, Map<String, dynamic>> groupedProducts = {};
    // Use _filteredProducts instead of _boughtProducts to match UI display
    for (var product in _filteredProducts) {
      final productName = product.productName;
      if (!groupedProducts.containsKey(productName)) {
        groupedProducts[productName] = {
          'name': productName,
          'imageUrl': product.imageUrl,
          'unit': product.unit,
          'sellingPrice': product.sellingPrice,
          'totalQuantity': 0,
        };
      }
      groupedProducts[productName]!['totalQuantity'] += product.quantity;
    }

    final productsList = groupedProducts.values.toList();

    // Download images for products that have them - OPTIMIZED PARALLEL PROCESSING
    setState(() {
      _generationProgress = 0.3; // 30% - Starting image downloads
    });

    Map<String, Uint8List?> productImages = {};
    final totalProducts = productsList.length;

    // Process images in parallel batches for much faster performance
    const int batchSize =
        50; // Increased from 25 to 50 for better parallelization
    int processedCount = 0;

    for (int i = 0; i < productsList.length; i += batchSize) {
      // Check for cancellation
      if (_cancelGeneration) {
        setState(() {
          _isGeneratingReport = false;
          _generationProgress = 0.0;
          _cancelGeneration = false;
        });
        throw Exception('Generation cancelled by user');
      }

      final endIndex = (i + batchSize < productsList.length)
          ? i + batchSize
          : productsList.length;
      final batch = productsList.sublist(i, endIndex);

      // Process all images in this batch in parallel
      final batchResults = await Future.wait(
        batch.map((product) async {
          final imageUrl = product['imageUrl'] as String?;
          final productName = product['name'] as String;

          // Skip downloading if no image URL, but still add to map
          if (imageUrl == null || imageUrl.isEmpty) {
            return MapEntry(productName, null);
          }

          try {
            // Get and compress image for faster PDF generation
            final compressedImage = await _getCompressedImageForPDF(imageUrl);
            return MapEntry(productName, compressedImage);
          } catch (e) {
            debugPrint('Error processing image for $productName: $e');
            return MapEntry(productName, null);
          }
        }),
      );

      // Add batch results to the map
      for (final entry in batchResults) {
        productImages[entry.key] = entry.value;
      }

      processedCount += batch.length;

      // Update progress during image processing (30% to 70%)
      setState(() {
        _generationProgress = 0.3 + (0.4 * processedCount / totalProducts);
      });
    }

    // Check for cancellation before building PDF
    if (_cancelGeneration) {
      throw Exception('Generation cancelled by user');
    }

    // Build PDF content
    setState(() {
      _generationProgress = 0.8; // 80% - Building PDF content
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15), // Reduced margin for more space
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];

          // Shop Header - Optimized
          widgets.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(color: PdfColors.blue),
              child: pw.Column(
                children: [
                  pw.Text(
                    _shopName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Product Catalogue',
                    style: pw.TextStyle(fontSize: 16, color: PdfColors.white),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Generated on: ${now.toString().split('.')[0]}',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.white),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          );

          widgets.add(pw.SizedBox(height: 15));

          // Products Grid - 4 products per row (optimized for smaller images)
          const int productsPerRow = 4;
          for (int i = 0; i < productsList.length; i += productsPerRow) {
            List<pw.Widget> rowWidgets = [];

            for (
              int j = 0;
              j < productsPerRow && i + j < productsList.length;
              j++
            ) {
              final product = productsList[i + j];
              final productName = product['name'] as String;
              final imageBytes = productImages[productName];

              rowWidgets.add(
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.all(3),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        // Product Image (compressed to 200x200)
                        pw.Container(
                          width: 80,
                          height: 80,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          child: imageBytes != null
                              ? pw.ClipRRect(
                                  horizontalRadius: 6,
                                  verticalRadius: 6,
                                  child: pw.Image(
                                    pw.MemoryImage(imageBytes),
                                    fit: pw.BoxFit.cover,
                                  ),
                                )
                              : pw.Center(
                                  child: pw.Icon(
                                    const pw.IconData(
                                      0xe3f4,
                                    ), // inventory_2 icon
                                    size: 40,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                        ),
                        pw.SizedBox(height: 8),
                        // Product Name
                        pw.Text(
                          product['name'].toString().toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                          maxLines: 2,
                        ),
                        pw.SizedBox(height: 4),
                        // Quantity
                        pw.Text(
                          '${product['totalQuantity']} ${product['unit']}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.blue,
                            fontWeight: pw.FontWeight.normal,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        // Price (if included)
                        if (includePrices) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'RS ${(product['sellingPrice'] as double).toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }

            widgets.add(pw.Row(children: rowWidgets));

            // Add some space between rows (reduced for faster generation)
            if (i + productsPerRow < productsList.length) {
              widgets.add(pw.SizedBox(height: 6));
            }
          }

          // Footer
          widgets.add(pw.SizedBox(height: 20));
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Text(
                'Total Products: ${productsList.length}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    // Save PDF file
    setState(() {
      _generationProgress = 0.9; // 90% - Saving file
    });

    final pdfBytes = await pdf.save();

    debugPrint(
      'Catalogue PDF generated successfully (${pdfBytes.length} bytes)',
    );

    if (pdfBytes.isEmpty) {
      throw Exception('PDF bytes are empty');
    }

    // Complete
    setState(() {
      _generationProgress = 1.0; // 100% - Complete
    });

    return pdfBytes;
  }

  void _generateAndSharePDF() async {
    try {
      setState(() {
        _isGeneratingReport = true;
        _cancelGeneration = false;
        _generationProgress = 0.0;
      });

      final pdfBytes = await _generateProductsPDF();

      // Check if generation was cancelled after completion
      if (!_cancelGeneration) {
        // Generate file name using FileService
        final fileName = FileService.generateTimestampedFileName(
          'products_report',
          'pdf',
        );

        // Share file using FileService (same as catalogue)
        final result = await FileService.shareFile(
          fileBytes: pdfBytes,
          fileName: fileName,
          shareText: 'Products Report',
          subFolder: 'Products',
        );

        if (!result.success) {
          throw Exception(result.errorMessage ?? 'Failed to share PDF');
        }

        debugPrint('Products report shared successfully: ${result.filePath}');
      }
    } catch (e) {
      if (e.toString().contains('cancelled by user')) {
        // Show cancellation message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generation cancelled'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error generating PDF'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isGeneratingReport = false;
        _generationProgress = 0.0;
        _cancelGeneration = false;
      });
    }
  }

  void _generateAndShareCatalogue(bool includePrices) async {
    try {
      setState(() {
        _isGeneratingReport = true;
        _cancelGeneration = false;
        _generationProgress = 0.0;
      });

      // Ensure shop name is loaded before generating catalogue
      await _ensureShopNameLoaded();

      final pdfBytes = await _generateProductsCatalogue(includePrices);

      // Check if generation was cancelled after completion
      if (!_cancelGeneration) {
        // Generate file name using FileService
        final fileName = FileService.generateTimestampedFileName(
          includePrices ? 'product_catalogue_with_prices' : 'product_catalogue',
          'pdf',
        );

        // Share file using FileService (same as bill sharing)
        final result = await FileService.shareFile(
          fileBytes: pdfBytes,
          fileName: fileName,
          shareText: '$_shopName - Product Catalogue',
          subFolder: 'Catalogues',
        );

        if (!result.success) {
          throw Exception(result.errorMessage ?? 'Failed to share catalogue');
        }

        debugPrint('Catalogue shared successfully: ${result.filePath}');
      }
    } catch (e) {
      if (e.toString().contains('cancelled by user')) {
        // Show cancellation message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Catalogue generation cancelled'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating catalogue: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isGeneratingReport = false;
        _generationProgress = 0.0;
        _cancelGeneration = false;
      });
    }
  }

  void _generateAndShareCSV() async {
    try {
      final csvString = await _generateProductsCSV();

      if (mounted) {
        // Convert CSV string to bytes with UTF-8 BOM for Excel compatibility
        final utf8Bytes = utf8.encode(csvString);
        final bom = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
        final csvBytes = Uint8List.fromList([...bom, ...utf8Bytes]);

        // Generate file name using FileService
        final fileName = FileService.generateTimestampedFileName(
          'products_report',
          'csv',
        );

        // Share file using FileService (same as catalogue)
        final result = await FileService.shareFile(
          fileBytes: csvBytes,
          fileName: fileName,
          shareText: 'Products Report CSV',
          subFolder: 'Products',
        );

        if (!result.success) {
          throw Exception(result.errorMessage ?? 'Failed to share CSV');
        }

        debugPrint('CSV report shared successfully: ${result.filePath}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating CSV: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to create table cell widget
  pw.Widget _buildTableCell(
    String text, {
    bool isCenter = false,
    double fontSize = 8,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: fontSize),
        textAlign: isCenter ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  Future<Uint8List> _generateProductsPDF() async {
    if (_cancelGeneration) throw Exception('Generation cancelled by user');

    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    debugPrint('Generating products report PDF');

    // Filter out products with 0 quantity and sort alphabetically (A to Z)
    final productsWithStock =
        _filteredProducts.where((p) => p.quantity > 0).toList()..sort(
          (a, b) => a.productName.toLowerCase().compareTo(
            b.productName.toLowerCase(),
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header Section
            pw.Text(
              'Available Products Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Generated on: $formattedDate | Filter: ${_getFilterLabel(_selectedFilter)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 15),

            // Products Table
            pw.Table(
              border: pw.TableBorder.all(width: 1, color: PdfColors.grey400),
              columnWidths: const {
                0: pw.FixedColumnWidth(30),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(0.8),
                5: pw.FlexColumnWidth(1),
                6: pw.FlexColumnWidth(1),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children:
                      [
                            'S.N',
                            'Product Name',
                            'Supplier',
                            'Unit',
                            'Qty',
                            'Buying',
                            'Selling',
                          ]
                          .map(
                            (header) => pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                header,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          )
                          .toList(),
                ),
                // Data rows
                ...productsWithStock.asMap().entries.map((entry) {
                  final product = entry.value;
                  return pw.TableRow(
                    children: [
                      _buildTableCell(
                        (entry.key + 1).toString(),
                        isCenter: true,
                      ),
                      _buildTableCell(product.productName),
                      _buildTableCell(product.supplierName),
                      _buildTableCell(product.unit, isCenter: true),
                      _buildTableCell(
                        product.quantity.toString(),
                        isCenter: true,
                      ),
                      _buildTableCell(
                        'Rs.${product.buyingPrice.toStringAsFixed(2)}',
                        isCenter: true,
                      ),
                      _buildTableCell(
                        'Rs.${product.sellingPrice.toStringAsFixed(2)}',
                        isCenter: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Total Products: ${productsWithStock.length}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();
    debugPrint('Products report PDF generated (${pdfBytes.length} bytes)');

    if (pdfBytes.isEmpty) {
      throw Exception('PDF bytes are empty');
    }

    return pdfBytes;
  }

  Future<String> _generateProductsCSV() async {
    debugPrint('Generating products CSV report');

    // Filter out products with 0 quantity and sort alphabetically (A to Z)
    final productsWithStock =
        _filteredProducts.where((p) => p.quantity > 0).toList()..sort(
          (a, b) => a.productName.toLowerCase().compareTo(
            b.productName.toLowerCase(),
          ),
        );

    // Create CSV header
    final csv = StringBuffer();
    csv.writeln(
      'S.No,Product Name,Supplier,Unit,Quantity,Buying Price,Selling Price,Filter Applied: ${_getFilterLabel(_selectedFilter)}',
    );

    // Add product rows - use products with stock sorted alphabetically
    for (var i = 0; i < productsWithStock.length; i++) {
      final product = productsWithStock[i];
      csv.writeln(
        '${i + 1},"${product.productName}","${product.supplierName}","${product.unit}",${product.quantity},Rs.${product.buyingPrice.toStringAsFixed(2)},Rs.${product.sellingPrice.toStringAsFixed(2)}',
      );
    }

    final csvString = csv.toString();
    debugPrint(
      'Products CSV report generated (${csvString.length} characters)',
    );

    if (csvString.isEmpty) {
      throw Exception('CSV content is empty');
    }

    return csvString;
  }

  /// Get compressed and optimized image for PDF - MUCH FASTER than full resolution
  Future<Uint8List?> _getCompressedImageForPDF(String imageUrl) async {
    try {
      // Try to get from cache first
      final cacheManager = DefaultCacheManager();
      final fileInfo = await cacheManager.getFileFromCache(imageUrl);

      Uint8List? imageBytes;

      if (fileInfo != null && fileInfo.file.existsSync()) {
        // Get cached image bytes
        imageBytes = await fileInfo.file.readAsBytes();
      } else {
        // Download with timeout if not cached
        final response = await http
            .get(Uri.parse(imageUrl))
            .timeout(
              const Duration(seconds: 8), // Reduced timeout
              onTimeout: () {
                throw Exception('Image download timeout');
              },
            );

        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
          // Cache the downloaded image
          await cacheManager.putFile(
            imageUrl,
            imageBytes,
            fileExtension: 'jpg',
          );
        }
      }

      if (imageBytes == null) return null;

      // Decode and compress image for PDF (200x200 is sufficient for catalogue)
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return imageBytes;

      // Resize to max 200x200 for PDF (maintains aspect ratio)
      final resized = img.copyResize(
        originalImage,
        width: 200,
        height: 200,
        interpolation: img.Interpolation.average,
      );

      // Encode as JPEG with 75% quality for smaller size
      final compressed = img.encodeJpg(resized, quality: 75);

      debugPrint(
        'Compressed image from ${imageBytes.length} to ${compressed.length} bytes',
      );
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('Error getting compressed image for $imageUrl: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Available Products'),
          centerTitle: false,
          automaticallyImplyLeading: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations!.availableProducts),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
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
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showReportOptionsDialog(context),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.grey.withValues(alpha: 0.2),
            ),
            height: 40,
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.account_circle, size: 35),
              onPressed: () async {
                AppNavigator.push(context, const MyProfile());
              },
              tooltip: localizations!.myProfile,
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // --- Search Bar (Toggle Visibility) ---
              if (_showSearchBar)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12.0,
                    right: 12.0,
                    top: 5,
                    bottom: 5.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 0,
                          offset: const Offset(0, 0),
                          spreadRadius: 1,
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withValues(alpha: 0.95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: context.bodyLargeText,
                      decoration: InputDecoration(
                        hintText: localizations!.searchProductOrSupplier,
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

              // --- Filter Chips ---
              if (!_showSearchBar) const SizedBox(height: 5),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 2.0,
                ),
                child: Row(
                  children: _filterOptions.map((option) {
                    return Row(
                      children: [
                        _buildFilterChip(option['key']!, option['label']!),
                        if (option != _filterOptions.last)
                          const SizedBox(width: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),

              // --- Product List (Grouped by Name with Batch Details) ---
              const SizedBox(height: 5),
              Expanded(
                child: _filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          localizations!.noProductsFound,
                          style: context.subtitleMedium,
                        ),
                      )
                    : _buildGroupedProductList(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
          // Loading overlay for catalogue generation
          if (_isGeneratingReport)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      const Text(
                        'Generating Catalogue',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      Text(
                        'Please wait while we prepare your product catalogue...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Progress bar
                      Container(
                        width: double.infinity,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _generationProgress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Percentage text
                      Text(
                        '${(_generationProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Cancel button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _cancelGeneration = true;
                              _isGeneratingReport = false;
                              _generationProgress = 0.0;
                            });
                            // Show cancellation message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Catalogue generation cancelled'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.red.shade200),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build filter chip widget
  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    final cardColor = Theme.of(context).cardTheme.color;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 0,
            offset: const Offset(0, 0),
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          colors: [Colors.white, Colors.white.withValues(alpha: 0.95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = key;
          });
          _filterProducts();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: cardColor,
        selectedColor: Colors.blue.withValues(alpha: 0.2),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.5),
          width: 0.8,
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue : null,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: -1),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // Helper function to determine stock status key for filtering
  String _getStockStatusKey(int quantity, int minLimit) {
    if (quantity == 0) {
      return 'reorder_now';
    } else if (quantity <= minLimit) {
      return 'order_soon';
    } else {
      return 'well_stocked';
    }
  }

  // Helper function to determine stock status with descriptive text
  String _getStockStatus(int quantity, int minLimit) {
    if (quantity == 0) {
      return localizations!.reorderNow;
    } else if (quantity <= minLimit) {
      return localizations!.orderSoon;
    } else {
      return localizations!.wellStocked;
    }
  }

  // Helper function to get stock color
  Color _getStockColor(int quantity, int minLimit) {
    if (quantity == 0) {
      return Colors.red;
    } else if (quantity <= minLimit) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  // Build stock badge widget
  Widget _buildStockBadge(int quantity, int minLimit) {
    final stockStatus = _getStockStatus(quantity, minLimit);
    final stockColor = _getStockColor(quantity, minLimit);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: stockColor.withValues(alpha: 0.15),
        border: Border.all(color: stockColor, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            quantity < minLimit ? Icons.warning : Icons.check_circle,
            size: 12,
            color: stockColor,
          ),
          const SizedBox(width: 4),
          Text(
            stockStatus,
            style: TextStyle(
              color: stockColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // Build grouped product list with batch hierarchy
  Widget _buildGroupedProductList(BuildContext context) {
    // Group products by name
    Map<String, List<BoughtProduct>> groupedByName = {};
    for (final product in _filteredProducts) {
      if (!groupedByName.containsKey(product.productName)) {
        groupedByName[product.productName] = [];
      }
      groupedByName[product.productName]!.add(product);
    }

    // Sort batches by purchase date (oldest first - FIFO)
    for (final batches in groupedByName.values) {
      batches.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a.purchaseDate) ?? DateTime.now();
        DateTime dateB = DateTime.tryParse(b.purchaseDate) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });
    }

    // Sort product names alphabetically (A to Z)
    final sortedProductNames = groupedByName.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final cardColor = context.cardColor;

    // Limit products to currently loaded items
    final displayedProductNames = sortedProductNames
        .take(_currentlyLoadedItems)
        .toList();

    return ListView.builder(
      controller: _scrollController,
      itemCount: displayedProductNames.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= displayedProductNames.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final productName = displayedProductNames[index];
        final batches = groupedByName[productName]!;
        final totalQty = batches.fold<int>(0, (total, p) => total + p.quantity);

        // Filter only available batches (quantity > 0)
        final availableBatches = batches.where((p) => p.quantity > 0).toList();

        // Calculate min limit from available batches (use SUM of all min limits)
        final minLimitForStatus = availableBatches.fold(
          0,
          (int sum, p) => sum + p.minLimit,
        );

        final unit = batches.first.unit;
        final firstBatch = batches.first;

        // Calculate expiry details for description
        int expiringQuantity = 0;
        int? daysUntilNearestExpiry;
        DateTime? nearestExpiryDate;
        bool hasExpired = false;

        for (final batch in batches) {
          if (batch.expiryDate != null &&
              batch.expiryDate!.isNotEmpty &&
              batch.quantity > 0) {
            try {
              final parts = batch.expiryDate!.split('/');
              if (parts.length == 3) {
                final day = int.parse(parts[0]);
                final month = int.parse(parts[1]);
                final year = int.parse(parts[2]);
                final expiryDate = DateTime(year, month, day);
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final sixtyDaysFromNow = today.add(const Duration(days: 60));

                if (expiryDate.isBefore(today)) {
                  hasExpired = true;
                  expiringQuantity += batch.quantity;
                  if (nearestExpiryDate == null ||
                      expiryDate.isBefore(nearestExpiryDate)) {
                    nearestExpiryDate = expiryDate;
                    daysUntilNearestExpiry = expiryDate
                        .difference(today)
                        .inDays;
                  }
                } else if (expiryDate.isBefore(sixtyDaysFromNow) ||
                    expiryDate.isAtSameMomentAs(today)) {
                  expiringQuantity += batch.quantity;
                  if (nearestExpiryDate == null ||
                      expiryDate.isBefore(nearestExpiryDate)) {
                    nearestExpiryDate = expiryDate;
                    daysUntilNearestExpiry = expiryDate
                        .difference(today)
                        .inDays;
                  }
                }
              }
            } catch (e) {
              // Invalid date format, skip
            }
          }
        }

        // Determine border color based on expiry status
        Color borderColor = context.secondaryTextColor!.withValues(alpha: 0.1);
        double borderWidth = 1.0;

        if (hasExpired) {
          borderColor = Colors.red;
          borderWidth = 2.0;
        } else if (expiringQuantity > 0) {
          borderColor = Colors.orange;
          borderWidth = 2.0;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: borderColor.withValues(alpha: 0.1),
                blurRadius: 0,
                offset: const Offset(0, 0),
                spreadRadius: borderWidth,
              ),
            ],
            gradient: LinearGradient(
              colors: [
                cardColor ?? Colors.white,
                (cardColor ?? Colors.white).withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16.0),
            child: Stack(
              children: [
                InkWell(
                  onTap: () {
                    AppNavigator.push(
                      context,
                      AvailableProductDetailScreen(
                        product: firstBatch,
                        userId: _currentUserId,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16.0),
                  splashColor: Colors.blue.withValues(alpha: 0.1),
                  highlightColor: Colors.blue.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Product Image (if available) - Left side
                        if (firstBatch.imageUrl != null &&
                            firstBatch.imageUrl!.isNotEmpty)
                          Container(
                            width: 48,
                            height: 48,
                            margin: const EdgeInsets.only(right: 12.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: firstBatch.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey.shade50,
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).primaryColor,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey.shade100,
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 24,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 48,
                            height: 48,
                            margin: const EdgeInsets.only(right: 12.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.blue.shade50,
                              border: Border.all(
                                color: Colors.blue.shade100,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.inventory_2,
                              color: Colors.blue.shade600,
                              size: 24,
                            ),
                          ),

                        // Product Details - Center
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Name with modern styling
                              Text(
                                productName[0].toUpperCase() +
                                    productName.substring(1),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                      letterSpacing: 0.5,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),

                              // Unit and Quantity with modern chips
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.straighten,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          unit,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 14,
                                          color: Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$totalQty',
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStockBadge(totalQty, minLimitForStatus),
                                ],
                              ),

                              // Expiry warning with modern styling
                              if (expiringQuantity > 0) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (hasExpired
                                                ? Colors.red
                                                : Colors.orange)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          (hasExpired
                                                  ? Colors.red
                                                  : Colors.orange)
                                              .withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        hasExpired
                                            ? Icons.error_outline
                                            : Icons.warning_amber_rounded,
                                        size: 14,
                                        color: hasExpired
                                            ? Colors.red[700]
                                            : (daysUntilNearestExpiry != null &&
                                                  daysUntilNearestExpiry < 30)
                                            ? Colors.red[700]
                                            : Colors.orange[700],
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          hasExpired
                                              ? localizations!.expiredText
                                                    .replaceAll(
                                                      '{quantity}',
                                                      expiringQuantity
                                                          .toString(),
                                                    )
                                                    .replaceAll('{unit}', unit)
                                              : daysUntilNearestExpiry == 0
                                              ? localizations!.expiringToday
                                                    .replaceAll(
                                                      '{quantity}',
                                                      expiringQuantity
                                                          .toString(),
                                                    )
                                                    .replaceAll('{unit}', unit)
                                              : daysUntilNearestExpiry == 1
                                              ? localizations!.expiringTomorrow
                                                    .replaceAll(
                                                      '{quantity}',
                                                      expiringQuantity
                                                          .toString(),
                                                    )
                                                    .replaceAll('{unit}', unit)
                                              : localizations!.expiringInDays
                                                    .replaceAll(
                                                      '{quantity}',
                                                      expiringQuantity
                                                          .toString(),
                                                    )
                                                    .replaceAll('{unit}', unit)
                                                    .replaceAll(
                                                      '{days}',
                                                      daysUntilNearestExpiry
                                                          .toString(),
                                                    ),
                                          style: TextStyle(
                                            color: hasExpired
                                                ? Colors.red[800]
                                                : (daysUntilNearestExpiry !=
                                                          null &&
                                                      daysUntilNearestExpiry <
                                                          30)
                                                ? Colors.red[800]
                                                : Colors.orange[800],
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- Data Model for Bought Products ---
class BoughtProduct {
  final String id;
  final String date;
  final String productName;
  final String supplierName;
  final String unit;
  final String? expiryDate;
  final int minLimit;
  final int quantity;
  final double buyingPrice;
  final double sellingPrice;
  final String batchId; // Unique identifier for this batch
  final String purchaseDate; // Date when batch was purchased
  final double profitMargin; // Profit per unit (sellingPrice - buyingPrice)
  final String? imageUrl; // Product image URL

  BoughtProduct({
    required this.id,
    required this.date,
    required this.productName,
    required this.supplierName,
    required this.unit,
    this.expiryDate,
    required this.minLimit,
    required this.quantity,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.batchId,
    required this.purchaseDate,
    required this.profitMargin,
    this.imageUrl,
  });

  factory BoughtProduct.fromMap(
    String id,
    Map<dynamic, dynamic> data, {
    String? entryDate,
  }) {
    final buyPrice = (data['buyingPrice'] ?? 0).toDouble();
    final sellPrice = (data['sellingPrice'] ?? 0).toDouble();
    final margin = sellPrice - buyPrice;

    return BoughtProduct(
      id: id,
      date: entryDate ?? data['timestamp'] ?? '',
      productName: data['productName'] ?? 'Unknown',
      supplierName: data['supplierName'] ?? 'Unknown',
      unit: data['unit'] ?? '',
      expiryDate: data['expiryDate'] as String?,
      minLimit: data['minLimit'] ?? 0,
      quantity: data['quantity'] ?? 0,
      buyingPrice: buyPrice,
      sellingPrice: sellPrice,
      batchId: data['batchId'] ?? id, // Fallback to id if not present
      purchaseDate: data['purchaseDate'] ?? data['date'] ?? '',
      profitMargin: margin,
      imageUrl: data['imageUrl'] as String?,
    );
  }

  BoughtProduct copyWith({
    String? id,
    String? date,
    String? productName,
    String? supplierName,
    String? unit,
    String? expiryDate,
    int? minLimit,
    int? quantity,
    double? buyingPrice,
    double? sellingPrice,
    String? batchId,
    String? purchaseDate,
    double? profitMargin,
    String? imageUrl,
  }) {
    return BoughtProduct(
      id: id ?? this.id,
      date: date ?? this.date,
      productName: productName ?? this.productName,
      supplierName: supplierName ?? this.supplierName,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      minLimit: minLimit ?? this.minLimit,
      quantity: quantity ?? this.quantity,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      batchId: batchId ?? this.batchId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      profitMargin: profitMargin ?? this.profitMargin,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
