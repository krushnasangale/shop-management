import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/billing/bill_success_page.dart';
import 'package:flashbill/pages/billing/review_billing_details.dart';
import 'package:flashbill/pages/product_image_preview_page.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateNewBill extends StatefulWidget {
  final bool isEditMode;
  final String? billId;
  final Map<String, dynamic>? existingBillData;

  const CreateNewBill({
    super.key,
    this.isEditMode = false,
    this.billId,
    this.existingBillData,
  });

  @override
  State<CreateNewBill> createState() => _CreateNewBillState();
}

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
  final String batchId;
  final String purchaseDate;
  final double profitMargin;
  final String? imageUrl;

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
    required this.batchId,
    required this.purchaseDate,
    required this.profitMargin,
    this.imageUrl,
  });

  factory BoughtProduct.fromMap(String id, Map<dynamic, dynamic> data) {
    final buyPrice = (data['buyingPrice'] ?? 0).toDouble();
    final sellPrice = (data['sellingPrice'] ?? 0).toDouble();
    final margin = sellPrice - buyPrice;

    return BoughtProduct(
      id: id,
      date: data['date'] ?? '',
      productName: data['productName'] ?? 'Unknown',
      supplierName: data['supplierName'] ?? 'Unknown',
      unit: data['unit'] ?? '',
      minLimit: data['minLimit'] ?? 0,
      quantity: data['quantity'] ?? 0,
      buyingPrice: buyPrice,
      sellingPrice: sellPrice,
      batchId: data['batchId'] ?? id,
      purchaseDate: data['purchaseDate'] ?? data['date'] ?? '',
      profitMargin: margin,
      imageUrl: data['imageUrl'] as String?,
    );
  }
}

class BillItem {
  final String productName;
  final String supplierName;
  final String unit;
  final double buyingPrice;
  final double sellingPrice;
  final int maxQuantity;
  final String batchId; // Track which batch this item came from
  final double profitMargin; // Profit per unit for this batch
  double billQuantity;
  double billPrice;
  final int order; // Order field to maintain sequence

  BillItem({
    required this.productName,
    required this.supplierName,
    required this.unit,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.maxQuantity,
    required this.billQuantity,
    required this.billPrice,
    required this.batchId,
    required this.profitMargin,
    required this.order,
  });

  double get total => billQuantity * billPrice;
  double get profitTotal => billQuantity * profitMargin;
}

class _CreateNewBillState extends State<CreateNewBill> {
  bool totalAmountPaid = true;
  String paymentMethod = 'cash'; // 'cash' or 'online'
  late String _userId;
  List<BoughtProduct> _availableProducts = [];
  final List<BillItem> _billItems = [];
  bool _productsLoading = true;
  List<Map<String, dynamic>> _customers = [];
  bool _customersLoading = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _customersSubscription;
  StreamSubscription<Map<String, dynamic>>? _appSettingsSubscription;
  late TextEditingController _searchController;
  late TextEditingController _dateController;
  late TextEditingController _customerNameController;
  late TextEditingController _customerMobileController;
  late TextEditingController _customerVehicleController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _productsSubscription;
  String _customerNameError = '';
  String _customerMobileError = '';
  String _customerVehicleError = '';
  String _nextPaymentDateError = '';
  late TextEditingController _amountPaidController;
  late TextEditingController _amountRemainingController;
  late TextEditingController _nextPaymentDateController;
  late TextEditingController _deliveryChargesController;
  double _deliveryCharges = 0.0;
  late TextEditingController _previousDueAmountController;
  double _previousDueAmount = 0.0;
  double _previousPaidAmount = 0.0; // preserved from existing bill when editing
  late TextEditingController _previousDueDescriptionController;
  String _previousDueAmountError = '';
  String _previousDueDescriptionError = '';
  bool _vehicleNumberEnabled = false; // App setting for vehicle number field
  bool _deliveryChargesEnabled =
      false; // App setting for delivery charges field
  bool _previousDueEnabled = false; // App setting for previous due field
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );
    _customerNameController = TextEditingController();
    _customerMobileController = TextEditingController();
    _customerVehicleController = TextEditingController();
    _amountPaidController = TextEditingController();
    _amountRemainingController = TextEditingController();
    _nextPaymentDateController = TextEditingController();
    _deliveryChargesController = TextEditingController();
    _previousDueAmountController = TextEditingController();
    _previousDueDescriptionController = TextEditingController();
    _loadProducts();
    _loadCustomers();
    _loadAppSettings();

    // Load existing bill data if in edit mode
    if (widget.isEditMode && widget.existingBillData != null) {
      _loadExistingBillData();
    }
  }

  void _loadExistingBillData() {
    final billData = widget.existingBillData!;

    // Set customer information
    _customerNameController.text = billData['customerName'] ?? '';
    _customerMobileController.text = billData['customerMobile'] ?? '';
    _customerVehicleController.text = billData['customerVehicle'] ?? '';

    // Set date
    _dateController.text =
        billData['billDate'] ?? DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Set payment method and next payment date
    paymentMethod = billData['paymentMethod'] ?? 'cash';
    _nextPaymentDateController.text = billData['nextPaymentDate'] ?? '';

    // Set payment status
    totalAmountPaid = billData['totalAmountPaid'] ?? true;

    // Restore previous due details
    final prevDueAmount =
        (billData['previousDueAmount'] as num?)?.toDouble() ?? 0.0;
    _previousDueAmount = prevDueAmount;
    if (prevDueAmount > 0) {
      _previousDueAmountController.text = prevDueAmount.toStringAsFixed(2);
      _previousDueDescriptionController.text =
          billData['previousDueDescription'] as String? ?? '';
      // Restore paid amount so it isn't reset to 0 on edit
      _previousPaidAmount =
          (billData['previousPaidAmount'] as num?)?.toDouble() ?? 0.0;
      // Ensure the previous due section is visible even if the setting is off
      _previousDueEnabled = true;
    }

    // Set amount paid and remaining
    final amountPaid = billData['amountPaid'] ?? 0;
    final amountRemaining = billData['amountRemaining'] ?? 0;
    _amountPaidController.text = amountPaid.toString();
    _amountRemainingController.text = amountRemaining.toString();

    // Set delivery charges
    _deliveryCharges = (billData['deliveryCharges'] as num?)?.toDouble() ?? 0.0;
    _deliveryChargesController.text = _deliveryCharges.toStringAsFixed(2);

    // Load products into bill items - delay until products are loaded
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && billData['products'] != null) {
        final products = billData['products'] as List<dynamic>;

        for (var i = 0; i < products.length; i++) {
          final product = products[i];
          // Find the matching product in available products by batch ID
          final batchId = product['batchId'] as String?;
          if (batchId != null) {
            final matchingProduct = _availableProducts.firstWhere(
              (p) => p.batchId == batchId,
              orElse: () => BoughtProduct(
                id: product['productId'] ?? '',
                date: '',
                productName: product['productName'] ?? 'Unknown',
                supplierName: product['supplierName'] ?? 'Unknown',
                unit: product['unit'] ?? '',
                minLimit: 0,
                quantity: ((product['quantity'] ?? 0) as num).toInt(),
                buyingPrice: (product['boughtPrice'] ?? 0).toDouble(),
                sellingPrice: (product['price'] ?? 0).toDouble(),
                batchId: batchId,
                purchaseDate: '',
                profitMargin: (product['profitMargin'] ?? 0).toDouble(),
              ),
            );

            // Create bill item with existing data
            final billItem = BillItem(
              productName: matchingProduct.productName,
              supplierName: matchingProduct.supplierName,
              unit: matchingProduct.unit,
              buyingPrice: matchingProduct.buyingPrice,
              sellingPrice: matchingProduct.sellingPrice,
              maxQuantity:
                  matchingProduct.quantity +
                  ((product['quantity'] ?? 0) as num).toInt(),
              billQuantity: (product['quantity'] ?? 0).toDouble(),
              billPrice: ((product['price'] ?? 0) as num).toDouble(),
              batchId: matchingProduct.batchId,
              profitMargin: matchingProduct.profitMargin,
              order: (product['order'] as int?) ?? i,
            );

            setState(() {
              _billItems.add(billItem);
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateController.dispose();
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _customerVehicleController.dispose();
    _amountPaidController.dispose();
    _amountRemainingController.dispose();
    _nextPaymentDateController.dispose();
    _deliveryChargesController.dispose();
    _previousDueAmountController.dispose();
    _previousDueDescriptionController.dispose();
    _productsSubscription?.cancel();
    _customersSubscription?.cancel();
    _appSettingsSubscription?.cancel();
    _profileService.dispose();
    super.dispose();
  }

  String? _validateCustomerName(String? value, AppLocalizations localizations) {
    if (value == null || value.trim().isEmpty) {
      return localizations.translate('customer_name_required');
    }
    return null;
  }

  String? _validateMobileNumber(String? value, AppLocalizations localizations) {
    if (value == null || value.trim().isEmpty) {
      return null; // Mobile number is optional
    }
    final cleanedValue = value.trim();
    if (!RegExp(r'^[0-9]{10}$').hasMatch(cleanedValue)) {
      return localizations.translate('mobile_number_must_be_10_digits');
    }
    return null;
  }

  String? _validateVehicleNumber(
    String? value,
    AppLocalizations localizations,
  ) {
    if (value == null || value.trim().isEmpty) {
      return null; // Vehicle number is optional
    }
    final cleanedValue = value.trim();
    // Indian vehicle number format: 2 letters, 2 digits, 2 letters, 4 digits (flexible)
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z]{2}[0-9]{4}$').hasMatch(cleanedValue)) {
      return localizations.translate('invalid_vehicle_number_format');
    }
    return null;
  }

  String? _validatePreviousDueAmount(
    String? value,
    AppLocalizations localizations,
  ) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return localizations.translate('please_enter_valid_amount');
    }
    if (amount < 0) {
      return localizations.translate('amount_cannot_be_negative');
    }
    return null;
  }

  String? _validatePreviousDueDescription(
    String? value,
    AppLocalizations localizations,
  ) {
    if (_previousDueAmount > 0 && (value == null || value.trim().isEmpty)) {
      return localizations.translate(
        'description_required_when_amount_entered',
      );
    }
    return null;
  }

  void _loadProducts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
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
                _availableProducts = loadedProducts;
                _productsLoading = false;
              });
            }
          });
    }
  }

  void _loadCustomers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _customersSubscription = FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .collection('items')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
          if (!mounted) return;

          final customers = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'mobileNumber': data['mobileNumber'] ?? '',
              'vehicleNumber': data['vehicleNumber'] ?? '',
            };
          }).toList();
          setState(() {
            _customers = customers;
            _customersLoading = false;
          });
        });
  }

  Future<void> _loadAppSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Initialize ProfileService if not already initialized
      _profileService.initialize(user.uid);

      // Listen to app settings stream for real-time updates
      _appSettingsSubscription = _profileService.appSettingsStream.listen((
        appSettings,
      ) {
        if (mounted) {
          setState(() {
            _vehicleNumberEnabled =
                appSettings['vehicleNumberEnabled'] ?? false;
            _deliveryChargesEnabled =
                appSettings['deliveryChargesEnabled'] ?? false;
            _previousDueEnabled = appSettings['previousDueEnabled'] ?? false;
          });
        }
      });

      // Also try to get current settings immediately in case stream hasn't emitted yet
      final profileData = await _profileService.getCurrentUserProfile();
      if (profileData != null && mounted) {
        final appSettings =
            profileData['appSettings'] as Map<String, dynamic>? ?? {};
        setState(() {
          _vehicleNumberEnabled = appSettings['vehicleNumberEnabled'] ?? false;
          _deliveryChargesEnabled =
              appSettings['deliveryChargesEnabled'] ?? false;
          _previousDueEnabled = appSettings['previousDueEnabled'] ?? false;
        });
      }
    } catch (e) {
      appLog('Error loading app settings: $e');
      // Default to true if error
      if (mounted) {
        setState(() {
          _vehicleNumberEnabled = true;
          _deliveryChargesEnabled = true;
          _previousDueEnabled = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          widget.isEditMode
              ? localizations.translate('edit_bill')
              : localizations.translate('create_new_bill'),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionLabel(context, localizations.translate('select_date')),
                _compactInput(
                  label: localizations.translate('select_date'),
                  controller: _dateController,
                  icon: Icons.calendar_today_outlined,
                  readOnly: true,
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      _dateController.text = DateFormat(
                        'dd/MM/yyyy',
                      ).format(pickedDate);
                    }
                  },
                ),
                const SizedBox(height: 20),
                _sectionLabel(
                  context,
                  localizations.translate('select_customer_from'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: _customerSourceButtonStyle,
                        onPressed: () => _showContactsBottomSheet(context),
                        icon: const Icon(Icons.contact_page_outlined, size: 16),
                        label: Text(localizations.translate('contacts')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: _customerSourceButtonStyle,
                        onPressed: () => _showCustomersDrawer(context),
                        icon: const Icon(Icons.person_outline, size: 16),
                        label: Text(localizations.translate('existing')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _compactInput(
                  label: localizations.translate('customer_full_name'),
                  controller: _customerNameController,
                  icon: Icons.person_outline,
                  errorText: _customerNameError,
                  onChanged: (value) {
                    if (value != value.toUpperCase()) {
                      _customerNameController.text = value.toUpperCase();
                      _customerNameController.selection =
                          TextSelection.fromPosition(
                            TextPosition(offset: value.toUpperCase().length),
                          );
                    }
                    setState(() {
                      _customerNameError =
                          _validateCustomerName(
                            _customerNameController.text,
                            localizations,
                          ) ??
                          '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                _compactInput(
                  label: localizations.translate('customer_mobile_number'),
                  controller: _customerMobileController,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  errorText: _customerMobileError,
                  onChanged: (value) {
                    setState(() {
                      _customerMobileError =
                          _validateMobileNumber(value, localizations) ?? '';
                    });
                  },
                ),
                if (_vehicleNumberEnabled) ...[
                  const SizedBox(height: 12),
                  _compactInput(
                    label: localizations.translate('customer_vehicle_number'),
                    controller: _customerVehicleController,
                    icon: Icons.directions_car_outlined,
                    keyboardType: TextInputType.text,
                    errorText: _customerVehicleError,
                    onChanged: (value) {
                      if (value != value.toUpperCase()) {
                        _customerVehicleController.text = value.toUpperCase();
                        _customerVehicleController.selection =
                            TextSelection.fromPosition(
                              TextPosition(offset: value.toUpperCase().length),
                            );
                      }
                      setState(() {
                        _customerVehicleError =
                            _validateVehicleNumber(
                              _customerVehicleController.text,
                              localizations,
                            ) ??
                            '';
                      });
                    },
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _sectionLabel(
                        context,
                        localizations.translate('products_added_for_billing'),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => showAvailableProductsDrawer(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        _billItems.isEmpty
                            ? localizations.translate('add_product')
                            : localizations.translate('add_more_products'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_billItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    child: Center(
                      child: Text(
                        localizations.translate(
                          'no_products_added_for_billing',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < _billItems.length; i++) ...[
                    _BillItemCard(
                      item: _billItems[i],
                      currencySymbol: localizations.translate(
                        'currency_symbol',
                      ),
                      qtyLabel: localizations.translate('qty_colon'),
                      totalLabel: localizations.translate('total_colon'),
                      onTap: () => _editBillProduct(context, i, _billItems[i]),
                      onRemove: () => _removeBillProduct(i),
                    ),
                    if (i != _billItems.length - 1) const SizedBox(height: 8),
                  ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _squareIcon(Icons.inventory_2_outlined, scheme),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                localizations.translate('total_items'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              '${_getTotalQuantity()} ${localizations.translate('items')}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _squareIcon(Icons.payments_outlined, scheme),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                localizations.translate('total_amount_label'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              '${localizations.translate('currency_symbol')}${_getTotalAmount().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_deliveryChargesEnabled) ...[
                  const SizedBox(height: 20),
                  _sectionLabel(
                    context,
                    localizations.translate('delivery_charges'),
                  ),
                  _compactInput(
                    label: localizations.translate('enter_delivery_charges'),
                    controller: _deliveryChargesController,
                    icon: Icons.local_shipping_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _deliveryCharges = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    localizations.translate('total_amount_paid'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: CupertinoSwitch(
                    value: totalAmountPaid,
                    onChanged: (value) {
                      setState(() {
                        totalAmountPaid = value;
                      });
                    },
                  ),
                  onTap: () {
                    setState(() {
                      totalAmountPaid = !totalAmountPaid;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  localizations.translate('payment_method').toUpperCase(),
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
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 'cash',
                        label: Text(localizations.translate('cash')),
                        icon: const Icon(Icons.money, size: 18),
                      ),
                      ButtonSegment(
                        value: 'online',
                        label: Text(localizations.translate('online')),
                        icon: const Icon(Icons.credit_card, size: 18),
                      ),
                    ],
                    selected: {paymentMethod},
                    onSelectionChanged: (value) {
                      setState(() => paymentMethod = value.first);
                    },
                  ),
                ),
                if (!totalAmountPaid) ...[
                  const SizedBox(height: 12),
                  _compactInput(
                    label: localizations.translate('enter_paid_amount'),
                    controller: _amountPaidController,
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        final totalAmount = _getTotalAmount().toInt();
                        final amountPaid = int.tryParse(value) ?? 0;
                        final remaining = totalAmount - amountPaid;
                        _amountRemainingController.text = remaining.toString();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _compactInput(
                    label: localizations.translate('amount_remaining'),
                    controller: _amountRemainingController,
                    icon: Icons.currency_rupee,
                    readOnly: true,
                    enabled: false,
                  ),
                  const SizedBox(height: 12),
                  _compactInput(
                    label: localizations.translate('next_payment_date'),
                    controller: _nextPaymentDateController,
                    icon: Icons.calendar_today_outlined,
                    readOnly: true,
                    errorText: _nextPaymentDateError,
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (selectedDate != null) {
                        setState(() {
                          _nextPaymentDateController.text = DateFormat(
                            'dd/MM/yyyy',
                          ).format(selectedDate);
                          _nextPaymentDateError = '';
                        });
                      }
                    },
                  ),
                ],
                if (_previousDueEnabled) ...[
                  const SizedBox(height: 20),
                  Card(
                    color: scheme.primaryContainer.withValues(alpha: 0.35),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: scheme.onPrimaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              localizations.translate(
                                'previous_due_amount_info',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _compactInput(
                    label: localizations.translate('previous_due_amount'),
                    controller: _previousDueAmountController,
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    errorText: _previousDueAmountError,
                    onChanged: (value) {
                      setState(() {
                        _previousDueAmount = double.tryParse(value) ?? 0.0;
                        _previousDueAmountError =
                            _validatePreviousDueAmount(value, localizations) ??
                            '';
                        _previousDueDescriptionError =
                            _validatePreviousDueDescription(
                              _previousDueDescriptionController.text,
                              localizations,
                            ) ??
                            '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _previousDueDescriptionController,
                    maxLines: 3,
                    onChanged: (value) {
                      setState(() {
                        _previousDueDescriptionError =
                            _validatePreviousDueDescription(
                              value,
                              localizations,
                            ) ??
                            '';
                      });
                    },
                    decoration: Adaptive.compactField(
                      label: localizations.translate(
                        'previous_due_description',
                      ),
                      hint: localizations.translate(
                        'enter_description_optional',
                      ),
                      icon: Icons.notes_outlined,
                      errorText: _previousDueDescriptionError.isEmpty
                          ? null
                          : _previousDueDescriptionError,
                    ),
                  ),
                ],
              ]),
            ),
          ),
          Adaptive.sliverBottomAction(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: Adaptive.compactOutlined.copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(46),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(localizations.translate('cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: Adaptive.compactFilled,
                    onPressed: () => _processBilling(context, localizations),
                    child: Text(
                      localizations.translate('process_billing'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactInput({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    bool readOnly = false,
    bool enabled = true,
    bool dropdown = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      enabled: enabled,
      onTap: onTap,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration:
          Adaptive.compactField(
            label: label,
            icon: icon,
            errorText: (errorText == null || errorText.isEmpty)
                ? null
                : errorText,
          ).copyWith(
            suffixIcon: dropdown
                ? Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: Adaptive.compactIconSize,
                    color: scheme.onSurfaceVariant,
                  )
                : null,
            suffixIconConstraints: dropdown
                ? Adaptive.compactPrefixConstraints
                : null,
          ),
    );
  }

  Future<void> _processBilling(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    setState(() {
      _customerNameError =
          _validateCustomerName(_customerNameController.text, localizations) ??
          '';
      _customerMobileError =
          _validateMobileNumber(
            _customerMobileController.text,
            localizations,
          ) ??
          '';
      _customerVehicleError = _vehicleNumberEnabled
          ? (_validateVehicleNumber(
                  _customerVehicleController.text,
                  localizations,
                ) ??
                '')
          : '';
      _previousDueAmountError = _previousDueEnabled
          ? (_validatePreviousDueAmount(
                  _previousDueAmountController.text,
                  localizations,
                ) ??
                '')
          : '';
      _previousDueDescriptionError = _previousDueEnabled
          ? (_validatePreviousDueDescription(
                  _previousDueDescriptionController.text,
                  localizations,
                ) ??
                '')
          : '';
    });

    if (_customerNameError.isNotEmpty ||
        _customerMobileError.isNotEmpty ||
        (_vehicleNumberEnabled && _customerVehicleError.isNotEmpty) ||
        (_previousDueEnabled && _previousDueAmountError.isNotEmpty) ||
        (_previousDueEnabled && _previousDueDescriptionError.isNotEmpty)) {
      return;
    }

    if (_billItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations.translate('please_add_products_for_billing'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? customerId = _getExistingCustomerId();

    if (customerId == null) {
      customerId = await _addNewCustomer();
      if (!context.mounted) return;
      if (customerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.translate('failed_to_add_customer')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (!totalAmountPaid) {
      if (_nextPaymentDateController.text.trim().isEmpty) {
        setState(() {
          _nextPaymentDateError = localizations.translate(
            'next_payment_date_required',
          );
        });
        return;
      }
    }

    final billProducts = _billItems.map((item) {
      return BillProductItem(
        productName: item.productName,
        supplierName: item.supplierName,
        unit: item.unit,
        quantity: item.billQuantity,
        price: item.billPrice,
        boughtPrice: item.buyingPrice.toInt(),
        total: item.total,
        batchId: item.batchId,
        profitMargin: item.profitMargin,
        initialQuantity: item.maxQuantity,
        order: item.order,
      );
    }).toList();

    final totalBillAmount = _getTotalAmount().toInt();
    final amountPaidValue = totalAmountPaid
        ? totalBillAmount
        : (int.tryParse(_amountPaidController.text) ?? 0);
    final amountRemainingValue = totalBillAmount - amountPaidValue;

    if (!context.mounted) return;
    AppNavigator.push(
      context,
      ReviewBillingDetails(
        billDate: _dateController.text,
        customerName: _customerNameController.text,
        customerMobile: _customerMobileController.text,
        customerVehicle: _customerVehicleController.text,
        customerId: customerId,
        products: billProducts,
        totalAmount: totalBillAmount,
        totalAmountPaid: totalAmountPaid,
        amountPaid: amountPaidValue,
        amountRemaining: amountRemainingValue,
        paymentMethod: paymentMethod,
        nextPaymentDate: !totalAmountPaid
            ? _nextPaymentDateController.text
            : '',
        isEditMode: widget.isEditMode,
        billId: widget.billId,
        deliveryCharges: _deliveryChargesEnabled ? _deliveryCharges.toInt() : 0,
        previousDueAmount: _previousDueEnabled ? _previousDueAmount : 0.0,
        previousPaidAmount: widget.isEditMode ? _previousPaidAmount : 0.0,
        previousDueDescription: _previousDueEnabled
            ? _previousDueDescriptionController.text.trim()
            : '',
      ),
    );
  }

  void removeProduct() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final localizations = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(localizations.translate('remove_product')),
          content: Text(localizations.translate('confirm_remove_product')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.translate('no')),
            ),
            FilledButton(
              style: Adaptive.compactFilled.copyWith(
                backgroundColor: const WidgetStatePropertyAll(Colors.red),
              ),
              onPressed: () {
                // Add your delete logic here
                Navigator.pop(context);
              },
              child: Text(localizations.translate('yes')),
            ),
          ],
        );
      },
    );
  }

  String? _getExistingCustomerId() {
    final customerName = _customerNameController.text.trim();
    final customerMobile = _customerMobileController.text.trim();

    for (var customer in _customers) {
      if (customer['name'] == customerName &&
          customer['mobileNumber'] == customerMobile) {
        return customer['id'];
      }
    }
    return null;
  }

  Future<String?> _addNewCustomer() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final customerData = {
        'name': _customerNameController.text.trim(),
        'mobileNumber': _customerMobileController.text.trim(),
        'vehicleNumber': _customerVehicleController.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .collection('items')
          .add(customerData);

      return docRef.id;
    } catch (e) {
      appLog('Error adding customer: $e');
      return null;
    }
  }

  int _getTotalAmount() {
    final productTotal = _billItems.fold(
      0.0,
      (total, item) => total + item.total,
    );
    return (productTotal + _deliveryCharges).toInt();
  }

  int _getTotalQuantity() {
    return _billItems.fold(
      0,
      (total, item) => total + item.billQuantity.toInt(),
    );
  }

  Widget _productImagePlaceholder() {
    return ColoredBox(
      color: Colors.grey.shade100,
      child: const SizedBox(
        width: 36,
        height: 36,
        child: Icon(Icons.inventory_2, size: 20, color: Colors.grey),
      ),
    );
  }

  bool _isProductAlreadyAdded(String productName) {
    return _billItems.any((item) => item.productName == productName);
  }

  void _addProductToBill(BoughtProduct product) {
    setState(() {
      // Check if there's already a bill item for this batch
      final existingIndex = _billItems.indexWhere(
        (item) => item.batchId == product.batchId,
      );
      if (existingIndex != -1) {
        // Increase quantity of existing item if not exceeding max
        final existingItem = _billItems[existingIndex];
        if (existingItem.billQuantity < existingItem.maxQuantity) {
          _billItems[existingIndex] = BillItem(
            productName: existingItem.productName,
            supplierName: existingItem.supplierName,
            unit: existingItem.unit,
            buyingPrice: existingItem.buyingPrice,
            sellingPrice: existingItem.sellingPrice,
            maxQuantity: existingItem.maxQuantity,
            billQuantity: existingItem.billQuantity + 1,
            billPrice: existingItem.billPrice,
            batchId: existingItem.batchId,
            profitMargin: existingItem.profitMargin,
            order: existingItem.order,
          );
        }
      } else {
        // Add new item
        // Generate display name with suffix if multiple batches of same product
        final baseName = product.productName;
        final existingCount = _billItems
            .where((item) => item.productName.startsWith(baseName))
            .length;
        final displayName = existingCount > 0
            ? '$baseName (${existingCount + 1})'
            : baseName;
        _billItems.add(
          BillItem(
            productName: displayName,
            supplierName: product.supplierName,
            unit: product.unit,
            buyingPrice: product.buyingPrice,
            sellingPrice: product.sellingPrice,
            maxQuantity: product.quantity,
            billQuantity: 1,
            billPrice: product.sellingPrice,
            batchId: product.batchId,
            profitMargin: product.profitMargin,
            order: _billItems.length,
          ),
        );
      }
    });
  }

  void _showBatchSelectionDialog(
    BuildContext context,
    String productName,
    List<BoughtProduct> batches,
  ) {
    final localizations = AppLocalizations.of(context)!;
    // Batches are already filtered to show only those with remaining quantity
    final availableBatches = batches;

    // If no batches available, show message
    if (availableBatches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.translate('no_batches_available')),
        ),
      );
      return;
    }

    // Sort batches by purchase date (oldest first - FIFO)
    availableBatches.sort((a, b) {
      DateTime dateA = DateTime.tryParse(a.purchaseDate) ?? DateTime.now();
      DateTime dateB = DateTime.tryParse(b.purchaseDate) ?? DateTime.now();
      return dateA.compareTo(dateB);
    });

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final dialogLocalizations = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(
            '${dialogLocalizations.translate('select_batch')}: $productName',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(availableBatches.length, (index) {
                  final batch = availableBatches[index];
                  final isFifo = index == 0;
                  final batchLabel = availableBatches.length > 1
                      ? '${dialogLocalizations.translate('batch')} ${index + 1} ${isFifo ? dialogLocalizations.translate('fifo_oldest') : ''}'
                      : '';
                  final existingBillItems = _billItems
                      .where((item) => item.batchId == batch.batchId)
                      .toList();
                  final totalQuantityAlreadyAdded = existingBillItems.fold(
                    0,
                    (total, item) => total + item.billQuantity.toInt(),
                  );
                  final isBatchFullyUsed =
                      totalQuantityAlreadyAdded >= batch.quantity;

                  final scheme = Theme.of(dialogContext).colorScheme;
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    enabled: !isBatchFullyUsed,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (batchLabel.isNotEmpty)
                          Text(
                            batchLabel,
                            style: TextStyle(
                              color: isFifo
                                  ? Colors.orange
                                  : scheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${dialogLocalizations.translate('buy')}: ${dialogLocalizations.translate('currency_symbol')}${batch.buyingPrice.toStringAsFixed(2)} | ${dialogLocalizations.translate('sell')}: ${dialogLocalizations.translate('currency_symbol')}${batch.sellingPrice.toStringAsFixed(2)}',
                          style: Theme.of(dialogContext).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dialogLocalizations.translate('available')}: ${batch.quantity} ${batch.unit}${batch.quantity != 1 ? 's' : ''}',
                          style: TextStyle(color: scheme.primary, fontSize: 12),
                        ),
                        if (batch.profitMargin > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '${dialogLocalizations.translate('profit_per_unit')}: ${dialogLocalizations.translate('currency_symbol')}${batch.profitMargin.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: scheme.tertiary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: isBatchFullyUsed
                        ? Text(
                            dialogLocalizations.translate('added'),
                            style: TextStyle(
                              color: scheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                    onTap: isBatchFullyUsed
                        ? null
                        : () {
                            _addProductToBill(batch);
                            Navigator.pop(dialogContext);
                            // Open edit dialog for the newly added product
                            Navigator.pop(dialogContext);
                            _editBillProduct(
                              context,
                              _billItems.length - 1,
                              _billItems.last,
                            );
                          },
                  );
                }),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogLocalizations.translate('cancel')),
            ),
          ],
        );
      },
    );
  }

  void _removeBillProduct(int index) {
    setState(() {
      _billItems.removeAt(index);
    });
  }

  void _editBillProduct(BuildContext context, int index, BillItem billItem) {
    final quantityController = TextEditingController(
      text: billItem.billQuantity.toString(),
    );
    final priceController = TextEditingController(
      text: billItem.billPrice.toString(),
    );
    String quantityError = '';
    String priceError = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final dialogLocalizations = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              title: Text(
                dialogLocalizations.translate('edit_product'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              content: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        billItem.productName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Bought Price Display (Reference)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dialogLocalizations.translate('bought_price'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${dialogLocalizations.translate('currency_symbol')} ${billItem.buyingPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Quantity with +/- buttons and input field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dialogLocalizations.translate('quantity'),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  double currentQty =
                                      double.tryParse(
                                        quantityController.text,
                                      ) ??
                                      1;
                                  if (currentQty > 1) {
                                    currentQty--;
                                    quantityController.text = currentQty
                                        .toStringAsFixed(0);
                                    setDialogState(() {
                                      quantityError = '';
                                    });
                                  }
                                },
                                child: Icon(
                                  Icons.remove_circle_outline,
                                  size: 24,
                                  color:
                                      (double.tryParse(
                                                quantityController.text,
                                              ) ??
                                              1) >
                                          1
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: quantityController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textAlign: TextAlign.center,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      // Validate input
                                      final quantity =
                                          double.tryParse(value) ?? 0;
                                      if (quantity > billItem.maxQuantity) {
                                        quantityController.text = billItem
                                            .maxQuantity
                                            .toStringAsFixed(0);
                                        quantityController.selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset: quantityController
                                                    .text
                                                    .length,
                                              ),
                                            );
                                      }
                                      quantityError = '';
                                    });
                                  },
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  double currentQty =
                                      double.tryParse(
                                        quantityController.text,
                                      ) ??
                                      1;
                                  if (currentQty < billItem.maxQuantity) {
                                    currentQty++;
                                    quantityController.text = currentQty
                                        .toStringAsFixed(0);
                                    setDialogState(() {
                                      quantityError = '';
                                    });
                                  }
                                },
                                child: Icon(
                                  Icons.add_circle_outline,
                                  size: 24,
                                  color:
                                      (double.tryParse(
                                                quantityController.text,
                                              ) ??
                                              1) <
                                          billItem.maxQuantity
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          if (quantityError.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                quantityError,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: dialogLocalizations.translate(
                                'selling_price_label',
                              ),
                              prefixText: dialogLocalizations.translate(
                                'currency_symbol',
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          if (priceError.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                priceError,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: Adaptive.compactOutlined,
                        onPressed: () => Navigator.pop(context),
                        child: Text(dialogLocalizations.translate('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: Adaptive.compactFilled.copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                            Size.fromHeight(42),
                          ),
                        ),
                        onPressed: () {
                          final quantity =
                              double.tryParse(quantityController.text) ?? 0;
                          final price =
                              double.tryParse(priceController.text) ?? 0;
                          String qtyErr = '';
                          String priceErr = '';

                          if (quantity <= 0) {
                            qtyErr = dialogLocalizations.translate(
                              'quantity_must_be_greater_than_zero',
                            );
                          } else if (quantity > billItem.maxQuantity) {
                            final errorTemplate = dialogLocalizations.translate(
                              'quantity_cannot_exceed_available',
                            );
                            qtyErr = errorTemplate.replaceAll(
                              '{max}',
                              billItem.maxQuantity.toString(),
                            );
                          }

                          if (price <= 0) {
                            priceErr = dialogLocalizations.translate(
                              'price_must_be_greater_than_zero',
                            );
                          }

                          if (qtyErr.isNotEmpty || priceErr.isNotEmpty) {
                            setDialogState(() {
                              quantityError = qtyErr;
                              priceError = priceErr;
                            });
                          } else {
                            setState(() {
                              _billItems[index].billQuantity = quantity;
                              _billItems[index].billPrice = price;
                            });
                            Navigator.pop(context);
                          }
                        },
                        child: Text(dialogLocalizations.translate('save')),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomersDrawer(BuildContext context) {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> displayCustomers = _customers;

    Adaptive.showSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final modalLocalizations = AppLocalizations.of(context)!;
            final scheme = Theme.of(context).colorScheme;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          modalLocalizations.translate('select_customer'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: CupertinoSearchTextField(
                    controller: searchController,
                    placeholder: modalLocalizations.translate(
                      'search_customer',
                    ),
                    padding: Adaptive.compactFieldPadding,
                    itemSize: Adaptive.compactIconSize,
                    prefixIcon: const Icon(CupertinoIcons.search),
                    suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill),
                    onChanged: (query) {
                      setModalState(() {
                        if (query.isEmpty) {
                          displayCustomers = _customers;
                        } else {
                          displayCustomers = _customers
                              .where(
                                (customer) =>
                                    SearchUtils.matchesSubsequence(
                                      customer['name'].toString(),
                                      query,
                                    ) ||
                                    SearchUtils.matchesSubsequence(
                                      customer['mobileNumber'].toString(),
                                      query,
                                    ),
                              )
                              .toList();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _customersLoading
                      ? Center(child: Adaptive.progress())
                      : displayCustomers.isEmpty
                      ? Center(
                          child: Text(
                            modalLocalizations.translate('no_customers_found'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: displayCustomers.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 64),
                          itemBuilder: (context, index) {
                            final customer = displayCustomers[index];
                            final vehicle = (customer['vehicleNumber'] ?? '')
                                .toString();
                            final subtitle = vehicle.isNotEmpty
                                ? '${modalLocalizations.translate('mobile_label')} ${customer['mobileNumber']}  ·  ${modalLocalizations.translate('vehicle_label')} $vehicle'
                                : '${modalLocalizations.translate('mobile_label')} ${customer['mobileNumber']}';
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                4,
                                12,
                                4,
                              ),
                              leading: _squareIcon(
                                Icons.person_outline,
                                scheme,
                              ),
                              title: Text(
                                customer['name'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                setState(() {
                                  _customerNameController.text =
                                      customer['name'];
                                  _customerMobileController.text =
                                      customer['mobileNumber'];
                                  _customerVehicleController.text =
                                      customer['vehicleNumber'];
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void showAvailableProductsDrawer(BuildContext context) {
    final searchController = TextEditingController();
    Map<String, Map<String, dynamic>> uniqueProducts = {};
    for (var product in _availableProducts) {
      final existingBillItems = _billItems
          .where((item) => item.batchId == product.batchId)
          .toList();
      final totalQuantityAlreadyAdded = existingBillItems.fold(
        0,
        (int total, item) => total + item.billQuantity.toInt(),
      );

      if (product.quantity > totalQuantityAlreadyAdded) {
        if (!uniqueProducts.containsKey(product.productName)) {
          uniqueProducts[product.productName] = {
            'product': product,
            'totalQuantity': _isProductAlreadyAdded(product.productName)
                ? product.quantity
                : product.quantity - totalQuantityAlreadyAdded,
            'batchCount': 1,
          };
        } else {
          final isAlreadyAdded = _isProductAlreadyAdded(product.productName);
          uniqueProducts[product.productName]!['totalQuantity'] +=
              isAlreadyAdded
              ? product.quantity
              : (product.quantity - totalQuantityAlreadyAdded);
          uniqueProducts[product.productName]!['batchCount'] += 1;
        }
      }
    }
    List<Map<String, dynamic>> displayProducts = uniqueProducts.values.toList();
    bool showSearch = false;

    Map<String, Map<String, dynamic>> buildUniqueProducts(String query) {
      final Map<String, Map<String, dynamic>> uniqueFilteredProducts = {};
      for (var product in _availableProducts) {
        if (query.isNotEmpty &&
            !(SearchUtils.matchesSubsequence(product.productName, query) ||
                SearchUtils.matchesSubsequence(product.supplierName, query))) {
          continue;
        }
        final existingBillItems = _billItems
            .where((item) => item.batchId == product.batchId)
            .toList();
        final totalQuantityAlreadyAdded = existingBillItems.fold(
          0,
          (total, item) => total + item.billQuantity.toInt(),
        );

        if (product.quantity > totalQuantityAlreadyAdded) {
          if (!uniqueFilteredProducts.containsKey(product.productName)) {
            uniqueFilteredProducts[product.productName] = {
              'product': product,
              'totalQuantity': _isProductAlreadyAdded(product.productName)
                  ? product.quantity
                  : product.quantity - totalQuantityAlreadyAdded,
              'batchCount': 1,
            };
          } else {
            final isAlreadyAdded = _isProductAlreadyAdded(product.productName);
            uniqueFilteredProducts[product.productName]!['totalQuantity'] +=
                isAlreadyAdded
                ? product.quantity
                : (product.quantity - totalQuantityAlreadyAdded);
            uniqueFilteredProducts[product.productName]!['batchCount'] += 1;
          }
        }
      }
      return uniqueFilteredProducts;
    }

    Adaptive.showSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            final modalLocalizations = AppLocalizations.of(context)!;
            final scheme = Theme.of(context).colorScheme;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          modalLocalizations.translate('select_product'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: modalLocalizations.translate(
                          'search_products',
                        ),
                        icon: Icon(
                          showSearch ? Icons.search_off : Icons.search,
                        ),
                        onPressed: () {
                          setModalState(() {
                            showSearch = !showSearch;
                            if (!showSearch &&
                                searchController.text.isNotEmpty) {
                              searchController.clear();
                              displayProducts = buildUniqueProducts(
                                '',
                              ).values.toList();
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                if (showSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: CupertinoSearchTextField(
                      controller: searchController,
                      autofocus: true,
                      placeholder: modalLocalizations.translate(
                        'search_products',
                      ),
                      padding: Adaptive.compactFieldPadding,
                      itemSize: Adaptive.compactIconSize,
                      prefixIcon: const Icon(CupertinoIcons.search),
                      suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill),
                      onChanged: (query) {
                        setModalState(() {
                          displayProducts = buildUniqueProducts(
                            query,
                          ).values.toList();
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: scheme.primaryContainer.withValues(alpha: 0.35),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: scheme.onPrimaryContainer,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              modalLocalizations.translate('batch_info_text'),
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: _productsLoading
                      ? Center(child: Adaptive.progress())
                      : displayProducts.isEmpty
                      ? Center(
                          child: Text(
                            modalLocalizations.translate('no_products_found'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: displayProducts.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 64),
                          itemBuilder: (context, index) {
                            final productData = displayProducts[index];
                            final product =
                                productData['product'] as BoughtProduct;
                            final totalQuantity =
                                (productData['totalQuantity'] as num).toInt();
                            final batchCount =
                                (productData['batchCount'] as num).toInt();
                            final isAlreadyAdded = _isProductAlreadyAdded(
                              product.productName,
                            );
                            final displayName =
                                product.productName[0].toUpperCase() +
                                product.productName.substring(1);
                            final subtitle =
                                '${modalLocalizations.translate('unit_label')} ${product.unit}  ·  ${modalLocalizations.translate('qty_label')} $totalQuantity'
                                '${batchCount > 1 ? '  ·  $batchCount ${modalLocalizations.translate('batches')}' : ''}';
                            final hasImage =
                                product.imageUrl != null &&
                                product.imageUrl!.isNotEmpty;

                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              enabled: !isAlreadyAdded,
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                4,
                                12,
                                4,
                              ),
                              leading: GestureDetector(
                                onTap: hasImage
                                    ? () => AppNavigator.push(
                                        context,
                                        ProductImagePreviewPage(
                                          imageUrl: product.imageUrl!,
                                          productName: displayName,
                                        ),
                                      )
                                    : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: hasImage
                                      ? CachedNetworkImage(
                                          imageUrl: product.imageUrl!,
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              _productImagePlaceholder(),
                                          errorWidget: (context, url, error) =>
                                              _productImagePlaceholder(),
                                        )
                                      : _productImagePlaceholder(),
                                ),
                              ),
                              title: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isAlreadyAdded
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isAlreadyAdded
                                      ? scheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                              trailing: isAlreadyAdded
                                  ? Text(
                                      modalLocalizations.translate(
                                        'already_added',
                                      ),
                                      style: TextStyle(
                                        color: scheme.secondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : Text(
                                      '${modalLocalizations.translate('currency_symbol')}${product.sellingPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary,
                                      ),
                                    ),
                              onTap: isAlreadyAdded
                                  ? null
                                  : () {
                                      final productBatches = _availableProducts
                                          .where(
                                            (p) =>
                                                p.productName ==
                                                product.productName,
                                          )
                                          .where((p) {
                                            final used = _billItems
                                                .where(
                                                  (item) =>
                                                      item.batchId == p.batchId,
                                                )
                                                .fold<int>(
                                                  0,
                                                  (total, item) =>
                                                      total +
                                                      item.billQuantity.toInt(),
                                                );
                                            return p.quantity > used;
                                          })
                                          .toList();

                                      if (productBatches.isEmpty) return;

                                      if (productBatches.length == 1) {
                                        Navigator.pop(context);
                                        _addProductToBill(productBatches.first);
                                        _editBillProduct(
                                          context,
                                          _billItems.length - 1,
                                          _billItems.last,
                                        );
                                      } else {
                                        _showBatchSelectionDialog(
                                          context,
                                          product.productName,
                                          productBatches,
                                        );
                                      }
                                    },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showContactsBottomSheet(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final status = await Permission.contacts.request();

    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.translate('contact_permission_required'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    List<Contact> contacts = [];
    try {
      contacts = await FastContacts.getAllContacts();
      appLog('Fetched ${contacts.length} contacts');
    } catch (e) {
      appLog('Error fetching contacts: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.translate('error_loading_contacts')}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final searchController = TextEditingController();
    List<Contact> displayContacts = contacts;

    Adaptive.showSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final modalLocalizations = AppLocalizations.of(context)!;
            final scheme = Theme.of(context).colorScheme;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          modalLocalizations.translate('select_from_contacts'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: CupertinoSearchTextField(
                    controller: searchController,
                    placeholder: modalLocalizations.translate(
                      'search_contacts',
                    ),
                    padding: Adaptive.compactFieldPadding,
                    itemSize: Adaptive.compactIconSize,
                    prefixIcon: const Icon(CupertinoIcons.search),
                    suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill),
                    onChanged: (query) {
                      setModalState(() {
                        if (query.isEmpty) {
                          displayContacts = contacts;
                        } else {
                          displayContacts = contacts
                              .where(
                                (contact) =>
                                    SearchUtils.matchesSubsequence(
                                      contact.displayName,
                                      query,
                                    ) ||
                                    contact.phones.any(
                                      (phone) => SearchUtils.matchesSubsequence(
                                        phone.number,
                                        query,
                                      ),
                                    ),
                              )
                              .toList();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: displayContacts.isEmpty
                      ? Center(
                          child: Text(
                            modalLocalizations.translate('no_contacts_found'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: displayContacts.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 64),
                          itemBuilder: (context, index) {
                            final contact = displayContacts[index];
                            final phoneNumber = contact.phones.isNotEmpty
                                ? contact.phones.first.number
                                : modalLocalizations.translate('no_phone');

                            final cleanedPhoneNumber = phoneNumber.replaceAll(
                              RegExp(r'[^\d]'),
                              '',
                            );

                            final validPhoneNumber =
                                cleanedPhoneNumber.length >= 10
                                ? cleanedPhoneNumber.substring(
                                    cleanedPhoneNumber.length - 10,
                                  )
                                : cleanedPhoneNumber;

                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                4,
                                12,
                                4,
                              ),
                              leading: _squareIcon(Icons.person, scheme),
                              title: Text(
                                contact.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                cleanedPhoneNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: validPhoneNumber.length == 10
                                      ? scheme.primary
                                      : scheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onTap: () {
                                try {
                                  if (contact.phones.isEmpty ||
                                      phoneNumber == 'No phone') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          modalLocalizations.translate(
                                            'no_phone_number_found',
                                          ),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  if (validPhoneNumber.length == 10) {
                                    setState(() {
                                      _customerNameController.text =
                                          contact.displayName;
                                      _customerMobileController.text =
                                          validPhoneNumber;
                                    });
                                    Navigator.pop(context);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          modalLocalizations
                                              .translate('invalid_phone_number')
                                              .replaceAll(
                                                '{name}',
                                                contact.displayName,
                                              ),
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  appLog('Error selecting contact: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        modalLocalizations.translate(
                                          'error_selecting_contact',
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final ButtonStyle _customerSourceButtonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 38),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  padding: const EdgeInsets.symmetric(horizontal: 10),
  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
);

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

class _BillItemCard extends StatelessWidget {
  const _BillItemCard({
    required this.item,
    required this.currencySymbol,
    required this.qtyLabel,
    required this.totalLabel,
    required this.onTap,
    required this.onRemove,
  });

  final BillItem item;
  final String currencySymbol;
  final String qtyLabel;
  final String totalLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        title: Text(
          item.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        subtitle: Text(
          '$qtyLabel ${item.billQuantity.toStringAsFixed(0)}  ·  $currencySymbol${item.billPrice.toStringAsFixed(2)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currencySymbol${item.total.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.delete_outline, color: scheme.error),
              tooltip: totalLabel,
            ),
          ],
        ),
      ),
    );
  }
}
