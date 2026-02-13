import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flashbill/pages/purchase/add_purchase_entry.dart';
import 'package:flashbill/l10n/app_localizations.dart';

class PurchaseEntryDetails extends StatefulWidget {
  final Map<String, dynamic> entry;

  const PurchaseEntryDetails({super.key, required this.entry});

  @override
  State<PurchaseEntryDetails> createState() => _PurchaseEntryDetailsState();
}

class _PurchaseEntryDetailsState extends State<PurchaseEntryDetails> {
  late List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  late List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subscriptions;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _purchaseSubscription;
  Map<String, dynamic> _purchaseData = {};

  @override
  void initState() {
    super.initState();
    _subscriptions = [];
    _purchaseData = Map.from(widget.entry);
    _loadItems();
    _loadPurchaseData();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  void _loadPurchaseData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final purchaseId = widget.entry['id'] as String?;
      if (purchaseId == null || purchaseId.isEmpty) return;

      // Listen to purchase document for real-time updates
      _purchaseSubscription = FirebaseFirestore.instance
          .collection('purchases')
          .doc(user.uid)
          .collection('items')
          .doc(purchaseId)
          .snapshots()
          .listen((snapshot) {
            if (mounted && snapshot.exists) {
              setState(() {
                _purchaseData = {'id': snapshot.id, ...snapshot.data()!};
                print(
                  'Purchase data updated: totalUnits=${_purchaseData['totalUnits']}, totalAmount=${_purchaseData['totalAmount']}',
                );
              });
            }
          });
    } catch (e) {
      print('Error loading purchase data: $e');
    }
  }

  void _loadItems() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final purchaseId = widget.entry['id'] as String?;
      if (purchaseId == null || purchaseId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Load all items for this purchase in real-time using Firestore query
      final subscription = FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(user.uid)
          .collection('items')
          .where('purchaseId', isEqualTo: purchaseId)
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              final loadedItems = snapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();

              setState(() {
                _items = loadedItems;
                _isLoading = false;
              });
            }
          });

      _subscriptions.add(subscription);
    } catch (e) {
      print('Error loading items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeProduct(String itemId) async {
    final localizations = AppLocalizations.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final purchaseId = widget.entry['id'] as String?;
      if (purchaseId == null || purchaseId.isEmpty) return;

      // Delete the product from purchased-products collection
      await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(user.uid)
          .collection('items')
          .doc(itemId)
          .delete();

      // Delete the corresponding entry from product-purchase-history
      final historySnapshot = await FirebaseFirestore.instance
          .collection('product-purchase-history')
          .doc(user.uid)
          .collection('items')
          .where('productId', isEqualTo: itemId)
          .get();

      for (var doc in historySnapshot.docs) {
        await doc.reference.delete();
      }

      // Check how many products remain in Firestore for this purchase
      final remainingItems = await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(user.uid)
          .collection('items')
          .where('purchaseId', isEqualTo: purchaseId)
          .get();

      // If no products remain, delete the purchase entry
      if (remainingItems.docs.isEmpty) {
        await FirebaseFirestore.instance
            .collection('purchases')
            .doc(user.uid)
            .collection('items')
            .doc(purchaseId)
            .delete();

        if (mounted) {
          // Navigate back after deletion
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.purchaseEntryRemovedLastProductDeleted ??
                    'Purchase entry removed (last product deleted)',
              ),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        // Calculate new total amount, total units, and total products from remaining items
        double newTotalAmount = 0;
        int newTotalUnits = 0;
        int newTotalProducts = remainingItems.docs.length;

        for (var doc in remainingItems.docs) {
          final total = (doc['total'] ?? 0) as num;
          final quantity = (doc['initialQuantity'] ?? 0) as num;
          newTotalAmount += total.toDouble();
          newTotalUnits += quantity.toInt();
        }

        // Update the purchase entry with new total amount, units, and product count
        await FirebaseFirestore.instance
            .collection('purchases')
            .doc(user.uid)
            .collection('items')
            .doc(purchaseId)
            .update({
              'totalAmount': newTotalAmount,
              'totalUnits': newTotalUnits,
              'totalProducts': newTotalProducts,
              'itemsCount': remainingItems.docs.length,
            });

        // Update the widget entry data to reflect changes
        widget.entry['totalAmount'] = newTotalAmount;
        widget.entry['totalUnits'] = newTotalUnits;
        widget.entry['totalProducts'] = newTotalProducts;

        // If there are more products, show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.productRemovedSuccessfully ??
                    'Product removed successfully',
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error removing product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations?.errorRemovingProduct ?? 'Error removing product'}: $e',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showRemoveConfirmation(String itemId, String productName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(
            localizations?.removeProduct ?? 'Remove Product',
            style: context.bodyLargeText,
          ),
          content: Text(
            _items.length <= 1
                ? (localizations?.removeLastProductWarning ??
                      'This is the last product. Removing it will delete the entire purchase entry. Continue?')
                : (localizations?.removeProductConfirmation ??
                          'Remove "$productName" from this purchase?')
                      .replaceAll('\$productName', productName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations?.cancel ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeProduct(itemId);
              },
              child: Text(
                localizations?.delete ?? 'Remove',
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    // Use totalAmount and totalUnits from real-time purchase data
    final totalAmount = (_purchaseData['totalAmount'] ?? 0) as num;
    final totalUnits = (_purchaseData['totalUnits'] ?? 0) as num;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations?.purchaseDetails ?? 'Purchase Details'),
          centerTitle: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.purchaseDetails ?? 'Purchase Details'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: localizations?.editPurchase ?? 'Edit Purchase',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddPurchaseEntry(
                    purchaseId: _purchaseData['id'] as String?,
                    existingEntry: _purchaseData,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: context.secondaryTextColor!.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _purchaseData['supplierName'] ??
                          (localizations?.unknownSupplier ??
                              'Unknown Supplier'),
                      style: context.headingMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations?.purchaseDate ?? 'Purchase Date',
                              style: context.subtitleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _purchaseData['date'] ??
                                  (localizations?.na ?? 'N/A'),
                              style: context.titleMedium,
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              localizations?.totalUnits ?? 'Total Units',
                              style: context.subtitleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text('$totalUnits', style: context.titleMedium),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations?.purchasedItems ?? 'Purchased Items',
              style: context.titleLarge,
            ),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((mapEntry) {
              final index = mapEntry.key;
              final item = mapEntry.value;
              final productName =
                  item['productName'] ?? (localizations?.unknown ?? 'Unknown');
              final quantity =
                  item['initialQuantity'] ?? 0; // Use current quantity
              final buyingPrice =
                  item['buyingPrice'] ?? 0; // Buying price never changes
              final sellingPrice =
                  item['sellingPrice'] ??
                  0; // Selling price at time of purchase
              final unit = item['unit'] ?? '';
              final expiryDate = item['expiryDate'] as String?;
              final total =
                  quantity * buyingPrice; // Calculate from current quantity
              final batchId = item['batchId'] as String?;
              final profitMargin = (sellingPrice - buyingPrice)
                  .toDouble(); // Calculate from prices

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: context.secondaryTextColor!.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                productName,
                                style: context.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Remove button
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red[600],
                              onPressed: (item['id'] as String?) != null
                                  ? () => _showRemoveConfirmation(
                                      item['id'] as String,
                                      productName,
                                    )
                                  : null,
                              tooltip:
                                  localizations?.removeProduct ??
                                  'Remove product',
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (batchId != null && batchId.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.purple.withOpacity(0.3),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  '${localizations?.batch ?? 'Batch'}: ${batchId.substring(0, 8)}...',
                                  style: TextStyle(
                                    color: Colors.purple[600],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Icon(
                                  Icons.straighten,
                                  size: 16,
                                  color: context.secondaryTextColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${localizations?.unit ?? 'Unit'}: $unit',
                                  style: context.subtitleSmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (expiryDate != null && expiryDate.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${localizations?.expiryDate ?? 'Expiry Date'}: $expiryDate',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations?.quantity ?? 'Quantity',
                                  style: context.subtitleSmall?.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('$quantity', style: context.titleMedium),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations?.buyingPrice ?? 'Buying Price',
                                  style: context.subtitleSmall?.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹$buyingPrice',
                                  style: TextStyle(
                                    color: Colors.red[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations?.sellingPrice ??
                                      'Selling Price',
                                  style: context.subtitleSmall?.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹$sellingPrice',
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Profit Margin Row (always show with calculated value)
                        Column(
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  localizations?.profitPerUnit ??
                                      'Profit per Unit',
                                  style: context.subtitleSmall?.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '₹${profitMargin.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: profitMargin >= 0
                                        ? Colors.green[600]
                                        : Colors.red[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(
                          color: context.secondaryTextColor?.withOpacity(0.1),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              localizations?.itemTotal ?? 'Item Total',
                              style: context.subtitleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₹$total',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.1),
                    Colors.green.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations?.grandTotal ?? 'Grand Total',
                    style: context.titleLarge,
                  ),
                  Text(
                    '₹$totalAmount',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
