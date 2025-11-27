import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:nkt/navigation/app_navigator.dart';
import 'package:nkt/pages/products/available_product_item_detail.dart';

class AvailableProducts extends StatefulWidget {
  const AvailableProducts({super.key});

  @override
  State<AvailableProducts> createState() => _AvailableProductsState();
}

class _AvailableProductsState extends State<AvailableProducts> {
  late DatabaseReference _boughtProductsRef;
  late String _userId;
  late List<BoughtProduct> _boughtProducts;
  late List<BoughtProduct> _filteredProducts;
  bool _isLoading = true;
  bool _showSearchBar = false;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Reorder Now', 'Order Soon', 'Well Stocked'
  late TextEditingController _searchController;
  StreamSubscription<DatabaseEvent>? _productsSubscription;
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
      _boughtProductsRef = FirebaseDatabase.instance.ref(
        'purchased-products/$_userId',
      );
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
        final database = FirebaseDatabase.instance;
        final snapshot = await database.ref('shop-profile/${user.uid}/shopName').get();
        if (snapshot.exists) {
          if (mounted) {
            setState(() {
              _shopName = snapshot.value.toString();
            });
          }
        }
      }
    } catch (e) {
      print('Error loading shop name: $e');
    }
  }

  void _loadProductsFromDatabase() {
    _productsSubscription = _boughtProductsRef.onValue.listen((
      DatabaseEvent event,
    ) {
      if (!mounted) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      final loadedProducts = <BoughtProduct>[];

      if (data != null) {
        // Iterate through purchased products directly
        for (var entry in data.entries) {
          final productData = entry.value as Map<dynamic, dynamic>?;
          if (productData != null) {
            final product = BoughtProduct.fromMap(
              entry.key as String,
              productData,
            );
            
            loadedProducts.add(product);
          }
        }
      }

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
      // Apply search filter
      var filtered = _boughtProducts;
      if (_searchQuery.isNotEmpty) {
        filtered = filtered
            .where(
              (product) =>
                  product.productName.toLowerCase().contains(_searchQuery) ||
                  product.supplierName.toLowerCase().contains(_searchQuery),
            )
            .toList();
      }

      // Apply status filter
      if (_selectedFilter != 'All') {
        filtered = filtered
            .where((product) =>
                _getStockStatus(product.quantity, product.minLimit) ==
                _selectedFilter)
            .toList();
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
          title: Text('Generate Report', style: TextStyle(color: primaryTextColor),),
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

        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          text: 'Available Products Report from $_shopName',
        );
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
        await Share.shareXFiles(
          [XFile(csvFile.path)],
          text: 'Available Products Report (CSV) from $_shopName',
        );
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
    final dateTimeString = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
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
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated on: ${now.toString().split('.')[0]}',
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
                    children: [
                      'S.No.',
                      'Product Name',
                      'Supplier',
                      'Unit',
                      'Qty',
                      'Buying',
                      'Selling',
                    ]
                        .map((header) => pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                header,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ))
                        .toList(),
                  ),
                  // Data rows
                  ..._boughtProducts.asMap().entries.map((entry) {
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
                            '₹${product.buyingPrice.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            '₹${product.sellingPrice.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total Products: ${_boughtProducts.length}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
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
    final dateTimeString = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/products_report_$dateTimeString.csv');

    // Create CSV header
    final csv = StringBuffer();
    csv.writeln('S.No.,Product Name,Supplier,Unit,Quantity,Buying Price,Selling Price,Stock Status,Min Limit');

    // Add product rows
    for (var i = 0; i < _boughtProducts.length; i++) {
      final product = _boughtProducts[i];
      final status = _getStockStatus(product.quantity, product.minLimit);
      csv.writeln('${i + 1},"${product.productName}","${product.supplierName}","${product.unit}",${product.quantity},${product.buyingPrice.toStringAsFixed(2)},${product.sellingPrice.toStringAsFixed(2)},"$status",${product.minLimit}');
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
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
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showReportOptionsDialog(context),
            ),
          ),
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
                top: 0,
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Reorder Now'),
                const SizedBox(width: 8),
                _buildFilterChip('Order Soon'),
                const SizedBox(width: 8),
                _buildFilterChip('Well Stocked'),
              ],
            ),
          ),

          // --- Product List ---
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Text(
                      'No products found',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductItem(
                        context,
                        product.productName,
                        product.unit,
                        product.quantity.toString(),
                        product.supplierName,
                        product.buyingPrice,
                        product.sellingPrice,
                        product,
                      );
                    },
                  ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: cardColor,
      selectedColor: Colors.blue.withOpacity(0.3),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.5),
        width: isSelected ? 2 : 1,
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
    if (quantity <= minLimit) {
      return 'Reorder Now';
    } else if (quantity <= minLimit + (minLimit ~/ 2)) {
      return 'Order Soon';
    } else {
      return 'Well Stocked';
    }
  }

  // Helper function to get stock color
  Color _getStockColor(int quantity, int minLimit) {
    if (quantity <= minLimit) {
      return Colors.red;
    } else if (quantity <= minLimit + (minLimit ~/ 2)) {
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

  // Helper widget for the product list item (the Card/Tile)
  Widget _buildProductItem(
    BuildContext context,
    String productName,
    String unit,
    String quantity,
    String supplierName,
    double buyingPrice,
    double sellingPrice,
    BoughtProduct product,
  ) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(
          color: secondaryTextColor!.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          AppNavigator.push(
            context,
            AvailableProductDetailScreen(product: product, userId: _currentUserId),
          );
        },
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Name & Supplier with Stock Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName[0].toUpperCase() + productName.substring(1),
                          style: TextStyle(
                            color: primaryTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supplier: $supplierName',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStockBadge(product.quantity, product.minLimit),
                ],
              ),
              const SizedBox(height: 10),
              // Unit and Quantity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Unit: $unit',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  Text(
                    'Qty: $quantity',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Prices
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Buying: ₹${buyingPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.red[400], fontSize: 11),
                  ),
                  Text(
                    'Selling: ₹${sellingPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green[400], fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
  final int minLimit;
  final int quantity;
  final double buyingPrice;
  final double sellingPrice;

  BoughtProduct({
    required this.id,
    required this.date,
    required this.productName,
    required this.supplierName,
    required this.unit,
    required this.minLimit,
    required this.quantity,
    required this.buyingPrice,
    required this.sellingPrice,
  });

  factory BoughtProduct.fromMap(String id, Map<dynamic, dynamic> data,
      {String? entryDate}) {
    return BoughtProduct(
      id: id,
      date: entryDate ?? data['timestamp'] ?? '',
      productName: data['productName'] ?? 'Unknown',
      supplierName: data['supplierName'] ?? 'Unknown',
      unit: data['unit'] ?? '',
      minLimit: data['minLimit'] ?? 0,
      quantity: data['quantity'] ?? 0,
      buyingPrice: (data['buyingPrice'] ?? 0).toDouble(),
      sellingPrice: (data['sellingPrice'] ?? 0).toDouble(),
    );
  }
}
