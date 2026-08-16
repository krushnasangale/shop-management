import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/pages/billing/bill_success_page.dart';
import 'package:flashbill/services/bills_data_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flashbill/services/subscription_guard.dart';

class ReviewBillingDetails extends StatefulWidget {
  final String billDate;
  final String customerName;
  final String customerMobile;
  final String? customerVehicle;
  final String customerId;
  final List<BillProductItem> products;
  final int totalAmount;
  final bool totalAmountPaid;
  final int? amountPaid;
  final int? amountRemaining;
  final String paymentMethod;
  final String nextPaymentDate;
  final bool isEditMode;
  final String? billId;
  final int deliveryCharges;
  final double previousDueAmount;
  final double previousPaidAmount;
  final String previousDueDescription;

  const ReviewBillingDetails({
    required this.billDate,
    required this.customerName,
    required this.customerMobile,
    this.customerVehicle,
    required this.customerId,
    required this.products,
    required this.totalAmount,
    required this.totalAmountPaid,
    this.amountPaid,
    this.amountRemaining,
    required this.paymentMethod,
    this.nextPaymentDate = '',
    this.isEditMode = false,
    this.billId,
    this.deliveryCharges = 0,
    this.previousDueAmount = 0.0,
    this.previousPaidAmount = 0.0,
    this.previousDueDescription = '',
    super.key,
  });

  @override
  State<ReviewBillingDetails> createState() => _ReviewBillingDetailsState();
}

class _ReviewBillingDetailsState extends State<ReviewBillingDetails> {
  int _currentBillNumber = 0;
  AppLocalizations? localizations;
  late BillsDataService _billsDataService;
  StreamSubscription? _billsDataServiceSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations ??= AppLocalizations.of(context)!;
    _initializeBillsDataService();
  }

  void _initializeBillsDataService() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _billsDataService = BillsDataService();
      _billsDataService.initialize(user.uid);
      _billsDataServiceSubscription = _billsDataService.billsStream.listen((_) {
        // Bills data updated, no specific action needed here
      });
    }
  }

  bool get _isPaid => (widget.amountRemaining ?? 0) == 0;

  String get _paymentStatusLabel =>
      _isPaid ? localizations!.paid : localizations!.unpaid;

  String get _paymentMethodLabel => widget.paymentMethod == 'cash'
      ? localizations!.cash
      : localizations!.online;

  IconData get _paymentMethodIcon =>
      widget.paymentMethod == 'cash' ? Icons.money : Icons.credit_card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = localizations!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.reviewBill)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    _SummaryTile(
                      icon: Icons.account_balance_wallet_outlined,
                      label: loc.total,
                      value: '₹${widget.totalAmount}',
                      valueColor: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    _SummaryTile(
                      icon: Icons.inventory_2_outlined,
                      label: loc.products,
                      value: '${widget.products.length}',
                    ),
                    const SizedBox(width: 8),
                    _SummaryTile(
                      icon: Icons.verified_outlined,
                      label: loc.paymentStatus,
                      value: _paymentStatusLabel,
                      valueColor: _isPaid ? scheme.primary : scheme.error,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionLabel(context, loc.customer),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Adaptive.fullWidthGroup(
              bordered: true,
              context: context,
              children: [
                _infoTile(
                  icon: Icons.calendar_today_outlined,
                  label: loc.billDate,
                  value: widget.billDate,
                ),
                _infoTile(
                  icon: Icons.person_outline,
                  label: loc.customerName,
                  value: widget.customerName,
                ),
                _infoTile(
                  icon: Icons.phone_outlined,
                  label: loc.customerMobileNumber,
                  value: widget.customerMobile,
                ),
                if (widget.customerVehicle != null &&
                    widget.customerVehicle!.isNotEmpty)
                  _infoTile(
                    icon: Icons.directions_car_outlined,
                    label: loc.vehicleNumber,
                    value: widget.customerVehicle!,
                  ),
                if ((widget.amountPaid ?? 0) > 0)
                  _infoTile(
                    icon: _paymentMethodIcon,
                    label: loc.paymentMethod,
                    value: _paymentMethodLabel,
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _sectionLabel(context, loc.products),
            ),
          ),
          SliverToBoxAdapter(
            child: Adaptive.fullWidthGroup(
              bordered: true,
              context: context,
              children: [
                for (final product in widget.products)
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                    minVerticalPadding: 4,
                    leading: _squareIcon(Icons.inventory_2_outlined, scheme),
                    title: Text(
                      product.productName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '${loc.supplier}: ${product.supplierName}\n'
                      '${loc.qty}: ${product.quantity.toStringAsFixed(0)} ${product.unit}'
                      '  ·  ₹${product.price} ${loc.each}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '₹${product.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.previousDueAmount > 0) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _sectionLabel(context, loc.previousDue),
              ),
            ),
            SliverToBoxAdapter(
              child: Adaptive.fullWidthGroup(
              bordered: true,
                context: context,
                children: [
                  _infoTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: loc.amount,
                    value: '₹${widget.previousDueAmount.toStringAsFixed(2)}',
                    valueColor: scheme.error,
                  ),
                  if (widget.previousPaidAmount > 0)
                    _infoTile(
                      icon: Icons.payments_outlined,
                      label: loc.previousPaidAmount,
                      value:
                          '₹${widget.previousPaidAmount.toStringAsFixed(2)}',
                      valueColor: scheme.primary,
                    ),
                  if (widget.previousDueDescription.isNotEmpty)
                    _infoTile(
                      icon: Icons.notes_outlined,
                      label: loc.description,
                      value: widget.previousDueDescription,
                    ),
                ],
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _sectionLabel(context, loc.summary),
            ),
          ),
          SliverToBoxAdapter(
            child: Adaptive.fullWidthGroup(
              bordered: true,
              context: context,
              children: [
                _infoTile(
                  icon: Icons.shopping_bag_outlined,
                  label: loc.totalAmount,
                  value: '₹${widget.totalAmount}',
                ),
                if (widget.deliveryCharges > 0)
                  _infoTile(
                    icon: Icons.local_shipping_outlined,
                    label: loc.deliveryCharges,
                    value: '₹${widget.deliveryCharges}',
                  ),
                _infoTile(
                  icon: Icons.payments_outlined,
                  label: loc.amountPaid,
                  value: '₹${widget.amountPaid ?? 0}',
                  valueColor: scheme.primary,
                ),
                _infoTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: loc.amountDue,
                  value: '₹${widget.amountRemaining ?? 0}',
                  valueColor: (widget.amountRemaining ?? 0) > 0
                      ? scheme.error
                      : null,
                ),
                _infoTile(
                  icon: Icons.verified_outlined,
                  label: loc.paymentStatus,
                  value: _paymentStatusLabel,
                  valueColor: _isPaid ? scheme.primary : scheme.error,
                ),
                if ((widget.amountRemaining ?? 0) > 0)
                  _infoTile(
                    icon: Icons.event_outlined,
                    label: loc.nextPaymentDate,
                    value: widget.nextPaymentDate.isNotEmpty
                        ? widget.nextPaymentDate
                        : loc.notSet,
                  ),
              ],
            ),
          ),
          Adaptive.sliverBottomAction(
            child: FilledButton(
              style: Adaptive.compactFilled,
              onPressed: () {
                if (!SubscriptionGuard.ensureCanWrite(context)) return;
                _showConfirmDialog(context);
              },
              child: Text(
                widget.isEditMode ? loc.updateBill : loc.confirmBill,
              ),
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
    Color? valueColor,
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
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: valueColor ?? scheme.onSurface,
        ),
      ),
      subtitle: Text(label),
    );
  }

  void _showConfirmDialog(BuildContext context) {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            widget.isEditMode
                ? localizations!.updateBill
                : localizations!.confirmBill,
          ),
          content: Text(
            widget.isEditMode
                ? localizations!.areYouSureUpdateBill
                : localizations!.areYouSureCreateBill,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations!.no),
            ),
            FilledButton(
              style: Adaptive.compactFilled,
              onPressed: () async {
                Navigator.pop(context);
                await _showLoadingAndCreateBill();
              },
              child: Text(localizations!.yes),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLoadingAndCreateBill() async {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Adaptive.progress(color: scheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        widget.isEditMode
                            ? localizations!.updatingBill
                            : localizations!.creatingBill,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Calculate total amount including delivery charges
    final productsTotal = widget.products.fold<double>(
      0.0,
      (total, product) => total + product.total,
    );
    final totalAmount = (productsTotal + widget.deliveryCharges).toInt();

    try {
      await _saveBillToDatabase();
      if (mounted) {
        Navigator.pop(context); // Close loader

        // If in edit mode, pop back to bills list with success result
        if (widget.isEditMode) {
          // Pop all the way back to the bills list (pop review page, edit page, and detail page)
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations!.billUpdatedSuccessfully)),
          );
        } else {
          // For new bills, navigate to success page
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BillSuccessPage(
                customerName: widget.customerName,
                customerMobile: widget.customerMobile,
                customerVehicle: widget.customerVehicle ?? '',
                totalAmount: totalAmount,
                amountPaid: widget.totalAmountPaid
                    ? totalAmount
                    : (widget.amountPaid ?? 0),
                amountRemaining: widget.totalAmountPaid
                    ? 0
                    : (widget.amountRemaining ?? 0),
                products: widget.products,
                paymentMethod: widget.paymentMethod,
                nextPaymentDate: widget.nextPaymentDate,
                billNumber: _currentBillNumber,
                deliveryCharges: widget.deliveryCharges,
                previousDueAmount: widget.previousDueAmount,
                previousPaidAmount: widget.previousPaidAmount,
                previousDueDescription: widget.previousDueDescription,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditMode
                  ? '${localizations!.errorUpdatingBill}: $e'
                  : '${localizations!.errorCreatingBill}: $e',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveBillToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final firestore = FirebaseFirestore.instance;
    final userId = user.uid;

    // If in edit mode, delete the old bill first
    if (widget.isEditMode && widget.billId != null) {
      await _deleteOldBill(firestore, userId, widget.billId!);
    }

    // Generate bill number if not in edit mode
    int billNumber = 1;
    if (!widget.isEditMode) {
      // Use cached bills to generate the next bill number
      final cachedBills = _billsDataService.getCachedBills();
      billNumber = cachedBills.length + 1;
    } else if (widget.billId != null) {
      // If editing, retrieve the existing bill number from cached bills
      final cachedBills = _billsDataService.getCachedBills();
      final existingBill = cachedBills.firstWhere(
        (bill) => bill['id'] == widget.billId,
        orElse: () => {},
      );
      billNumber = existingBill['billNumber'] ?? 1;
    }

    // Store billNumber in instance variable to pass to success page
    _currentBillNumber = billNumber;

    // Generate document ID using Firestore auto-generated ID format
    final billDocRef = firestore
        .collection('bills')
        .doc(userId)
        .collection('items');

    // Prepare bill data
    final productsTotal = widget.products.fold<double>(
      0.0,
      (double sum, product) => sum + product.total,
    );
    final totalAmount = (productsTotal + widget.deliveryCharges).toInt();

    final actualAmountPaid = widget.totalAmountPaid
        ? totalAmount
        : (widget.amountPaid ?? 0);
    final actualAmountRemaining = widget.totalAmountPaid
        ? 0
        : (widget.amountRemaining ?? 0);

    final billData = {
      'billNumber': billNumber, // Add bill number
      'customerId': widget
          .customerId, // Add customerId for efficient customer history fetching
      'billDate': widget.billDate,
      'customerName': widget.customerName,
      'customerMobile': widget.customerMobile,
      'customerVehicle': widget.customerVehicle ?? '',
      'totalAmount': totalAmount,
      'totalAmountPaid': widget.totalAmountPaid,
      'amountPaid': actualAmountPaid,
      'amountRemaining': actualAmountRemaining,
      'paymentMethod': widget.paymentMethod,
      'nextPaymentDate': widget.nextPaymentDate,
      'deliveryCharges': widget.deliveryCharges,
      'previousDueAmount': widget.previousDueAmount,
      'previousPaidAmount': widget.previousPaidAmount,
      'previousDueDescription': widget.previousDueDescription,
      'timestamp': DateTime.now().toIso8601String(),
      'products': {
        for (int i = 0; i < widget.products.length; i++)
          'product_$i': {
            'productName': widget.products[i].productName,
            'supplierName': widget.products[i].supplierName,
            'unit': widget.products[i].unit,
            'quantity': widget.products[i].quantity,
            'price': widget.products[i].price,
            'boughtPrice': widget.products[i].boughtPrice,
            'total': widget.products[i].total,
            'batchId': widget.products[i].batchId,
            'profitMargin': widget.products[i].profitMargin,
            'profitTotal': widget.products[i].profitTotal,
            'order': widget.products[i].order,
          },
      },
      'payments': [
        {
          'amount': actualAmountPaid,
          'date': widget.billDate,
          'method': widget.paymentMethod,
        },
      ],
    };

    // Save bill to bills table (use existing billId if editing, otherwise auto-generate)
    if (widget.isEditMode && widget.billId != null) {
      await billDocRef.doc(widget.billId).set(billData);
    } else {
      await billDocRef.add(billData);
    }

    // Update product quantities in purchased-products
    for (final product in widget.products) {
      final productsSnapshot = await firestore
          .collection('purchased-products')
          .doc(userId)
          .collection('items')
          .get();

      final matchingDocs = productsSnapshot.docs.where((productDoc) {
        final productData = productDoc.data();
        final docBatchId = (productData['batchId'] as String?) ?? productDoc.id;
        return docBatchId == product.batchId;
      }).toList();

      // If duplicate rows exist for the same batchId, consume stock from rows
      // that actually have quantity first.
      matchingDocs.sort((a, b) {
        final qtyA = (a.data()['quantity'] as num?)?.toInt() ?? 0;
        final qtyB = (b.data()['quantity'] as num?)?.toInt() ?? 0;
        return qtyB.compareTo(qtyA);
      });

      int remainingToReduce = product.quantity.toInt();
      for (final productDoc in matchingDocs) {
        if (remainingToReduce <= 0) break;

        final productData = productDoc.data();
        final currentQty = (productData['quantity'] as num?)?.toInt() ?? 0;
        if (currentQty <= 0) continue;

        final reduction = remainingToReduce > currentQty
            ? currentQty
            : remainingToReduce;
        final newQty = currentQty - reduction;

        await firestore
            .collection('purchased-products')
            .doc(userId)
            .collection('items')
            .doc(productDoc.id)
            .update({'quantity': newQty});

        remainingToReduce -= reduction;
      }
    }
  }

  Future<void> _deleteOldBill(
    FirebaseFirestore firestore,
    String userId,
    String billId,
  ) async {
    // Get the old bill data from cached bills to restore product quantities
    final cachedBills = _billsDataService.getCachedBills();
    final billData = cachedBills.firstWhere(
      (bill) => bill['id'] == billId,
      orElse: () => <String, dynamic>{},
    );

    if (billData.isNotEmpty) {
      final products = billData['products'] as Map<String, dynamic>?;

      if (products != null) {
        // Restore product quantities from the old bill
        for (final productEntry in products.entries) {
          final product = productEntry.value as Map<String, dynamic>;
          final productName = product['productName'] as String?;
          final supplierName = product['supplierName'] as String?;
          final quantity = (product['quantity'] as num?)?.toInt() ?? 0;
          final batchId = product['batchId'] as String?;

          if (productName != null && supplierName != null && batchId != null) {
            // Find matching rows by batchId (or doc ID fallback) and restore
            // into the first matching row.
            final productsSnapshot = await firestore
                .collection('purchased-products')
                .doc(userId)
                .collection('items')
                .get();

            for (final productDoc in productsSnapshot.docs) {
              final productData = productDoc.data();
              final docBatchId =
                  (productData['batchId'] as String?) ?? productDoc.id;

              if (docBatchId == batchId) {
                final currentQty =
                    (productData['quantity'] as num?)?.toInt() ?? 0;
                final restoredQty = currentQty + quantity;

                await firestore
                    .collection('purchased-products')
                    .doc(userId)
                    .collection('items')
                    .doc(productDoc.id)
                    .update({'quantity': restoredQty});
                break;
              }
            }
          }
        }
      }

      // Delete the old bill
      await firestore
          .collection('bills')
          .doc(userId)
          .collection('items')
          .doc(billId)
          .delete();
    }
  }

  @override
  void dispose() {
    _billsDataServiceSubscription?.cancel();
    super.dispose();
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
