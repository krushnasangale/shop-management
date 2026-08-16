import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';
import 'package:flashbill/services/bills_data_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

class PreviousDueDetailsPage extends StatefulWidget {
  final Map<String, dynamic> payment;

  const PreviousDueDetailsPage({super.key, required this.payment});

  @override
  State<PreviousDueDetailsPage> createState() => _PreviousDueDetailsPageState();
}

class _PreviousDueDetailsPageState extends State<PreviousDueDetailsPage> {
  List<Map<String, dynamic>> paymentRecords = [];
  bool isLoadingPayments = true;
  Map<String, dynamic>? currentBillData;
  late BillsDataService _billsDataService;
  StreamSubscription? _billsDataServiceSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBillsDataService();
  }

  void _initializeBillsDataService() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _billsDataService = BillsDataService();
      _billsDataService.initialize(user.uid);
      _billsDataServiceSubscription = _billsDataService.billsStream.listen((_) {
        _loadBillData();
      });
    } else {
      setState(() => isLoadingPayments = false);
    }
  }

  Future<void> _loadBillData() async {
    try {
      final cachedBills = _billsDataService.getCachedBills();
      final billData = cachedBills.firstWhere(
        (bill) => bill['id'] == widget.payment['billId'],
        orElse: () => <String, dynamic>{},
      );

      if (billData.isNotEmpty) {
        setState(() {
          currentBillData = billData;
        });
        await _loadPaymentRecords();
      } else {
        setState(() => isLoadingPayments = false);
      }
    } catch (e) {
      debugPrint('Error loading bill data: $e');
      setState(() => isLoadingPayments = false);
    }
  }

  Future<void> _loadPaymentRecords() async {
    try {
      if (currentBillData != null) {
        final payments =
            currentBillData!['previousDuePayments'] as List<dynamic>? ?? [];
        setState(() {
          paymentRecords = payments
              .map((p) => Map<String, dynamic>.from(p))
              .toList()
              .reversed
              .toList();
          isLoadingPayments = false;
        });
      } else {
        setState(() => isLoadingPayments = false);
      }
    } catch (e) {
      debugPrint('Error loading payment records: $e');
      setState(() => isLoadingPayments = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final symbol = loc?.currencySymbol ?? '₹';

    final previousDueAmount =
        (currentBillData?['previousDueAmount'] as num?)?.toDouble() ??
        widget.payment['previousDueAmount'] as double;
    final previousPaidAmount =
        (currentBillData?['previousPaidAmount'] as num?)?.toDouble() ??
        widget.payment['previousPaidAmount'] as double;
    final remaining = previousDueAmount - previousPaidAmount;
    final canAddPayment = previousPaidAmount < previousDueAmount;

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (previousPaidAmount >= previousDueAmount) {
      statusColor = scheme.primary;
      statusText = loc?.paid ?? 'Paid';
      statusIcon = Icons.check_circle_outline;
    } else if (previousPaidAmount > 0) {
      statusColor = scheme.onSurfaceVariant;
      statusText = loc?.partiallyPaid ?? 'Partially Paid';
      statusIcon = Icons.schedule_outlined;
    } else {
      statusColor = scheme.error;
      statusText = loc?.unpaid ?? 'Unpaid';
      statusIcon = Icons.cancel_outlined;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.previousDue ?? 'Previous Due'),
        actions: [
          if (canAddPayment)
            TextButton(
              onPressed: () => _showAddPaymentDialog(context),
              child: Text(loc?.addPayment ?? 'Add Payment'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      _SummaryTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: loc?.total ?? 'Total',
                        value: '$symbol${previousDueAmount.toStringAsFixed(0)}',
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        icon: Icons.check_circle_outline,
                        label: loc?.collected ?? 'Collected',
                        value:
                            '$symbol${previousPaidAmount.toStringAsFixed(0)}',
                        valueColor: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        icon: Icons.schedule_outlined,
                        label: loc?.pending ?? 'Pending',
                        value: '$symbol${remaining.toStringAsFixed(0)}',
                        valueColor: remaining > 0
                            ? scheme.error
                            : scheme.primary,
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Chip(
                      avatar: Icon(statusIcon, size: 16, color: statusColor),
                      label: Text(statusText),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      side: BorderSide(
                        color: statusColor.withValues(alpha: 0.35),
                      ),
                      backgroundColor: statusColor.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _sectionLabel(
                    loc?.customerInformation ?? 'Customer Information',
                  ),
                ),
                Adaptive.fullWidthGroup(
                  bordered: true,
                  context: context,
                  children: [
                    _infoTile(
                      icon: Icons.person_outline,
                      label: loc?.customerName ?? 'Customer Name',
                      value: widget.payment['customerName']?.toString() ?? '',
                    ),
                    _infoTile(
                      icon: Icons.calendar_today_outlined,
                      label: loc?.billDate ?? 'Bill Date',
                      value: widget.payment['billDate']?.toString() ?? '',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _sectionLabel(
                    loc?.paymentHistory ?? 'Payment History',
                  ),
                ),
                Adaptive.fullWidthGroup(
                  bordered: true,
                  context: context,
                  children: [
                    if (isLoadingPayments)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Adaptive.progress()),
                      )
                    else if (paymentRecords.isEmpty)
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        leading: _squareIcon(
                          Icons.receipt_long_outlined,
                          scheme,
                        ),
                        title: Text(
                          loc?.noPaymentsRecorded ?? 'No payments recorded',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    else
                      for (final record in paymentRecords)
                        _infoTile(
                          icon: Icons.payments_outlined,
                          label:
                              '${record['date'] ?? ''}  ·  ${_methodLabel(record['paymentMethod'], loc)}',
                          value: '$symbol${record['amount']}',
                        ),
                  ],
                ),
              ]),
            ),
          ),
          Adaptive.sliverBottomAction(
            child: FilledButton.icon(
              onPressed: () => _navigateToBillDetails(context),
              style: Adaptive.compactFilled,
              icon: const Icon(Icons.receipt_long, size: 20),
              label: Text(loc?.viewBillDetails ?? 'View Bill Details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  String _methodLabel(dynamic method, AppLocalizations? loc) {
    final value = (method ?? 'cash').toString().toLowerCase();
    if (value == 'online') return loc?.online ?? 'Online';
    return loc?.cash ?? 'Cash';
  }

  void _navigateToBillDetails(BuildContext context) {
    List<Map<String, dynamic>>? products;
    if (currentBillData?['products'] is Map) {
      final productsMap = currentBillData!['products'] as Map<String, dynamic>;
      products = productsMap.entries.map((entry) {
        final product = entry.value as Map<String, dynamic>;
        return Map<String, dynamic>.from(product);
      }).toList();
    } else if (widget.payment['products'] is Map) {
      final productsMap = widget.payment['products'] as Map<String, dynamic>;
      products = productsMap.entries.map((entry) {
        final product = entry.value as Map<String, dynamic>;
        return Map<String, dynamic>.from(product);
      }).toList();
    } else {
      products = <Map<String, dynamic>>[];
    }

    AppNavigator.push(
      context,
      ViewBillDetailsScreen(
        billId: widget.payment['billId'],
        billDate: widget.payment['billDate'],
        customerName: widget.payment['customerName'],
        customerMobile: '',
        customerVehicle: '',
        totalAmount: widget.payment['totalAmount'],
        totalAmountPaid: widget.payment['isFullyPaid'],
        amountPaid: widget.payment['amountPaid'],
        amountRemaining: widget.payment['amountRemaining'],
        products: products,
        nextPaymentDate: '',
        previousDueAmount: widget.payment['previousDueAmount'],
        previousPaidAmount: widget.payment['previousPaidAmount'],
        previousDueDescription: '',
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final TextEditingController amountController = TextEditingController();
    final previousDueAmount =
        (currentBillData?['previousDueAmount'] as num?)?.toDouble() ??
        widget.payment['previousDueAmount'] as double;
    final previousPaidAmount =
        (currentBillData?['previousPaidAmount'] as num?)?.toDouble() ??
        widget.payment['previousPaidAmount'] as double;
    final remainingAmount = previousDueAmount - previousPaidAmount;
    String selectedPaymentMethod = 'cash';
    final symbol = loc?.currencySymbol ?? '₹';

    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              title: Text(loc?.addPayment ?? 'Add Payment'),
              content: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _squareIcon(Icons.schedule_outlined, scheme),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc?.pending ?? 'Amount Pending',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$symbol${remainingAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: scheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration:
                            Adaptive.compactField(
                              label: loc?.paymentAmount ?? 'Payment Amount',
                              hint: '1000',
                              icon: Icons.currency_rupee,
                            ).copyWith(
                              helperText:
                                  '${loc?.max ?? 'Max'}: $symbol${remainingAmount.toStringAsFixed(2)}',
                            ),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            final enteredAmount = double.tryParse(value);
                            if (enteredAmount != null &&
                                enteredAmount > remainingAmount) {
                              amountController.text = remainingAmount
                                  .toStringAsFixed(2);
                              amountController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: amountController.text.length,
                                    ),
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${loc?.amountCannotExceed ?? 'Amount cannot exceed'} $symbol${remainingAmount.toStringAsFixed(2)}',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        (loc?.paymentMethod ?? 'Payment Method').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'cash',
                              label: Text(loc?.cash ?? 'Cash'),
                            ),
                            ButtonSegment(
                              value: 'online',
                              label: Text(loc?.online ?? 'Online'),
                            ),
                          ],
                          selected: {selectedPaymentMethod},
                          onSelectionChanged: (value) {
                            setDialogState(() {
                              selectedPaymentMethod = value.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: Adaptive.compactFilled,
                          onPressed: () async {
                            final paymentAmountStr = amountController.text
                                .trim();
                            if (paymentAmountStr.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc?.pleaseEnterAValidNumber ??
                                        'Please enter a valid number',
                                  ),
                                ),
                              );
                              return;
                            }

                            final paymentAmount = double.tryParse(
                              paymentAmountStr,
                            );
                            if (paymentAmount == null || paymentAmount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc?.pleaseEnterAValidNumber ??
                                        'Please enter a valid number',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (paymentAmount > remainingAmount) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${loc?.amountCannotExceed ?? 'Amount cannot exceed'} ${(loc?.pending ?? 'pending amount').toLowerCase()} $symbol${remainingAmount.toStringAsFixed(2)}',
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              return;
                            }

                            Navigator.of(context).pop();
                            await _addPayment(
                              paymentAmount,
                              selectedPaymentMethod,
                            );
                          },
                          child: Text(loc?.addPayment ?? 'Add Payment'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc?.cancel ?? 'Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addPayment(double amount, String paymentMethod) async {
    final loc = AppLocalizations.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newPayment = {
        'amount': amount,
        'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
        'paymentMethod': paymentMethod,
      };

      final billRef = FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(widget.payment['billId']);

      final billDoc = await billRef.get();
      final currentPreviousPaid =
          (billDoc.data()?['previousPaidAmount'] as num?)?.toDouble() ?? 0.0;

      await billRef.update({
        'previousDuePayments': FieldValue.arrayUnion([newPayment]),
      });

      final newPreviousPaidAmount = currentPreviousPaid + amount;

      await billRef.update({'previousPaidAmount': newPreviousPaidAmount});

      await _loadBillData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc?.paymentAddedSuccessfully ?? 'Payment added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc?.failedToAddPayment ?? 'Failed to add payment'),
          ),
        );
      }
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: scheme.primaryContainer,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      icon,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
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
