import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flashbill/pages/products/available_products.dart';

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
    extends State<AvailableProductDetailScreen> {
  // Local state for editable fields
  late TextEditingController _quantityController;
  late TextEditingController _minLimitController;
  List<BoughtProduct> _allBatches = [];
  bool _isLoadingBatches = true;
  bool _editingMinLimit = false;
  Map<String, bool> _editingBatchPrices =
      {}; // Track which batches are being edited
  Map<String, TextEditingController> _batchPriceControllers =
      {}; // Per-batch price controllers
  Map<String, bool> _editingBatchQuantities =
      {}; // Track which batches quantities are being edited
  Map<String, TextEditingController> _batchQuantityControllers =
      {}; // Per-batch quantity controllers
  List<Map<String, dynamic>> _purchaseHistory = []; // Complete purchase history
  bool _isLoadingHistory = true;
  Map<int, bool> _expandedPurchaseHistory =
      {}; // Track which purchase history items are expanded
  Map<int, bool> _expandedBatches = {}; // Track which batch items are expanded

  @override
  void initState() {
    super.initState();

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
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _minLimitController.dispose();
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
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Quantity', style: TextStyle(color: primaryTextColor)),
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
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Selling Price',
          style: TextStyle(color: primaryTextColor),
        ),
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
    return _allBatches.fold<double>(0, (sum, b) => sum + b.quantity);
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
    if (_isLoadingBatches || totalStockQty == 0)
      return widget.product.buyingPrice;
    double totalCost = 0;
    for (var batch in _allBatches) {
      totalCost += batch.buyingPrice * batch.quantity;
    }
    return totalCost / totalStockQty;
  }

  double get averageSellingPrice {
    if (_isLoadingBatches || totalStockQty == 0)
      return widget.product.sellingPrice;
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
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: secondaryTextColor, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: secondaryTextColor, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: valueColor ?? primaryTextColor,
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
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    // Capitalize product name for display
    final displayedProductName =
        widget.product.productName[0].toUpperCase() +
        widget.product.productName.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(displayedProductName),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // Confirm deletion
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Delete Product',
                    style: TextStyle(color: primaryTextColor),
                  ),
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // --- 1. Financial Metrics Card (Current Stock) ---
                  Card(
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Financial Metrics (Current Stock)',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
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
                            valueColor: profitMargin >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

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
                                      style: TextStyle(
                                        color: primaryTextColor,
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
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _allBatches
                                        .fold(
                                          0,
                                          (sum, batch) => sum + batch.quantity,
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
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
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
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
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6,
                                                    ),
                                              ),
                                              style: TextStyle(
                                                color: primaryTextColor,
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
                                              color: Colors.green.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
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
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
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
                                              int.tryParse(
                                                _minLimitController.text,
                                              ) ??
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
                                            batchWithMinLimit ??=
                                                _allBatches.isNotEmpty
                                                ? _allBatches.first
                                                : null;

                                            if (batchWithMinLimit != null) {
                                              FirebaseFirestore.instance
                                                  .collection(
                                                    'purchased-products',
                                                  )
                                                  .doc(widget.userId)
                                                  .collection('items')
                                                  .doc(batchWithMinLimit.id)
                                                  .update({
                                                    'minLimit': newMinLimit,
                                                  })
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
                                                        content: Text(
                                                          'Error: $e',
                                                        ),
                                                      ),
                                                    );
                                                  });
                                            }
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Enter a valid number',
                                                ),
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
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          _editingMinLimit
                                              ? Icons.check
                                              : Icons.edit,
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
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
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
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final batch = _allBatches[index];
                                final isFirstBatch = index == 0;
                                final isLastBatch =
                                    index == _allBatches.length - 1;
                                final isExpanded =
                                    _expandedBatches[index] ?? false;
                                final isDark =
                                    Theme.of(context).brightness ==
                                    Brightness.dark;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[50],
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
                                        borderRadius:
                                            const BorderRadius.vertical(
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
                                                                      .withOpacity(
                                                                        0.15,
                                                                      )
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
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  isFirstBatch
                                                                  ? Colors
                                                                        .orange[700]
                                                                  : Colors
                                                                        .blue[700],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),

                                                    // Supplier name
                                                    Text(
                                                      batch.supplierName,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: primaryTextColor,
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4.0,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    // Quantity
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .inventory_2_outlined,
                                                            color: Colors.grey,
                                                            size: 20,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Quantity',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .grey,
                                                                    fontSize:
                                                                        13,
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
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors
                                                                          .blue
                                                                          .withOpacity(
                                                                            0.1,
                                                                          ),
                                                                      border: Border.all(
                                                                        color: Colors
                                                                            .blue,
                                                                        width:
                                                                            1.5,
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
                                                                            color:
                                                                                Colors.blue[400],
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            fontSize:
                                                                                16,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        Icon(
                                                                          Icons
                                                                              .edit,
                                                                          color:
                                                                              Colors.blue,
                                                                          size:
                                                                              20,
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
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Profit/Unit',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .grey,
                                                                    fontSize:
                                                                        13,
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
                                                                        FontWeight
                                                                            .w600,
                                                                    fontSize:
                                                                        14,
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
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Buying Price',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .grey,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Text(
                                                                  '₹${batch.buyingPrice.toStringAsFixed(2)}/${batch.unit}',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .red[400],
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontSize:
                                                                        14,
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
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Selling Price',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .grey,
                                                                    fontSize:
                                                                        13,
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
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors
                                                                          .blue
                                                                          .withOpacity(
                                                                            0.1,
                                                                          ),
                                                                      border: Border.all(
                                                                        color: Colors
                                                                            .blue,
                                                                        width:
                                                                            1.5,
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
                                                                              color: Colors.green[400],
                                                                              fontWeight: FontWeight.w600,
                                                                              fontSize: 14,
                                                                            ),
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        Icon(
                                                                          Icons
                                                                              .edit,
                                                                          color:
                                                                              Colors.blue,
                                                                          size:
                                                                              18,
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
                                                  batch
                                                      .expiryDate!
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                _buildDetailRow(
                                                  context,
                                                  'Expiry Date',
                                                  batch.expiryDate!,
                                                  icon: Icons.calendar_today,
                                                  valueColor:
                                                      Colors.orange[700],
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

                  // --- 3. Complete Purchase History Card ---
                  Card(
                    color: cardColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                          // Header with title and history count
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.history,
                                      color: Colors.blue[600],
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Purchase History',
                                        style: TextStyle(
                                          color: primaryTextColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '${_purchaseHistory.length} purchases total',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _purchaseHistory.length.toString(),
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Content
                          if (_isLoadingHistory)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 32.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else if (_purchaseHistory.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32.0,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.history_outlined,
                                      color: Colors.grey[400],
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No purchase history yet',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _purchaseHistory.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final purchase = _purchaseHistory[index];
                                final profitPerUnit =
                                    (purchase['sellingPrice'] ?? 0) -
                                    (purchase['buyingPrice'] ?? 0);
                                final totalProfit =
                                    profitPerUnit * (purchase['quantity'] ?? 0);
                                final isDark =
                                    Theme.of(context).brightness ==
                                    Brightness.dark;
                                final isExpanded =
                                    _expandedPurchaseHistory[index] ?? false;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[50],
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
                                      // Tile (Always visible)
                                      InkWell(
                                        onTap: () => setState(() {
                                          _expandedPurchaseHistory[index] =
                                              !isExpanded;
                                        }),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue
                                                            .withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '#${_purchaseHistory.length - index}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.blue[700],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            purchase['supplierName'] ??
                                                                'Unknown Supplier',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  primaryTextColor,
                                                              fontSize: 13,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            purchase['unit'] ??
                                                                'units',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .grey[500],
                                                            ),
                                                          ),
                                                        ],
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
                                                    purchase['date'] ?? 'N/A',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${purchase['quantity']} units',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[500],
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
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Pricing details grid
                                              Column(
                                                children: [
                                                  // Row 1: Buying and Selling Price
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      _buildPriceInfo(
                                                        context,
                                                        'Buy Price',
                                                        '₹${purchase['buyingPrice']}',
                                                        Colors.orange[600]!,
                                                      ),
                                                      Container(
                                                        width: 1,
                                                        height: 30,
                                                        color: Colors.grey[300],
                                                      ),
                                                      _buildPriceInfo(
                                                        context,
                                                        'Sell Price',
                                                        '₹${purchase['sellingPrice']}',
                                                        Colors.green[600]!,
                                                      ),
                                                      Container(
                                                        width: 1,
                                                        height: 30,
                                                        color: Colors.grey[300],
                                                      ),
                                                      _buildPriceInfo(
                                                        context,
                                                        'Margin',
                                                        '₹${profitPerUnit.toStringAsFixed(0)}',
                                                        profitPerUnit >= 0
                                                            ? Colors.green[600]!
                                                            : Colors.red[600]!,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 16),

                                                  // Row 2: Totals
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      _buildTotalInfo(
                                                        context,
                                                        'Total Cost',
                                                        '₹${(purchase['buyingPrice'] ?? 0) * (purchase['quantity'] ?? 0)}',
                                                        Colors.orange,
                                                      ),
                                                      Container(
                                                        width: 1,
                                                        height: 30,
                                                        color: Colors.grey[300],
                                                      ),
                                                      _buildTotalInfo(
                                                        context,
                                                        'Total Revenue',
                                                        '₹${purchase['total'] ?? 0}',
                                                        Colors.green,
                                                      ),
                                                      Container(
                                                        width: 1,
                                                        height: 30,
                                                        color: Colors.grey[300],
                                                      ),
                                                      _buildTotalInfo(
                                                        context,
                                                        'Total Profit',
                                                        '₹${totalProfit.toStringAsFixed(0)}',
                                                        totalProfit >= 0
                                                            ? Colors.green
                                                            : Colors.red,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build price info
  Widget _buildPriceInfo(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build total info
  Widget _buildTotalInfo(
    BuildContext context,
    String label,
    String value,
    MaterialColor color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color[700],
            ),
          ),
        ],
      ),
    );
  }
}
