import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/purchase/add_purchase_entry.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:material_ui/material_ui.dart';

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
    for (final sub in _subscriptions) {
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
              });
            }
          });
    } catch (e) {
      appLog('Error loading purchase data: $e');
    }
  }

  void _loadItems() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final purchaseId = widget.entry['id'] as String?;

      if (purchaseId == null || purchaseId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

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

              var needsMigration = false;
              for (final item in loadedItems) {
                if (item['order'] == null) {
                  needsMigration = true;
                  break;
                }
              }

              loadedItems.sort((a, b) {
                final orderA = (a['order'] as num?)?.toInt();
                final orderB = (b['order'] as num?)?.toInt();

                if (orderA != null && orderB != null) {
                  return orderA.compareTo(orderB);
                }

                final timestampA = a['timestamp'] as String? ?? '';
                final timestampB = b['timestamp'] as String? ?? '';
                return timestampA.compareTo(timestampB);
              });

              setState(() {
                _items = loadedItems;
                _isLoading = false;
              });

              if (needsMigration) {
                _migrateItemsOrder(user.uid, loadedItems);
              }
            }
          });

      _subscriptions.add(subscription);
    } catch (e) {
      appLog('Error loading items: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _migrateItemsOrder(
    String userId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item['order'] == null) {
          final docId = item['id'] as String;
          final docRef = FirebaseFirestore.instance
              .collection('purchased-products')
              .doc(userId)
              .collection('items')
              .doc(docId);

          batch.update(docRef, {'order': i});
        }
      }

      await batch.commit();
    } catch (e) {
      appLog('Error during migration: $e');
    }
  }

  Future<void> _removeProduct(String itemId) async {
    final loc = AppLocalizations.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final purchaseId = widget.entry['id'] as String?;
      if (purchaseId == null || purchaseId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(user.uid)
          .collection('items')
          .doc(itemId)
          .delete();

      final historySnapshot = await FirebaseFirestore.instance
          .collection('product-purchase-history')
          .doc(user.uid)
          .collection('items')
          .where('productId', isEqualTo: itemId)
          .get();

      for (final doc in historySnapshot.docs) {
        await doc.reference.delete();
      }

      final remainingItems = await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(user.uid)
          .collection('items')
          .where('purchaseId', isEqualTo: purchaseId)
          .get();

      if (remainingItems.docs.isEmpty) {
        await FirebaseFirestore.instance
            .collection('purchases')
            .doc(user.uid)
            .collection('items')
            .doc(purchaseId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loc?.purchaseEntryRemovedLastProductDeleted ??
                    'Purchase entry removed (last product deleted)',
              ),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        var newTotalAmount = 0.0;
        var newTotalUnits = 0;
        final newTotalProducts = remainingItems.docs.length;

        for (final doc in remainingItems.docs) {
          final total = (doc['total'] ?? 0) as num;
          final quantity = (doc['initialQuantity'] ?? 0) as num;
          newTotalAmount += total.toDouble();
          newTotalUnits += quantity.toInt();
        }

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

        widget.entry['totalAmount'] = newTotalAmount;
        widget.entry['totalUnits'] = newTotalUnits;
        widget.entry['totalProducts'] = newTotalProducts;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loc?.productRemovedSuccessfully ??
                    'Product removed successfully',
              ),
            ),
          );
        }
      }
    } catch (e) {
      appLog('Error removing product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${loc?.errorRemovingProduct ?? 'Error removing product'}: $e',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showRemoveConfirmation(String itemId, String productName) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc?.removeProduct ?? 'Remove Product'),
        content: Text(
          _items.length <= 1
              ? (loc?.removeLastProductWarning ??
                    'This is the last product. Removing it will delete the entire purchase entry. Continue?')
              : (loc?.removeProductConfirmation ??
                        'Remove "$productName" from this purchase?')
                    .replaceAll('\$productName', productName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(loc?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeProduct(itemId);
            },
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: Text(loc?.delete ?? 'Remove'),
          ),
        ],
      ),
    );
  }

  void _editPurchase() {
    AppNavigator.push(
      context,
      AddPurchaseEntry(
        purchaseId: _purchaseData['id'] as String?,
        existingEntry: _purchaseData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final totalAmount = (_purchaseData['totalAmount'] ?? 0) as num;
    final totalUnits = (_purchaseData['totalUnits'] ?? 0) as num;
    final supplier =
        (_purchaseData['supplierName'] ?? loc?.unknownSupplier ?? 'Unknown')
            .toString();
    final date = (_purchaseData['date'] ?? loc?.na ?? 'N/A').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.purchaseDetails ?? 'Purchase Details'),
        actions: [
          AppContextMenu.iconButton(
            width: 168,
            items: () => [
              AppContextMenuItem(
                label: loc?.editPurchase ?? 'Edit',
                icon: CupertinoIcons.pencil,
                onPressed: _editPurchase,
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? Center(child: Adaptive.progress())
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _SummaryTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: loc?.total ?? 'Total',
                        value: '₹${_formatAmount(totalAmount)}',
                        valueColor: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        icon: Icons.shopping_bag_outlined,
                        label: loc?.totalUnits ?? 'Units',
                        value: '$totalUnits',
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        icon: Icons.inventory_2_outlined,
                        label: loc?.products ?? 'Products',
                        value: '${_items.length}',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _sectionLabel(context, loc?.details ?? 'Details'),
                ),
                Adaptive.fullWidthGroup(
                  context: context,
                  children: [
                    _infoTile(
                      icon: Icons.local_shipping_outlined,
                      label: loc?.supplier ?? 'Supplier',
                      value: supplier,
                    ),
                    _infoTile(
                      icon: Icons.calendar_today_outlined,
                      label: loc?.purchaseDate ?? 'Purchase Date',
                      value: date,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _sectionLabel(
                    context,
                    loc?.purchasedItems ?? 'Purchased Products',
                  ),
                ),
                if (_items.isEmpty)
                  Adaptive.fullWidthGroup(
                    context: context,
                    children: [
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        leading: _squareIcon(
                          Icons.inventory_2_outlined,
                          scheme,
                        ),
                        title: Text(
                          loc?.noPurchasedEntriesYet ?? 'No products',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (var i = 0; i < _items.length; i++) ...[
                          _PurchaseItemTile(
                            item: _items[i],
                            loc: loc,
                            onRemove: (_items[i]['id'] as String?) == null
                                ? null
                                : () => _showRemoveConfirmation(
                                    _items[i]['id'] as String,
                                    (_items[i]['productName'] ??
                                            loc?.unknown ??
                                            'Unknown')
                                        .toString(),
                                  ),
                          ),
                          if (i != _items.length - 1) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      minVerticalPadding: 4,
      leading: _squareIcon(icon, scheme),
      title: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: Text(label),
    );
  }
}

class _PurchaseItemTile extends StatelessWidget {
  const _PurchaseItemTile({
    required this.item,
    required this.loc,
    required this.onRemove,
  });

  final Map<String, dynamic> item;
  final AppLocalizations? loc;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final productName = (item['productName'] ?? loc?.unknown ?? 'Unknown')
        .toString();
    final quantity = (item['initialQuantity'] ?? 0) as num;
    final buyingPrice = (item['buyingPrice'] ?? 0) as num;
    final sellingPrice = (item['sellingPrice'] ?? 0) as num;
    final unit = (item['unit'] ?? '').toString();
    final expiryDate = item['expiryDate'] as String?;
    final batchId = item['batchId'] as String?;
    final total = quantity * buyingPrice;
    final profit = sellingPrice - buyingPrice;
    final meta = [
      if (expiryDate != null && expiryDate.isNotEmpty) expiryDate,
      if (batchId != null && batchId.isNotEmpty)
        '${loc?.batch ?? 'Batch'} ${batchId.length > 8 ? '${batchId.substring(0, 8)}…' : batchId}',
    ].join('  ·  ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _squareIcon(Icons.inventory_2_outlined, scheme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '₹${_formatAmount(total)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                if (onRemove != null)
                  AppContextMenu.iconButton(
                    dense: true,
                    width: 168,
                    items: () => [
                      AppContextMenuItem(
                        label: loc?.removeProduct ?? 'Remove',
                        icon: CupertinoIcons.delete,
                        destructive: true,
                        onPressed: onRemove!,
                      ),
                    ],
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Metric(
                  label: 'Qty',
                  value: unit.isEmpty ? '$quantity' : '$quantity $unit',
                ),
                _Metric(label: 'Buy', value: '₹${_formatAmount(buyingPrice)}'),
                _Metric(
                  label: 'Sell',
                  value: '₹${_formatAmount(sellingPrice)}',
                ),
                _Metric(
                  label: 'Profit',
                  value: '${profit >= 0 ? '+' : ''}₹${_formatAmount(profit)}',
                  valueColor: profit >= 0 ? scheme.primary : scheme.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: valueColor ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _squareIcon(icon, scheme),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _sectionLabel(BuildContext context, String title) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: scheme.onSurfaceVariant,
      ),
    ),
  );
}

Widget _squareIcon(IconData icon, ColorScheme scheme) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: ColoredBox(
      color: scheme.primaryContainer,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
      ),
    ),
  );
}

String _formatAmount(num amount) {
  if (amount == amount.roundToDouble()) return amount.toInt().toString();
  return amount.toStringAsFixed(2);
}
