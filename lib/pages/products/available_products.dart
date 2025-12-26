import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/products/available_product_item_detail.dart';

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
  String _selectedFilter =
      'All'; // 'All', 'Reorder Now', 'Order Soon', 'Well Stocked'
  late TextEditingController _searchController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _productsSubscription;
  String _shopName = '--';
  String get _currentUserId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterProducts);
    _getUserAndLoadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _productsSubscription?.cancel();
    super.dispose();
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
        final snapshot = await FirebaseFirestore.instance
            .collection('shop-profile')
            .doc(user.uid)
            .get();
        if (snapshot.exists) {
          if (mounted) {
            setState(() {
              _shopName = (snapshot.data()?['shopName'] as String?) ?? '--';
            });
          }
        }
      }
    } catch (e) {
      print('Error loading shop name: $e');
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
          if (productName.toLowerCase().contains(_searchQuery)) {
            filtered.addAll(batches);
          }
        });
      } else {
        groupedByName.values.forEach((batches) => filtered.addAll(batches));
      }

      // Apply status filter - check consolidated quantity
      if (_selectedFilter != 'All') {
        filtered = filtered.where((product) {
          // Handle Expired filter separately
          if (_selectedFilter == 'Expired') {
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
          if (_selectedFilter == 'Expiring Soon') {
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

          return _getStockStatus(totalQty, minLimitForStatus) ==
              _selectedFilter;
        }).toList();
      }

      _filteredProducts = filtered;
    });
  }

  void _showReportOptionsDialog(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Generate Report',
            style: TextStyle(color: primaryTextColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select format to export products data:'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export as PDF'),
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
                  label: const Text('Export as CSV (Excel)'),
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
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Products',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChipForBottomSheet('All', setModalState),
                      _buildFilterChipForBottomSheet(
                        'Expiring Soon',
                        setModalState,
                      ),
                      _buildFilterChipForBottomSheet('Expired', setModalState),
                      _buildFilterChipForBottomSheet(
                        'Reorder Now',
                        setModalState,
                      ),
                      _buildFilterChipForBottomSheet(
                        'Order Soon',
                        setModalState,
                      ),
                      _buildFilterChipForBottomSheet(
                        'Well Stocked',
                        setModalState,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChipForBottomSheet(
    String label,
    StateSetter setModalState,
  ) {
    final isSelected = _selectedFilter == label;
    final cardColor = Theme.of(context).cardTheme.color;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
        setModalState(() {
          _selectedFilter = label;
        });
        _filterProducts();
        Navigator.pop(context); // Close bottom sheet after selection
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cardColor,
      selectedColor: Colors.blue.withOpacity(0.3),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.5),
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _generateAndSharePDF() async {
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

      final pdfFile = await _generateProductsPDF();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        await Share.shareXFiles([
          XFile(pdfFile.path),
        ], text: 'Available Products Report from $_shopName');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateAndShareCSV() async {
    try {
      final csvFile = await _generateProductsCSV();

      if (mounted) {
        await Share.shareXFiles([
          XFile(csvFile.path),
        ], text: 'Available Products Report (CSV) from $_shopName');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<File> _generateProductsPDF() async {
    final pdf = pw.Document();
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final dateTimeString =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/products_report_$dateTimeString.pdf');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text(
                '$_shopName - Available Products Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated on: ${now.toString().split('.')[0]} | Filter: $_selectedFilter',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 20),

              // Products Table
              pw.Table(
                border: pw.TableBorder.all(width: 1),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1),
                  6: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children:
                        [
                              'S.No.',
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
                  // Data rows - use filtered products
                  ..._filteredProducts.asMap().entries.map((entry) {
                    final product = entry.value;
                    final index = entry.key + 1;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            index.toString(),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            product.productName,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            product.supplierName,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            product.unit,
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            product.quantity.toString(),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'Rs.${product.buyingPrice.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'Rs.${product.sellingPrice.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total Products: ${_filteredProducts.length}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> _generateProductsCSV() async {
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final dateTimeString =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/products_report_$dateTimeString.csv');

    // Create CSV header
    final csv = StringBuffer();
    csv.writeln(
      'S.No.,Product Name,Supplier,Unit,Quantity,Buying Price,Selling Price,Stock Status,Min Limit,Filter Applied: $_selectedFilter',
    );

    // Add product rows - use filtered products
    for (var i = 0; i < _filteredProducts.length; i++) {
      final product = _filteredProducts[i];
      final status = _getStockStatus(product.quantity, product.minLimit);
      csv.writeln(
        '${i + 1},"${product.productName}","${product.supplierName}","${product.unit}",${product.quantity},Rs.${product.buyingPrice.toStringAsFixed(2)},Rs.${product.sellingPrice.toStringAsFixed(2)},"$status",${product.minLimit}',
      );
    }

    await file.writeAsString(csv.toString());
    return file;
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

    // Get theme colors
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Products'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          if (Platform.isAndroid || Platform.isIOS)
            IconButton(
              onPressed: _showFilterBottomSheet,
              icon: const Icon(Icons.filter_alt_sharp),
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
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showReportOptionsDialog(context),
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
      body: Column(
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
              child: Card(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    hintText: 'Search product or supplier',
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
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

          // --- Filter Chips ---
          if (!_showSearchBar) const SizedBox(height: 5),
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 2.0,
              ),
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Expiring Soon'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Expired'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Reorder Now'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Order Soon'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Well Stocked'),
                ],
              ),
            ),

          // --- Product List (Grouped by Name with Batch Details) ---
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Text(
                      'No products found',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  )
                : _buildGroupedProductList(context),
          ),
        ],
      ),
    );
  }

  // Build filter chip widget
  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    final cardColor = Theme.of(context).cardTheme.color;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
        _filterProducts();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cardColor,
      selectedColor: Colors.blue.withOpacity(0.3),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.5),
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // Helper function to determine stock status with descriptive text
  String _getStockStatus(int quantity, int minLimit) {
    if (quantity == 0) {
      return 'Reorder Now';
    } else if (quantity <= minLimit) {
      return 'Order Soon';
    } else {
      return 'Well Stocked';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: stockColor.withOpacity(0.2),
        border: Border.all(color: stockColor, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            quantity < minLimit ? Icons.warning : Icons.check_circle,
            size: 16,
            color: stockColor,
          ),
          const SizedBox(width: 6),
          Text(
            stockStatus,
            style: TextStyle(
              color: stockColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
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

    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return ListView.builder(
      itemCount: sortedProductNames.length,
      itemBuilder: (context, index) {
        final productName = sortedProductNames[index];
        final batches = groupedByName[productName]!;
        final totalQty = batches.fold<int>(0, (sum, p) => sum + p.quantity);

        // Filter only available batches (quantity > 0)
        final availableBatches = batches.where((p) => p.quantity > 0).toList();

        // Calculate min limit from available batches (use SUM of all min limits)
        final minLimitForStatus = availableBatches.fold(
          0,
          (sum, p) => sum + p.minLimit,
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
        Color borderColor = secondaryTextColor!.withOpacity(0.1);
        double borderWidth = 1.0;

        if (hasExpired) {
          borderColor = Colors.red;
          borderWidth = 2.0;
        } else if (expiringQuantity > 0) {
          borderColor = Colors.orange;
          borderWidth = 2.0;
        }

        return Card(
          color: cardColor,
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(color: borderColor, width: borderWidth),
          ),
          child: InkWell(
            onTap: () {
              AppNavigator.push(
                context,
                AvailableProductDetailScreen(
                  product: firstBatch,
                  userId: _currentUserId,
                ),
              );
            },
            borderRadius: BorderRadius.circular(10.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name
                        Text(
                          productName[0].toUpperCase() +
                              productName.substring(1),
                          style: TextStyle(
                            color: primaryTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Unit and Total Qty
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Unit: $unit',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total: $totalQty',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        // Expiry description at bottom
                        if (expiringQuantity > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                hasExpired
                                    ? Icons.error_outline
                                    : Icons.warning_amber_rounded,
                                size: 12,
                                color: hasExpired
                                    ? Colors.red
                                    : (daysUntilNearestExpiry != null &&
                                          daysUntilNearestExpiry < 30)
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  hasExpired
                                      ? '$expiringQuantity $unit expired'
                                      : daysUntilNearestExpiry == 0
                                      ? '$expiringQuantity $unit expiring today'
                                      : daysUntilNearestExpiry == 1
                                      ? '$expiringQuantity $unit expiring tomorrow'
                                      : '$expiringQuantity $unit expiring in $daysUntilNearestExpiry days',
                                  style: TextStyle(
                                    color: hasExpired
                                        ? Colors.red
                                        : (daysUntilNearestExpiry != null &&
                                              daysUntilNearestExpiry < 30)
                                        ? Colors.red
                                        : Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Stock badge
                  _buildStockBadge(totalQty, minLimitForStatus),
                ],
              ),
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
    );
  }
}
