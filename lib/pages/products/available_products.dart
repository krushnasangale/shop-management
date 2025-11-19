import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Reorder Now', 'Order Soon', 'Well Stocked'
  late TextEditingController _searchController;
  StreamSubscription<DatabaseEvent>? _productsSubscription;
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
      _loadProductsFromDatabase();
    } else {
      setState(() {
        _isLoading = false;
        _boughtProducts = [];
        _filteredProducts = [];
      });
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
        actions: const [
          // Three vertical dots menu icon
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Search Bar ---
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName[0].toUpperCase() + productName.substring(1),
                        style: TextStyle(
                          color: primaryTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supplier: $supplierName',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStockBadge(product.quantity, product.minLimit),
                    ],
                  ),
                ],
              ),
              // Unit and Quantity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Unit: $unit',
                    style: TextStyle(color: secondaryTextColor, fontSize: 13),
                  ),
                  Text(
                    'Qty: $quantity',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              // Prices
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Buying: ₹${buyingPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.red[400], fontSize: 12),
                  ),
                  Text(
                    'Selling: ₹${sellingPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green[400], fontSize: 12),
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
