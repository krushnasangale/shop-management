import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flashbill/pages/products/available_products.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';

class AvailableProductDetailScreen extends StatefulWidget {
  final BoughtProduct product;
  final String userId; // Pass userId for correct database path

  const AvailableProductDetailScreen({
    super.key,
    required this.product,
    required this.userId,
  });

  @override
  State<AvailableProductDetailScreen> createState() =>
      _AvailableProductDetailScreenState();
}

class _AvailableProductDetailScreenState
    extends State<AvailableProductDetailScreen>
    with SingleTickerProviderStateMixin {
  // Local state for editable fields
  late TextEditingController _quantityController;
  late TextEditingController _minLimitController;
  late TabController _tabController;
  List<BoughtProduct> _allBatches = [];
  bool _isLoadingBatches = true;
  bool _editingMinLimit = false;
  final Map<String, bool> _editingBatchPrices = {};
  final Map<String, TextEditingController> _batchPriceControllers = {};
  final Map<String, bool> _editingBatchQuantities = {};
  final Map<String, TextEditingController> _batchQuantityControllers = {};
  List<Map<String, dynamic>> _purchaseHistory = []; // Complete purchase history
  List<Map<String, dynamic>> _filteredPurchaseHistory =
      []; // Filtered purchase history
  bool _isLoadingHistory = true;
  final Map<int, bool> _expandedPurchaseHistory = {};
  List<Map<String, dynamic>> _soldHistory = []; // Complete sold history
  List<Map<String, dynamic>> _filteredSoldHistory = []; // Filtered sold history
  bool _isLoadingSoldHistory = true;
  final Map<int, bool> _expandedSoldHistory = {};
  final Map<int, bool> _expandedBatches = {};

  // Search and filter state for purchases
  late TextEditingController _searchController;
  String _sortBy = 'date'; // date, amount, supplier, profit
  bool _sortAscending = false;
  String _filterSupplier = 'all';

  // Search and filter state for sales
  late TextEditingController _searchSalesController;
  String _sortSalesBy = 'date'; // date, amount, customer, profit
  bool _sortSalesAscending = false;
  String _filterCustomer = 'all';

  @override
  void initState() {
    super.initState();

    // Initialize TabController
    _tabController = TabController(length: 3, vsync: this);

    // Initialize search controllers
    _searchController = TextEditingController();
    _searchController.addListener(_filterAndSortPurchaseHistory);

    _searchSalesController = TextEditingController();
    _searchSalesController.addListener(_filterAndSortSoldHistory);

    // Initialize controllers with current product values
    _quantityController = TextEditingController(
      text: widget.product.quantity.toString(),
    );

    // Calculate min limit from all available batches
    _minLimitController = TextEditingController();

    // Load all batches for this product
    _loadAllBatches();

    // Load complete purchase history for this product
    _loadPurchaseHistory();

    // Load complete sold history for this product
    _loadSoldHistory();
  }

  Future<void> _loadAllBatches() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(widget.userId)
          .collection('items')
          .get();

      final batches = <BoughtProduct>[];
      for (var doc in snapshot.docs) {
        final product = doc.data();
        final quantity = product['quantity'] ?? 0;

        // Only process batches with quantity > 0 and matching product name
        if (quantity > 0 &&
            product['productName'] == widget.product.productName) {
          final batch = BoughtProduct.fromMap(doc.id, product);
          batches.add(batch);
        }
      }

      // Sort by purchase date (oldest first for FIFO)
      batches.sort(
        (a, b) =>
            DateTime.tryParse(
              a.purchaseDate,
            )?.compareTo(DateTime.tryParse(b.purchaseDate) ?? DateTime.now()) ??
            0,
      );

      if (mounted) {
        // Calculate min limit - get it from the one batch that stores it (minLimit > 0)
        int minLimit = 0;
        for (var batch in batches) {
          if (batch.minLimit > 0) {
            minLimit = batch.minLimit;
            break;
          }
        }

        setState(() {
          _allBatches = batches;
          _isLoadingBatches = false;
          _minLimitController.text = minLimit.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBatches = false;
        });
      }
    }
  }

  Future<void> _loadPurchaseHistory() async {
    try {
      // Read from the product-purchase-history collection and aggregate by product name
      final snapshot = await FirebaseFirestore.instance
          .collection('product-purchase-history')
          .doc(widget.userId)
          .collection('items')
          .get();

      final history = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final item = doc.data();

        // Match by product name to aggregate across all suppliers
        if (item['productName'] == widget.product.productName) {
          history.add(item);
        }
      }

      // Sort by date (newest first)
      history.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _purchaseHistory = history;
          _filteredPurchaseHistory = history;
          _isLoadingHistory = false;
        });
        _filterAndSortPurchaseHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  // Filter and sort purchase history
  void _filterAndSortPurchaseHistory() {
    setState(() {
      // First filter
      _filteredPurchaseHistory = _purchaseHistory.where((purchase) {
        // Filter by search query
        final searchQuery = _searchController.text.toLowerCase();
        final supplierName = (purchase['supplierName'] ?? '')
            .toString()
            .toLowerCase();
        final date = (purchase['date'] ?? '').toString().toLowerCase();

        if (searchQuery.isNotEmpty &&
            !supplierName.contains(searchQuery) &&
            !date.contains(searchQuery)) {
          return false;
        }

        // Filter by supplier
        if (_filterSupplier != 'all' &&
            purchase['supplierName'] != _filterSupplier) {
          return false;
        }

        return true;
      }).toList();

      // Then sort
      _filteredPurchaseHistory.sort((a, b) {
        int comparison = 0;

        switch (_sortBy) {
          case 'date':
            DateTime dateA =
                DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
            DateTime dateB =
                DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
            comparison = dateA.compareTo(dateB);
            break;
          case 'amount':
            comparison = ((a['total'] ?? 0) as num).compareTo(
              (b['total'] ?? 0) as num,
            );
            break;
          case 'supplier':
            comparison = (a['supplierName'] ?? '').toString().compareTo(
              (b['supplierName'] ?? '').toString(),
            );
            break;
          case 'profit':
            final profitA =
                ((a['sellingPrice'] ?? 0) - (a['buyingPrice'] ?? 0)) *
                (a['quantity'] ?? 0);
            final profitB =
                ((b['sellingPrice'] ?? 0) - (b['buyingPrice'] ?? 0)) *
                (b['quantity'] ?? 0);
            comparison = profitA.compareTo(profitB);
            break;
        }

        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  // Get unique suppliers for filter
  List<String> _getUniqueSuppliers() {
    final suppliers = _purchaseHistory
        .map((p) => (p['supplierName'] ?? 'Unknown').toString())
        .toSet()
        .toList();
    suppliers.sort();
    return suppliers;
  }

  // Group purchases by date
  Map<String, List<Map<String, dynamic>>> _groupPurchasesByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();

    for (var purchase in _filteredPurchaseHistory.reversed) {
      final date = DateTime.tryParse(purchase['date'] ?? '') ?? DateTime(2000);

      String groupKey;
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        groupKey = 'Today';
      } else if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day - 1) {
        groupKey = 'Yesterday';
      } else if (now.difference(date).inDays < 7) {
        groupKey = 'This Week';
      } else if (date.year == now.year && date.month == now.month) {
        groupKey = 'This Month';
      } else if (date.year == now.year) {
        groupKey = 'This Year';
      } else {
        groupKey = 'Older';
      }

      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(purchase);
    }

    return grouped;
  }

  // Calculate summary statistics
  Map<String, dynamic> _calculateSummaryStats() {
    if (_filteredPurchaseHistory.isEmpty) {
      return {
        'totalPurchases': 0,
        'totalSpent': 0.0,
        'avgPurchaseValue': 0.0,
        'totalProfit': 0.0,
        'bestSupplier': 'N/A',
      };
    }

    double totalSpent = 0;
    double totalProfit = 0;
    final supplierSpending = <String, double>{};

    for (var purchase in _filteredPurchaseHistory) {
      final cost =
          ((purchase['buyingPrice'] ?? 0) as num) *
          ((purchase['quantity'] ?? 0) as num);
      final profit =
          (((purchase['sellingPrice'] ?? 0) as num) -
              ((purchase['buyingPrice'] ?? 0) as num)) *
          ((purchase['quantity'] ?? 0) as num);

      totalSpent += cost.toDouble();
      totalProfit += profit.toDouble();

      final supplier = (purchase['supplierName'] ?? 'Unknown').toString();
      supplierSpending[supplier] =
          (supplierSpending[supplier] ?? 0) + cost.toDouble();
    }

    String bestSupplier = 'N/A';
    if (supplierSpending.isNotEmpty) {
      bestSupplier = supplierSpending.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return {
      'totalPurchases': _filteredPurchaseHistory.length,
      'totalSpent': totalSpent,
      'avgPurchaseValue': totalSpent / _filteredPurchaseHistory.length,
      'totalProfit': totalProfit,
      'bestSupplier': bestSupplier,
    };
  }

  Future<void> _loadSoldHistory() async {
    try {
      // Read from the bills collection and extract products sold
      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .doc(widget.userId)
          .collection('items')
          .get();

      final history = <Map<String, dynamic>>[];
      for (var billDoc in snapshot.docs) {
        final billData = billDoc.data();
        final productsMap = billData['products'] as Map<String, dynamic>?;

        if (productsMap != null) {
          // Iterate through products in this bill
          for (var productEntry in productsMap.entries) {
            final product = productEntry.value as Map<String, dynamic>;

            // Match by product name
            if (product['productName'] == widget.product.productName) {
              history.add({
                'id': billDoc.id,
                'billId': billDoc.id,
                'date': billData['billDate'] ?? 'N/A',
                'timestamp': billData['timestamp'] ?? '',
                'customerName': billData['customerName'] ?? 'Unknown',
                'customerMobile': billData['customerMobile'] ?? '',
                'quantity': product['quantity'] ?? 0,
                'sellingPrice': product['price'] ?? 0,
                'total': product['total'] ?? 0,
                'unit': product['unit'] ?? 'units',
                'buyingPrice': product['boughtPrice'] ?? 0,
              });
            }
          }
        }
      }

      // Sort by timestamp (newest first)
      history.sort((a, b) {
        final timestampA = a['timestamp'] ?? '';
        final timestampB = b['timestamp'] ?? '';
        return timestampB.compareTo(timestampA);
      });

      if (mounted) {
        setState(() {
          _soldHistory = history;
          _filteredSoldHistory = history;
          _isLoadingSoldHistory = false;
        });
        _filterAndSortSoldHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSoldHistory = false;
        });
      }
    }
  }

  // Filter and sort sold history
  void _filterAndSortSoldHistory() {
    setState(() {
      // First filter
      _filteredSoldHistory = _soldHistory.where((sale) {
        // Filter by search query
        final searchQuery = _searchSalesController.text.toLowerCase();
        final customerName = (sale['customerName'] ?? '')
            .toString()
            .toLowerCase();
        final date = (sale['date'] ?? '').toString().toLowerCase();

        if (searchQuery.isNotEmpty &&
            !customerName.contains(searchQuery) &&
            !date.contains(searchQuery)) {
          return false;
        }

        // Filter by customer
        if (_filterCustomer != 'all' &&
            sale['customerName'] != _filterCustomer) {
          return false;
        }

        return true;
      }).toList();

      // Then sort
      _filteredSoldHistory.sort((a, b) {
        int comparison = 0;

        switch (_sortSalesBy) {
          case 'date':
            final timestampA = a['timestamp'] ?? '';
            final timestampB = b['timestamp'] ?? '';
            comparison = timestampA.compareTo(timestampB);
            break;
          case 'amount':
            comparison = ((a['total'] ?? 0) as num).compareTo(
              (b['total'] ?? 0) as num,
            );
            break;
          case 'customer':
            comparison = (a['customerName'] ?? '').toString().compareTo(
              (b['customerName'] ?? '').toString(),
            );
            break;
          case 'profit':
            final profitA =
                ((a['sellingPrice'] ?? 0) - (a['buyingPrice'] ?? 0)) *
                (a['quantity'] ?? 0);
            final profitB =
                ((b['sellingPrice'] ?? 0) - (b['buyingPrice'] ?? 0)) *
                (b['quantity'] ?? 0);
            comparison = profitA.compareTo(profitB);
            break;
        }

        return _sortSalesAscending ? comparison : -comparison;
      });
    });
  }

  // Get unique customers for filter
  List<String> _getUniqueCustomers() {
    final customers = _soldHistory
        .map((s) => (s['customerName'] ?? 'Unknown').toString())
        .toSet()
        .toList();
    customers.sort();
    return customers;
  }

  // Group sales by date
  Map<String, List<Map<String, dynamic>>> _groupSalesByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();

    for (var sale in _filteredSoldHistory.reversed) {
      DateTime date;
      if (sale['timestamp'] != null &&
          sale['timestamp'].toString().isNotEmpty) {
        date = DateTime.tryParse(sale['timestamp']) ?? DateTime(2000);
      } else if (sale['date'] != null) {
        date = DateTime.tryParse(sale['date']) ?? DateTime(2000);
      } else {
        date = DateTime(2000);
      }

      String groupKey;
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        groupKey = 'Today';
      } else if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day - 1) {
        groupKey = 'Yesterday';
      } else if (now.difference(date).inDays < 7) {
        groupKey = 'This Week';
      } else if (date.year == now.year && date.month == now.month) {
        groupKey = 'This Month';
      } else if (date.year == now.year) {
        groupKey = 'This Year';
      } else {
        groupKey = 'Older';
      }

      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(sale);
    }

    return grouped;
  }

  // Calculate summary stats for sales
  Map<String, dynamic> _calculateSalesSummaryStats() {
    if (_filteredSoldHistory.isEmpty) {
      return {'totalSales': 0, 'totalRevenue': 0.0, 'totalProfit': 0.0};
    }

    double totalRevenue = 0;
    double totalProfit = 0;

    for (var sale in _filteredSoldHistory) {
      final revenue = ((sale['total'] ?? 0) as num).toDouble();
      final profit =
          (((sale['sellingPrice'] ?? 0) as num) -
              ((sale['buyingPrice'] ?? 0) as num)) *
          ((sale['quantity'] ?? 0) as num);

      totalRevenue += revenue;
      totalProfit += profit.toDouble();
    }

    return {
      'totalSales': _filteredSoldHistory.length,
      'totalRevenue': totalRevenue,
      'totalProfit': totalProfit,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quantityController.dispose();
    _minLimitController.dispose();
    _searchController.dispose();
    _searchSalesController.dispose();
    // Dispose all batch price controllers
    for (var controller in _batchPriceControllers.values) {
      controller.dispose();
    }
    // Dispose all batch quantity controllers
    for (var controller in _batchQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- SAVE BATCH SELLING PRICE ---
  Future<void> _saveBatchSellingPrice(String batchId, double newPrice) async {
    try {
      await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(widget.userId)
          .collection('items')
          .doc(batchId)
          .update({'sellingPrice': newPrice});

      // Reload batches to reflect changes
      await _loadAllBatches();

      if (mounted) {
        setState(() {
          _editingBatchPrices[batchId] = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Selling price updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating price: $e')));
      }
    }
  }

  // --- SHOW EDIT QUANTITY DIALOG ---
  void _showEditQuantityDialog(BoughtProduct batch) {
    final quantityController = TextEditingController(
      text: batch.quantity.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Quantity', style: context.bodyLargeText),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity',
            hintText: 'Enter quantity',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(quantityController.text);
              if (newQuantity != null && newQuantity > 0) {
                _saveBatchQuantity(batch.id, newQuantity);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter valid quantity')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- SHOW EDIT SELLING PRICE DIALOG ---
  void _showEditSellingPriceDialog(BoughtProduct batch) {
    final priceController = TextEditingController(
      text: batch.sellingPrice.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Selling Price', style: context.bodyLargeText),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Selling Price',
            hintText: 'Enter price',
            prefix: const Text('₹'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice > 0) {
                _saveBatchSellingPrice(batch.id, newPrice);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter valid price')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- SAVE BATCH QUANTITY ---
  Future<void> _saveBatchQuantity(String batchId, int newQuantity) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Get the product batch to find the old quantity and purchaseId
      final batchDoc = await firestore
          .collection('purchased-products')
          .doc(widget.userId)
          .collection('items')
          .doc(batchId)
          .get();

      if (!batchDoc.exists) {
        throw Exception('Product batch not found');
      }

      final batchData = batchDoc.data()!;
      final oldQuantity = (batchData['quantity'] as num?)?.toInt() ?? 0;
      final oldInitialQuantity =
          (batchData['initialQuantity'] as num?)?.toInt() ?? 0;
      final buyingPrice = (batchData['buyingPrice'] as num?)?.toDouble() ?? 0.0;
      final purchaseId = batchData['purchaseId'] as String?;

      // Calculate the quantity difference and amount difference
      final quantityDifference = newQuantity - oldQuantity;
      final oldTotal = oldQuantity * buyingPrice;
      final newTotal = newQuantity * buyingPrice;
      final amountDifference = newTotal - oldTotal;

      // Calculate new initial quantity (adjust by the difference)
      final newInitialQuantity = oldInitialQuantity + quantityDifference;

      // Update the product batch quantity
      await firestore
          .collection('purchased-products')
          .doc(widget.userId)
          .collection('items')
          .doc(batchId)
          .update({
            'quantity': newQuantity,
            'initialQuantity': newInitialQuantity,
          });

      // Update the purchase record's totalUnits and totalAmount if purchaseId exists
      if (purchaseId != null && purchaseId.isNotEmpty) {
        final purchaseDoc = await firestore
            .collection('purchases')
            .doc(widget.userId)
            .collection('items')
            .doc(purchaseId)
            .get();

        if (purchaseDoc.exists) {
          final purchaseData = purchaseDoc.data()!;
          final currentTotalUnits =
              (purchaseData['totalUnits'] as num?)?.toInt() ?? 0;
          final currentTotalAmount =
              (purchaseData['totalAmount'] as num?)?.toDouble() ?? 0.0;

          final newTotalUnits = currentTotalUnits + quantityDifference;
          final newTotalAmount = currentTotalAmount + amountDifference;

          // Update the purchase record
          await firestore
              .collection('purchases')
              .doc(widget.userId)
              .collection('items')
              .doc(purchaseId)
              .update({
                'totalUnits': newTotalUnits > 0 ? newTotalUnits : 0,
                'totalAmount': newTotalAmount > 0 ? newTotalAmount : 0,
              });
        }
      }

      // Reload batches to reflect changes
      await _loadAllBatches();

      if (mounted) {
        setState(() {
          _editingBatchQuantities[batchId] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quantity and purchase record updated!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating quantity: $e')));
      }
    }
  }

  // --- FINANCIAL CALCULATIONS (From all batches with their individual prices) ---
  double get totalStockQty {
    if (_isLoadingBatches) return 0;
    return _allBatches.fold<double>(0, (double sum, b) => sum + b.quantity);
  }

  double get totalPotentialRevenue {
    if (_isLoadingBatches) return 0;
    double total = 0;
    for (var batch in _allBatches) {
      total += batch.sellingPrice * batch.quantity;
    }
    return total;
  }

  double get totalPotentialProfit {
    if (_isLoadingBatches) return 0;
    double totalProfit = 0;
    for (var batch in _allBatches) {
      totalProfit += (batch.sellingPrice - batch.buyingPrice) * batch.quantity;
    }
    return totalProfit;
  }

  double get averageBuyingPrice {
    if (_isLoadingBatches || totalStockQty == 0) {
      return widget.product.buyingPrice;
    }
    double totalCost = 0;
    for (var batch in _allBatches) {
      totalCost += batch.buyingPrice * batch.quantity;
    }
    return totalCost / totalStockQty;
  }

  double get averageSellingPrice {
    if (_isLoadingBatches || totalStockQty == 0) {
      return widget.product.sellingPrice;
    }
    return totalPotentialRevenue / totalStockQty;
  }

  double get profitMargin {
    final avgBuy = averageBuyingPrice;
    final avgSell = averageSellingPrice;
    if (avgBuy <= 0) return 0.0;
    return ((avgSell - avgBuy) / avgBuy) * 100;
  }

  // --- UI BUILDERS ---
  Widget _buildDetailRow(
    BuildContext context,
    String title,
    String subtitle, {
    IconData? icon,
    Color? valueColor,
  }) {
    // ... (implementation remains the same) ...

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: context.secondaryTextColor, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.secondaryTextColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: valueColor ?? context.primaryTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;

    // Calculate financial metrics
    final totalPotentialRevenue = this.totalPotentialRevenue;
    final totalPotentialProfit = this.totalPotentialProfit;
    final profitMargin = this.profitMargin;
    final avgBuyingPrice = averageBuyingPrice;
    final avgSellingPrice = averageSellingPrice;

    // Calculate total invested amount
    final totalInvestedAmount = _allBatches.fold<double>(
      0,
      (double sum, batch) => sum + (batch.buyingPrice * batch.quantity),
    );

    // Calculate total quantity by unit
    final totalQuantityByUnit = _allBatches.fold<Map<String, int>>({}, (
      map,
      batch,
    ) {
      map[batch.unit] = (map[batch.unit] ?? 0) + batch.quantity;
      return map;
    });

    // Capitalize product name for display
    final displayedProductName =
        widget.product.productName[0].toUpperCase() +
        widget.product.productName.substring(1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(displayedProductName),
        centerTitle: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [Colors.grey[850]!, Colors.grey[800]!]
                      : [Colors.white, Colors.grey[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey[200]!,
                  width: 1.5,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                padding: const EdgeInsets.all(4),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade500, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor:
                    Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 18),
                        const SizedBox(width: 6),
                        Text('Info'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Purchases',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('Sales', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // Confirm deletion
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Delete Product', style: context.bodyLargeText),
                  content: const Text(
                    'Are you sure you want to delete this product? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        try {
                          // Delete all batches of this product from purchased-products collection
                          final batchesSnapshot = await FirebaseFirestore
                              .instance
                              .collection('purchased-products')
                              .doc(widget.userId)
                              .collection('items')
                              .where(
                                'productName',
                                isEqualTo: widget.product.productName,
                              )
                              .get();

                          // Collect unique purchase IDs from all batches
                          Set<String> affectedPurchaseIds = {};
                          for (var doc in batchesSnapshot.docs) {
                            final purchaseId =
                                doc.data()['purchaseId'] as String?;
                            if (purchaseId != null && purchaseId.isNotEmpty) {
                              affectedPurchaseIds.add(purchaseId);
                            }
                          }

                          // Delete each batch
                          for (var doc in batchesSnapshot.docs) {
                            await doc.reference.delete();
                          }

                          // Update or delete affected purchase entries
                          for (String purchaseId in affectedPurchaseIds) {
                            // Get remaining items for this purchase
                            final remainingItems = await FirebaseFirestore
                                .instance
                                .collection('purchased-products')
                                .doc(widget.userId)
                                .collection('items')
                                .where('purchaseId', isEqualTo: purchaseId)
                                .get();

                            if (remainingItems.docs.isEmpty) {
                              // No items left, delete the purchase entry
                              await FirebaseFirestore.instance
                                  .collection('purchases')
                                  .doc(widget.userId)
                                  .collection('items')
                                  .doc(purchaseId)
                                  .delete();
                            } else {
                              // Recalculate purchase totals
                              double newTotalAmount = 0;
                              int newTotalUnits = 0;
                              int newTotalProducts = remainingItems.docs.length;

                              for (var doc in remainingItems.docs) {
                                final total = (doc['total'] ?? 0) as num;
                                final quantity =
                                    (doc['initialQuantity'] ?? 0) as num;
                                newTotalAmount += total.toDouble();
                                newTotalUnits += quantity.toInt();
                              }

                              // Update the purchase entry
                              await FirebaseFirestore.instance
                                  .collection('purchases')
                                  .doc(widget.userId)
                                  .collection('items')
                                  .doc(purchaseId)
                                  .update({
                                    'totalAmount': newTotalAmount,
                                    'totalUnits': newTotalUnits,
                                    'totalProducts': newTotalProducts,
                                  });
                            }
                          }

                          if (mounted) {
                            Navigator.of(context).pop(); // Close dialog
                            Navigator.of(
                              context,
                            ).pop(); // Go back after deletion
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${widget.product.productName} deleted successfully (${batchesSnapshot.docs.length} batches removed)',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop(); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting product: $e'),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Info Tab
          _buildInfoTab(
            context,
            cardColor,
            totalPotentialRevenue,
            totalPotentialProfit,
            profitMargin,
            totalInvestedAmount,
            avgBuyingPrice,
            avgSellingPrice,
            totalQuantityByUnit,
          ),
          // Purchase History Tab
          _buildPurchaseHistoryTab(context, cardColor),
          // Sold History Tab
          _buildSoldHistoryTab(context, cardColor),
        ],
      ),
    );
  }

  // Build Info Tab
  Widget _buildInfoTab(
    BuildContext context,
    Color cardColor,
    double totalPotentialRevenue,
    double totalPotentialProfit,
    double profitMargin,
    double totalInvestedAmount,
    double avgBuyingPrice,
    double avgSellingPrice,
    Map<String, int> totalQuantityByUnit,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 12, left: 12, top: 0, bottom: 12),
      child: Column(
        children: [
          // --- Total Quantity By Unit ---
          if (_allBatches.isNotEmpty)
            Card(
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_outlined,
                              color: Colors.indigo,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total Quantity',
                              style: context.bodyLargeText?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _allBatches
                                .fold(
                                  0,
                                  (int sum, batch) => sum + batch.quantity,
                                )
                                .toString(),
                            style: TextStyle(
                              color: Colors.purple[700],
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Group by unit and show individual totals
                    ..._allBatches
                        .fold<Map<String, int>>({}, (map, batch) {
                          map[batch.unit] =
                              (map[batch.unit] ?? 0) + batch.quantity;
                          return map;
                        })
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    entry.value.toString(),
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                    Divider(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]
                          : Colors.grey[300],
                      height: 12,
                    ),

                    // Minimum Limit Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Minimum Limit',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _editingMinLimit
                                ? SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _minLimitController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 6,
                                            ),
                                      ),
                                      style: context.bodyLargeText?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      _minLimitController.text,
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                        Row(
                          children: [
                            if (_editingMinLimit)
                              GestureDetector(
                                onTap: () {
                                  // Reload the original min limit
                                  int minLimit = 0;
                                  for (var batch in _allBatches) {
                                    if (batch.minLimit > 0) {
                                      minLimit = batch.minLimit;
                                      break;
                                    }
                                  }
                                  setState(() {
                                    _minLimitController.text = minLimit
                                        .toString();
                                    _editingMinLimit = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.red[600],
                                    size: 18,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                if (_editingMinLimit) {
                                  // Save the new min limit
                                  final newMinLimit =
                                      int.tryParse(_minLimitController.text) ??
                                      0;
                                  if (newMinLimit >= 0) {
                                    // Find the batch that stores minLimit and update it
                                    BoughtProduct? batchWithMinLimit;
                                    for (var batch in _allBatches) {
                                      if (batch.minLimit > 0) {
                                        batchWithMinLimit = batch;
                                        break;
                                      }
                                    }

                                    // If no batch has minLimit, use the first one
                                    batchWithMinLimit ??= _allBatches.isNotEmpty
                                        ? _allBatches.first
                                        : null;

                                    if (batchWithMinLimit != null) {
                                      FirebaseFirestore.instance
                                          .collection('purchased-products')
                                          .doc(widget.userId)
                                          .collection('items')
                                          .doc(batchWithMinLimit.id)
                                          .update({'minLimit': newMinLimit})
                                          .then((_) {
                                            setState(() {
                                              _editingMinLimit = false;
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Minimum limit updated',
                                                ),
                                              ),
                                            );
                                          })
                                          .catchError((e) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                              ),
                                            );
                                          });
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Enter a valid number'),
                                      ),
                                    );
                                  }
                                } else {
                                  setState(() {
                                    _editingMinLimit = true;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  _editingMinLimit ? Icons.check : Icons.edit,
                                  color: Colors.blue[600],
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),

          // --- 2. All Batches Card (Always show) ---
          Card(
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 12.0,
                left: 12.0,
                top: 12.0,
                bottom: 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _allBatches.length > 1
                            ? 'All Batches (FIFO Order)'
                            : 'Batch Details',
                        style: context.headingMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (_isLoadingBatches)
                    const Center(child: CircularProgressIndicator())
                  else if (_allBatches.isEmpty)
                    Center(
                      child: Text(
                        'No batches found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _allBatches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final batch = _allBatches[index];
                        final isFirstBatch = index == 0;
                        final isLastBatch = index == _allBatches.length - 1;
                        final isExpanded = _expandedBatches[index] ?? false;
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;

                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[200]!,
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Batch Tile (Always visible)
                              InkWell(
                                onTap: () => setState(() {
                                  _expandedBatches[index] = !isExpanded;
                                }),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Batch label with FIFO indicator
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isFirstBatch
                                                        ? Colors.orange
                                                              .withOpacity(0.15)
                                                        : Colors.blue
                                                              .withOpacity(
                                                                0.15,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    isFirstBatch
                                                        ? 'OLDEST (Sell First)'
                                                        : isLastBatch
                                                        ? 'NEWEST'
                                                        : 'Batch ${index + 1}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isFirstBatch
                                                          ? Colors.orange[700]
                                                          : Colors.blue[700],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Supplier name
                                            Text(
                                              batch.supplierName,
                                              style: context.bodyLargeText
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),

                                            // Quick info: Date and Quantity
                                            Text(
                                              '${batch.purchaseDate} • ${batch.quantity} ${batch.unit}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${batch.sellingPrice.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Icon(
                                            isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            color: Colors.blue[600],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Expanded content
                              if (isExpanded) ...[
                                Divider(
                                  color: isDark
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                                  height: 1,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Row 1: Quantity and Profit/Unit
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4.0,
                                        ),
                                        child: Row(
                                          children: [
                                            // Quantity
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.inventory_2_outlined,
                                                    color: Colors.grey,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Quantity',
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        GestureDetector(
                                                          onTap: () =>
                                                              _showEditQuantityDialog(
                                                                batch,
                                                              ),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Colors.blue
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    Colors.blue,
                                                                width: 1.5,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    6,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Text(
                                                                  '${batch.quantity} ${batch.unit}',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .blue[400],
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontSize:
                                                                        16,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Icon(
                                                                  Icons.edit,
                                                                  color: Colors
                                                                      .blue,
                                                                  size: 20,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Profit/Unit
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.trending_up,
                                                    color: Colors.grey,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Profit/Unit',
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          '₹${batch.profitMargin.toStringAsFixed(2)}',
                                                          style: TextStyle(
                                                            color:
                                                                batch.profitMargin >=
                                                                    0
                                                                ? Colors
                                                                      .green[400]
                                                                : Colors
                                                                      .red[400],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Row 2: Buying Price and Selling Price
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4.0,
                                        ),
                                        child: Row(
                                          children: [
                                            // Buying Price
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.shopping_cart,
                                                    color: Colors.grey,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Buying Price',
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          '₹${batch.buyingPrice.toStringAsFixed(2)}/${batch.unit}',
                                                          style: TextStyle(
                                                            color:
                                                                Colors.red[400],
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Selling Price
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.sell_outlined,
                                                    color: Colors.grey,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Selling Price',
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        GestureDetector(
                                                          onTap: () =>
                                                              _showEditSellingPriceDialog(
                                                                batch,
                                                              ),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Colors.blue
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    Colors.blue,
                                                                width: 1.5,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    6,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Flexible(
                                                                  child: Text(
                                                                    '₹${batch.sellingPrice.toStringAsFixed(2)}/${batch.unit}',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .green[400],
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Icon(
                                                                  Icons.edit,
                                                                  color: Colors
                                                                      .blue,
                                                                  size: 18,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (batch.expiryDate != null &&
                                          batch.expiryDate!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _buildDetailRow(
                                          context,
                                          'Expiry Date',
                                          batch.expiryDate!,
                                          icon: Icons.calendar_today,
                                          valueColor: Colors.orange[700],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- 3. Financial Metrics Card (Current Stock) ---
          Card(
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial Metrics (Current Stock)',
                    style: context.headingMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildDetailRow(
                    context,
                    'Total Potential Revenue',
                    '₹${totalPotentialRevenue.toStringAsFixed(2)}',
                    icon: Icons.trending_up,
                    valueColor: Colors.green,
                  ),
                  Divider(),

                  _buildDetailRow(
                    context,
                    'Total Potential Profit',
                    '₹${totalPotentialProfit.toStringAsFixed(2)}',
                    icon: Icons.paid_outlined,
                    valueColor: Colors.blue,
                  ),
                  Divider(),

                  _buildDetailRow(
                    context,
                    'Profit Margin (per unit)',
                    '${profitMargin.toStringAsFixed(1)}%',
                    icon: Icons.percent,
                    valueColor: profitMargin >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Build Purchase History Tab
  Widget _buildPurchaseHistoryTab(BuildContext context, Color cardColor) {
    final stats = _calculateSummaryStats();
    final groupedPurchases = _groupPurchasesByDate();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by supplier or date...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Filter and Sort Row
              SizedBox(
                height: 35,
                child: Row(
                  children: [
                    // Supplier Filter
                    Expanded(
                      child: InkWell(
                        onTap: () => _showSupplierFilterSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _filterSupplier == 'all'
                                      ? 'All Suppliers'
                                      : _filterSupplier,
                                  style: TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.filter_list,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort Button
                    Expanded(
                      child: InkWell(
                        onTap: () => _showPurchaseSortSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _sortBy == 'date'
                                      ? 'Date'
                                      : _sortBy == 'amount'
                                      ? 'Amount'
                                      : _sortBy == 'supplier'
                                      ? 'Supplier'
                                      : 'Profit',
                                  style: TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.sort,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort Direction Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: Colors.blue[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _sortAscending = !_sortAscending;
                          });
                          _filterAndSortPurchaseHistory();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 10, left: 10, bottom: 8),
            child: Column(
              children: [
                // Summary Statistics Card
                if (_purchaseHistory.isNotEmpty)
                  Card(
                    color: cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue[400]!,
                                      Colors.blue[700]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.analytics_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Summary Statistics',
                                style: context.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Stats Grid
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Total',
                                  stats['totalPurchases'].toString(),
                                  Icons.shopping_cart,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Spent',
                                  '₹${stats['totalSpent'].toStringAsFixed(0)}',
                                  Icons.account_balance_wallet,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Profit',
                                  '₹${stats['totalProfit'].toStringAsFixed(0)}',
                                  Icons.monetization_on,
                                  stats['totalProfit'] >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),

                // Purchase History with Date Grouping
                if (_isLoadingHistory)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_filteredPurchaseHistory.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: [
                          Icon(
                            _searchController.text.isNotEmpty ||
                                    _filterSupplier != 'all'
                                ? Icons.search_off
                                : Icons.history_outlined,
                            color: Colors.grey[400],
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty ||
                                    _filterSupplier != 'all'
                                ? 'No purchases found'
                                : 'No purchase history yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (_searchController.text.isNotEmpty ||
                              _filterSupplier != 'all')
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Try adjusting your filters',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  ...groupedPurchases.entries.map((group) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Group Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue[400]!,
                                      Colors.blue[600]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  group.key,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${group.value.length}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Purchase Cards in Group
                        ...group.value.asMap().entries.map((entry) {
                          final index = _filteredPurchaseHistory.indexOf(
                            entry.value,
                          );
                          final purchase = entry.value;
                          final profitPerUnit =
                              (purchase['sellingPrice'] ?? 0) -
                              (purchase['buyingPrice'] ?? 0);
                          final totalProfit =
                              profitPerUnit * (purchase['quantity'] ?? 0);
                          final isExpanded =
                              _expandedPurchaseHistory[index] ?? false;

                          // Calculate profit margin percentage
                          final profitMargin =
                              (purchase['buyingPrice'] ?? 0) > 0
                              ? (profitPerUnit /
                                        (purchase['buyingPrice'] ?? 1)) *
                                    100
                              : 0.0;

                          // Get color based on profit margin
                          Color getMarginColor(double margin) {
                            if (margin < 0) return Colors.red;
                            if (margin < 10) return Colors.orange;
                            if (margin < 30) return Colors.amber;
                            return Colors.green;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Dismissible(
                              key: Key('purchase_$index'),
                              background: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Icon(
                                  Icons.info_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              secondaryBackground: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.endToStart) {
                                  // Delete action - you can implement delete functionality here
                                  return await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Purchase'),
                                      content: const Text(
                                        'Are you sure you want to delete this purchase record?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return false;
                              },
                              onDismissed: (direction) {
                                if (direction == DismissDirection.endToStart) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Purchase deleted'),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[850]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[200]!,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Card Header
                                    InkWell(
                                      onTap: () => setState(() {
                                        _expandedPurchaseHistory[index] =
                                            !isExpanded;
                                      }),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Row(
                                          children: [
                                            // Supplier Avatar
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.blue[400]!,
                                                    Colors.blue[600]!,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  (purchase['supplierName'] ??
                                                          'U')
                                                      .toString()[0]
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // Supplier Info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          purchase['supplierName'] ??
                                                              'Unknown',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 15,
                                                            color: context
                                                                .primaryTextColor,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: getMarginColor(
                                                            profitMargin,
                                                          ).withOpacity(0.15),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          '${profitMargin.toStringAsFixed(0)}%',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                getMarginColor(
                                                                  profitMargin,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.calendar_today,
                                                        size: 11,
                                                        color: Colors.grey[500],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        purchase['date'] ??
                                                            'N/A',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        size: 11,
                                                        color: Colors.grey[500],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${purchase['quantity']} ${purchase['unit'] ?? 'units'}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Amount and Expand Icon
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '₹${purchase['total'] ?? 0}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: totalProfit >= 0
                                                        ? Colors.green
                                                              .withOpacity(0.1)
                                                        : Colors.red
                                                              .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        totalProfit >= 0
                                                            ? Icons.trending_up
                                                            : Icons
                                                                  .trending_down,
                                                        size: 10,
                                                        color: totalProfit >= 0
                                                            ? Colors.green
                                                            : Colors.red,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '₹${totalProfit.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              totalProfit >= 0
                                                              ? Colors.green
                                                              : Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              isExpanded
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              color: Colors.blue[600],
                                              size: 24,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Expanded Details
                                    if (isExpanded) ...[
                                      Divider(
                                        color: isDark
                                            ? Colors.grey[700]
                                            : Colors.grey[200],
                                        height: 1,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          children: [
                                            // Pricing Grid
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.grey[800]
                                                          ?.withOpacity(0.5)
                                                    : Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      _buildDetailChip(
                                                        'Buy',
                                                        '₹${purchase['buyingPrice']}',
                                                        Icons
                                                            .shopping_bag_outlined,
                                                        Colors.orange,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      _buildDetailChip(
                                                        'Sell',
                                                        '₹${purchase['sellingPrice']}',
                                                        Icons.sell_outlined,
                                                        Colors.green,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      _buildDetailChip(
                                                        'Margin',
                                                        '₹$profitPerUnit',
                                                        Icons.attach_money,
                                                        profitPerUnit >= 0
                                                            ? Colors.green
                                                            : Colors.red,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),

                                                  // Profit Margin Bar
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            'Profit Margin',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                          Text(
                                                            '${profitMargin.toStringAsFixed(1)}%',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  getMarginColor(
                                                                    profitMargin,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        child: LinearProgressIndicator(
                                                          value:
                                                              (profitMargin
                                                                  .clamp(
                                                                    0,
                                                                    100,
                                                                  ) /
                                                              100),
                                                          backgroundColor:
                                                              Colors.grey[300],
                                                          valueColor:
                                                              AlwaysStoppedAnimation(
                                                                getMarginColor(
                                                                  profitMargin,
                                                                ),
                                                              ),
                                                          minHeight: 6,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Total Summary
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.blue.withOpacity(
                                                      0.05,
                                                    ),
                                                    Colors.blue.withOpacity(
                                                      0.1,
                                                    ),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Colors.blue
                                                      .withOpacity(0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  _buildTotalStat(
                                                    'Cost',
                                                    '₹${((purchase['buyingPrice'] ?? 0) * (purchase['quantity'] ?? 0))}',
                                                    Colors.orange[600]!,
                                                  ),
                                                  Container(
                                                    width: 1,
                                                    height: 30,
                                                    color: Colors.grey[300],
                                                  ),
                                                  _buildTotalStat(
                                                    'Revenue',
                                                    '₹${purchase['total'] ?? 0}',
                                                    Colors.blue[600]!,
                                                  ),
                                                  Container(
                                                    width: 1,
                                                    height: 30,
                                                    color: Colors.grey[300],
                                                  ),
                                                  _buildTotalStat(
                                                    'Profit',
                                                    '₹${totalProfit.toStringAsFixed(0)}',
                                                    totalProfit >= 0
                                                        ? Colors.green[600]!
                                                        : Colors.red[600]!,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Show Supplier Filter Bottom Sheet
  void _showSupplierFilterSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.blue[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Filter by Supplier',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1),

            // Options List
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        _filterSupplier == 'all'
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: _filterSupplier == 'all'
                            ? Colors.blue[600]
                            : Colors.grey,
                      ),
                      title: Text(
                        'All Suppliers',
                        style: TextStyle(
                          fontWeight: _filterSupplier == 'all'
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _filterSupplier = 'all';
                        });
                        _filterAndSortPurchaseHistory();
                        Navigator.pop(context);
                      },
                    ),
                    ..._getUniqueSuppliers().map(
                      (supplier) => ListTile(
                        leading: Icon(
                          _filterSupplier == supplier
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _filterSupplier == supplier
                              ? Colors.blue[600]
                              : Colors.grey,
                        ),
                        title: Text(
                          supplier,
                          style: TextStyle(
                            fontWeight: _filterSupplier == supplier
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _filterSupplier = supplier;
                          });
                          _filterAndSortPurchaseHistory();
                          Navigator.pop(context);
                        },
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
  }

  // Show Purchase Sort Bottom Sheet
  void _showPurchaseSortSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.sort, color: Colors.blue[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Sort Purchases',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1),

            // Sort Options
            ListTile(
              leading: Icon(
                _sortBy == 'date' ? Icons.check_circle : Icons.circle_outlined,
                color: _sortBy == 'date' ? Colors.blue[600] : Colors.grey,
              ),
              title: Text(
                'Date',
                style: TextStyle(
                  fontWeight: _sortBy == 'date'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortBy = 'date';
                });
                _filterAndSortPurchaseHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortBy == 'amount'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortBy == 'amount' ? Colors.blue[600] : Colors.grey,
              ),
              title: Text(
                'Amount',
                style: TextStyle(
                  fontWeight: _sortBy == 'amount'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortBy = 'amount';
                });
                _filterAndSortPurchaseHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortBy == 'supplier'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortBy == 'supplier' ? Colors.blue[600] : Colors.grey,
              ),
              title: Text(
                'Supplier',
                style: TextStyle(
                  fontWeight: _sortBy == 'supplier'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortBy = 'supplier';
                });
                _filterAndSortPurchaseHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortBy == 'profit'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortBy == 'profit' ? Colors.blue[600] : Colors.grey,
              ),
              title: Text(
                'Profit',
                style: TextStyle(
                  fontWeight: _sortBy == 'profit'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortBy = 'profit';
                });
                _filterAndSortPurchaseHistory();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show Customer Filter Bottom Sheet
  void _showCustomerFilterSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Filter by Customer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1),

            // Options List
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        _filterCustomer == 'all'
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: _filterCustomer == 'all'
                            ? Colors.green[600]
                            : Colors.grey,
                      ),
                      title: Text(
                        'All Customers',
                        style: TextStyle(
                          fontWeight: _filterCustomer == 'all'
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _filterCustomer = 'all';
                        });
                        _filterAndSortSoldHistory();
                        Navigator.pop(context);
                      },
                    ),
                    ..._getUniqueCustomers().map(
                      (customer) => ListTile(
                        leading: Icon(
                          _filterCustomer == customer
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _filterCustomer == customer
                              ? Colors.green[600]
                              : Colors.grey,
                        ),
                        title: Text(
                          customer,
                          style: TextStyle(
                            fontWeight: _filterCustomer == customer
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _filterCustomer = customer;
                          });
                          _filterAndSortSoldHistory();
                          Navigator.pop(context);
                        },
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
  }

  // Show Sales Sort Bottom Sheet
  void _showSalesSortSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.sort, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Sort Sales',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1),

            // Sort Options
            ListTile(
              leading: Icon(
                _sortSalesBy == 'date'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortSalesBy == 'date' ? Colors.green[600] : Colors.grey,
              ),
              title: Text(
                'Date',
                style: TextStyle(
                  fontWeight: _sortSalesBy == 'date'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortSalesBy = 'date';
                });
                _filterAndSortSoldHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortSalesBy == 'amount'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortSalesBy == 'amount'
                    ? Colors.green[600]
                    : Colors.grey,
              ),
              title: Text(
                'Amount',
                style: TextStyle(
                  fontWeight: _sortSalesBy == 'amount'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortSalesBy = 'amount';
                });
                _filterAndSortSoldHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortSalesBy == 'customer'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortSalesBy == 'customer'
                    ? Colors.green[600]
                    : Colors.grey,
              ),
              title: Text(
                'Customer',
                style: TextStyle(
                  fontWeight: _sortSalesBy == 'customer'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortSalesBy = 'customer';
                });
                _filterAndSortSoldHistory();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                _sortSalesBy == 'profit'
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: _sortSalesBy == 'profit'
                    ? Colors.green[600]
                    : Colors.grey,
              ),
              title: Text(
                'Profit',
                style: TextStyle(
                  fontWeight: _sortSalesBy == 'profit'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              onTap: () {
                setState(() {
                  _sortSalesBy = 'profit';
                });
                _filterAndSortSoldHistory();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Build stat card for summary
  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Build detail chip
  Widget _buildDetailChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Build total stat
  Widget _buildTotalStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // Build Sold History Tab
  Widget _buildSoldHistoryTab(BuildContext context, Color cardColor) {
    final stats = _calculateSalesSummaryStats();
    final groupedSales = _groupSalesByDate();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchSalesController,
                decoration: InputDecoration(
                  hintText: 'Search by customer or date...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: _searchSalesController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchSalesController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Filter and Sort Row
              SizedBox(
                height: 35,
                child: Row(
                  children: [
                    // Customer Filter
                    Expanded(
                      child: InkWell(
                        onTap: () => _showCustomerFilterSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _filterCustomer == 'all'
                                      ? 'All Customers'
                                      : _filterCustomer,
                                  style: TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.filter_list,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort Button
                    Expanded(
                      child: InkWell(
                        onTap: () => _showSalesSortSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _sortSalesBy == 'date'
                                      ? 'Date'
                                      : _sortSalesBy == 'amount'
                                      ? 'Amount'
                                      : _sortSalesBy == 'customer'
                                      ? 'Customer'
                                      : 'Profit',
                                  style: TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.sort,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort Direction Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _sortSalesAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: Colors.green[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _sortSalesAscending = !_sortSalesAscending;
                          });
                          _filterAndSortSoldHistory();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              right: 10,
              left: 10,
              top: 4,
              bottom: 8,
            ),
            child: Column(
              children: [
                // Summary Statistics Card
                if (_soldHistory.isNotEmpty)
                  Card(
                    color: cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[400]!,
                                      Colors.green[700]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.analytics_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Sales Summary',
                                style: context.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Stats Grid
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Total',
                                  stats['totalSales'].toString(),
                                  Icons.receipt_long,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Revenue',
                                  '\u20b9${stats['totalRevenue'].toStringAsFixed(0)}',
                                  Icons.account_balance_wallet,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Profit',
                                  '\u20b9${stats['totalProfit'].toStringAsFixed(0)}',
                                  Icons.monetization_on,
                                  stats['totalProfit'] >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),

                // Sales History with Date Grouping
                if (_isLoadingSoldHistory)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_filteredSoldHistory.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: [
                          Icon(
                            _searchSalesController.text.isNotEmpty ||
                                    _filterCustomer != 'all'
                                ? Icons.search_off
                                : Icons.receipt_long_outlined,
                            color: Colors.grey[400],
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchSalesController.text.isNotEmpty ||
                                    _filterCustomer != 'all'
                                ? 'No sales found'
                                : 'No sales yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (_searchSalesController.text.isNotEmpty ||
                              _filterCustomer != 'all')
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Try adjusting your filters',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  ...groupedSales.entries.map((group) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Group Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[400]!,
                                      Colors.green[600]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  group.key,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${group.value.length}',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Sales Cards in Group
                        ...group.value.map((sale) {
                          final index = _filteredSoldHistory.indexOf(sale);
                          final profitPerUnit =
                              (sale['sellingPrice'] ?? 0) -
                              (sale['buyingPrice'] ?? 0);
                          final totalProfit =
                              profitPerUnit * (sale['quantity'] ?? 0);
                          final isExpanded =
                              _expandedSoldHistory[index] ?? false;

                          final profitMargin = (sale['buyingPrice'] ?? 0) > 0
                              ? (profitPerUnit / (sale['buyingPrice'] ?? 1)) *
                                    100
                              : 0.0;

                          Color getMarginColor(double margin) {
                            if (margin < 0) return Colors.red;
                            if (margin < 10) return Colors.orange;
                            if (margin < 30) return Colors.amber;
                            return Colors.green;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[850] : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[200]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  InkWell(
                                    onTap: () => setState(() {
                                      _expandedSoldHistory[index] = !isExpanded;
                                    }),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.green[400]!,
                                                  Colors.green[600]!,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                (sale['customerName'] ?? 'U')
                                                    .toString()[0]
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        sale['customerName'] ??
                                                            'Unknown',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 15,
                                                          color: context
                                                              .primaryTextColor,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: getMarginColor(
                                                          profitMargin,
                                                        ).withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '${profitMargin.toStringAsFixed(0)}%',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: getMarginColor(
                                                            profitMargin,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.calendar_today,
                                                      size: 11,
                                                      color: Colors.grey[500],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      sale['date'] ?? 'N/A',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      size: 11,
                                                      color: Colors.grey[500],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${sale['quantity']} ${sale['unit'] ?? 'units'}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '\u20b9${sale['total'] ?? 0}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: totalProfit >= 0
                                                      ? Colors.green
                                                            .withOpacity(0.1)
                                                      : Colors.red.withOpacity(
                                                          0.1,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      totalProfit >= 0
                                                          ? Icons.trending_up
                                                          : Icons.trending_down,
                                                      size: 10,
                                                      color: totalProfit >= 0
                                                          ? Colors.green
                                                          : Colors.red,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      '\u20b9${totalProfit.toStringAsFixed(0)}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: totalProfit >= 0
                                                            ? Colors.green
                                                            : Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            color: Colors.green[600],
                                            size: 24,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isExpanded) ...[
                                    Divider(
                                      color: isDark
                                          ? Colors.grey[700]
                                          : Colors.grey[200],
                                      height: 1,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.grey[800]
                                                        ?.withOpacity(0.5)
                                                  : Colors.grey[50],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    _buildDetailChip(
                                                      'Buy',
                                                      '\u20b9${sale['buyingPrice']}',
                                                      Icons
                                                          .shopping_bag_outlined,
                                                      Colors.orange,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _buildDetailChip(
                                                      'Sell',
                                                      '\u20b9${sale['sellingPrice']}',
                                                      Icons.sell_outlined,
                                                      Colors.green,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _buildDetailChip(
                                                      'Margin',
                                                      '\u20b9$profitPerUnit',
                                                      Icons.attach_money,
                                                      profitPerUnit >= 0
                                                          ? Colors.green
                                                          : Colors.red,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Profit Margin',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                        ),
                                                        Text(
                                                          '${profitMargin.toStringAsFixed(1)}%',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                getMarginColor(
                                                                  profitMargin,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                      child: LinearProgressIndicator(
                                                        value:
                                                            (profitMargin.clamp(
                                                              0,
                                                              100,
                                                            ) /
                                                            100),
                                                        backgroundColor:
                                                            Colors.grey[300],
                                                        valueColor:
                                                            AlwaysStoppedAnimation(
                                                              getMarginColor(
                                                                profitMargin,
                                                              ),
                                                            ),
                                                        minHeight: 6,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.green.withOpacity(
                                                    0.05,
                                                  ),
                                                  Colors.green.withOpacity(0.1),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.green.withOpacity(
                                                  0.2,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                _buildTotalStat(
                                                  'Cost',
                                                  '\u20b9${((sale['buyingPrice'] ?? 0) * (sale['quantity'] ?? 0))}',
                                                  Colors.orange[600]!,
                                                ),
                                                Container(
                                                  width: 1,
                                                  height: 30,
                                                  color: Colors.grey[300],
                                                ),
                                                _buildTotalStat(
                                                  'Revenue',
                                                  '\u20b9${sale['total'] ?? 0}',
                                                  Colors.green[600]!,
                                                ),
                                                Container(
                                                  width: 1,
                                                  height: 30,
                                                  color: Colors.grey[300],
                                                ),
                                                _buildTotalStat(
                                                  'Profit',
                                                  '\u20b9${totalProfit.toStringAsFixed(0)}',
                                                  totalProfit >= 0
                                                      ? Colors.green[600]!
                                                      : Colors.red[600]!,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
