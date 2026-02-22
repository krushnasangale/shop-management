import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/billing/bill_success_page.dart';
import 'package:flashbill/pages/billing/review_billing_details.dart';
import 'package:flashbill/ui%20helpers/ui_helper.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/utils/search_utils.dart';

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

        for (var product in products) {
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
      print('Error loading app settings: $e');
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                buildFormField(
                  localizations.translate('select_date'),
                  _dateController,
                  suffixIcon: Icons.calendar_today_outlined,
                  onTap: () async {
                    // Show date picker
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
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations.translate('select_customer_from'),
                    style: context.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Select Customer section
                Row(
                  children: [
                    SizedBox(
                      height: 25,
                      child: ElevatedButton.icon(
                        onPressed: () => _showContactsBottomSheet(context),
                        icon: const Icon(
                          Icons.contact_page,
                          color: Colors.white,
                        ),
                        label: Text(
                          localizations.translate('contacts'),
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 25,
                      child: ElevatedButton.icon(
                        onPressed: () => _showCustomersDrawer(context),
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: Text(
                          localizations.translate('existing'),
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildFormField(
                      localizations.translate('customer_full_name'),
                      _customerNameController,
                      onChanged: (value) {
                        // Convert to uppercase
                        if (value != value.toUpperCase()) {
                          _customerNameController.text = value.toUpperCase();
                          _customerNameController
                              .selection = TextSelection.fromPosition(
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
                    const SizedBox(height: 10),
                    if (_customerNameError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 4,
                          left: 16,
                          bottom: 10,
                        ),
                        child: Text(
                          _customerNameError,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildFormField(
                      localizations.translate('customer_mobile_number'),
                      _customerMobileController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _customerMobileError =
                              _validateMobileNumber(value, localizations) ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    if (_customerMobileError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 4,
                          left: 16,
                          bottom: 10,
                        ),
                        child: Text(
                          _customerMobileError,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),

                if (_vehicleNumberEnabled)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildFormField(
                        localizations.translate('customer_vehicle_number'),
                        _customerVehicleController,
                        keyboardType: TextInputType.text,
                        onChanged: (value) {
                          // Convert to uppercase
                          if (value != value.toUpperCase()) {
                            _customerVehicleController.text = value
                                .toUpperCase();
                            _customerVehicleController
                                .selection = TextSelection.fromPosition(
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
                      const SizedBox(height: 10),
                      if (_customerVehicleError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 4,
                            left: 16,
                            bottom: 10,
                          ),
                          child: Text(
                            _customerVehicleError,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),

                // Products section
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 25,
                      child: ElevatedButton.icon(
                        onPressed: () => showAvailableProductsDrawer(context),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text(
                          _billItems.isEmpty
                              ? localizations.translate('add_product')
                              : localizations.translate('add_more_products'),
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.translate('products_added_for_billing'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_billItems.isEmpty) const SizedBox(height: 12),
                    if (_billItems.isEmpty)
                      Center(
                        child: Text(
                          localizations.translate(
                            'no_products_added_for_billing',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_billItems.isNotEmpty)
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _billItems.length,
                          itemBuilder: (context, index) {
                            final billItem = _billItems[index];
                            return InkWell(
                              onTap: () =>
                                  _editBillProduct(context, index, billItem),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Card(
                                  child: Container(
                                    width: 160,
                                    padding: const EdgeInsets.all(10.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                billItem.productName,
                                                style: context.bodyLargeText
                                                    ?.copyWith(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _removeBillProduct(index),
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              localizations.translate(
                                                'qty_colon',
                                              ),
                                              style: context.bodyMediumText
                                                  ?.copyWith(fontSize: 12),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              billItem.billQuantity
                                                  .toStringAsFixed(0),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${localizations.translate('currency_symbol')}${billItem.billPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${localizations.translate('total_colon')} ${localizations.translate('currency_symbol')}${billItem.total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizations.translate('total_items'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_getTotalQuantity()} ${localizations.translate('items')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizations.translate('total_amount_label'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${localizations.translate('currency_symbol')}${_getTotalAmount().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Delivery Charges Field
                if (_deliveryChargesEnabled)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.translate('delivery_charges'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildFormField(
                        localizations.translate('enter_delivery_charges'),
                        _deliveryChargesController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _deliveryCharges = double.tryParse(value) ?? 0.0;
                          });
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Switch(
                      value: totalAmountPaid,
                      onChanged: (value) {
                        setState(() {
                          totalAmountPaid = value;
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    Text(
                      localizations.translate('total_amount_paid'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Payment Method Selection
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.translate('payment_method'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  paymentMethod = 'cash';
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: paymentMethod == 'cash'
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  border: Border.all(
                                    color: paymentMethod == 'cash'
                                        ? Colors.blue
                                        : Colors.grey.withOpacity(0.3),
                                    width: paymentMethod == 'cash' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.money,
                                      color: paymentMethod == 'cash'
                                          ? Colors.blue
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      localizations.translate('cash'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: paymentMethod == 'cash'
                                            ? Colors.blue
                                            : Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  paymentMethod = 'online';
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: paymentMethod == 'online'
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  border: Border.all(
                                    color: paymentMethod == 'online'
                                        ? Colors.green
                                        : Colors.grey.withOpacity(0.3),
                                    width: paymentMethod == 'online' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.credit_card,
                                      color: paymentMethod == 'online'
                                          ? Colors.green
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      localizations.translate('online'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: paymentMethod == 'online'
                                            ? Colors.green
                                            : Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!totalAmountPaid) const SizedBox(height: 12),

                if (!totalAmountPaid)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildFormField(
                        localizations.translate('enter_paid_amount'),
                        _amountPaidController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            // Auto-calculate remaining amount
                            final totalAmount = _getTotalAmount().toInt();
                            final amountPaid = int.tryParse(value) ?? 0;
                            final remaining = totalAmount - amountPaid;
                            _amountRemainingController.text = remaining
                                .toString();
                          });
                        },
                      ),
                    ],
                  ),

                if (!totalAmountPaid)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.translate('amount_remaining'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        height: 53,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: Colors.grey[700]!),
                          color: Colors.grey[100],
                        ),
                        child: TextField(
                          controller: _amountRemainingController,
                          enabled: false,
                          decoration: InputDecoration(
                            fillColor: Colors.white,
                            hintText: '0',
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16.0,
                              horizontal: 16.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                            prefix: Text(
                              localizations.translate('currency_symbol'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                if (!totalAmountPaid)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.translate('next_payment_date'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      GestureDetector(
                        onTap: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (selectedDate != null) {
                            setState(() {
                              _nextPaymentDateController.text = DateFormat(
                                'dd/MM/yyyy',
                              ).format(selectedDate);
                              _nextPaymentDateError =
                                  ''; // Clear error when date is selected
                            });
                          }
                        },
                        child: Container(
                          height: 53,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: _nextPaymentDateError.isNotEmpty
                                  ? Colors.red
                                  : Colors.grey[700]!,
                            ),
                            color: Colors.grey[100],
                          ),
                          child: TextField(
                            controller: _nextPaymentDateController,
                            enabled: false,
                            decoration: InputDecoration(
                              fillColor: Colors.white,
                              hintText: localizations.translate(
                                'select_date_hint',
                              ),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                                horizontal: 16.0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                      if (_nextPaymentDateError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 16),
                          child: Text(
                            _nextPaymentDateError,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                // Previous Due Amount Section
                if (_previousDueEnabled) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            localizations.translate('previous_due_amount_info'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildFormField(
                        localizations.translate('previous_due_amount'),
                        _previousDueAmountController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _previousDueAmount = double.tryParse(value) ?? 0.0;
                            _previousDueAmountError =
                                _validatePreviousDueAmount(
                                  value,
                                  localizations,
                                ) ??
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
                      const SizedBox(height: 10),
                      if (_previousDueAmountError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 10),
                          child: Text(
                            _previousDueAmountError,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Text(
                        localizations.translate('previous_due_description'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: _previousDueDescriptionError.isNotEmpty
                                ? Colors.red
                                : Colors.grey[700]!,
                          ),
                          color: Colors.grey[100],
                        ),
                        child: TextField(
                          controller: _previousDueDescriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            fillColor: Colors.white,
                            hintText: localizations.translate(
                              'enter_description_optional',
                            ),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 16.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide.none,
                            ),
                          ),
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
                        ),
                      ),
                      if (_previousDueDescriptionError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 16),
                          child: Text(
                            _previousDueDescriptionError,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                // Buttons fixed at the bottom
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: TextButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[400],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              localizations.translate('cancel'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Validate form fields
                            setState(() {
                              _customerNameError =
                                  _validateCustomerName(
                                    _customerNameController.text,
                                    localizations,
                                  ) ??
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
                                          _previousDueDescriptionController
                                              .text,
                                          localizations,
                                        ) ??
                                        '')
                                  : '';
                            });

                            // Check if there are any errors
                            if (_customerNameError.isNotEmpty ||
                                _customerMobileError.isNotEmpty ||
                                (_vehicleNumberEnabled &&
                                    _customerVehicleError.isNotEmpty) ||
                                (_previousDueEnabled &&
                                    _previousDueAmountError.isNotEmpty) ||
                                (_previousDueEnabled &&
                                    _previousDueDescriptionError.isNotEmpty)) {
                              return;
                            }

                            // Check if products are added
                            if (_billItems.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    localizations.translate(
                                      'please_add_products_for_billing',
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Check if customer exists, if not add to database
                            String? customerId = _getExistingCustomerId();

                            if (customerId == null) {
                              // Add new customer to database
                              customerId = await _addNewCustomer();
                              if (customerId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      localizations.translate(
                                        'failed_to_add_customer',
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                            }

                            // Validate partial payment - next payment date is mandatory
                            if (!totalAmountPaid) {
                              if (_nextPaymentDateController.text
                                  .trim()
                                  .isEmpty) {
                                setState(() {
                                  _nextPaymentDateError = localizations
                                      .translate('next_payment_date_required');
                                });
                                return;
                              }
                            }

                            // Prepare bill products for review screen
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
                              );
                            }).toList();

                            final totalBillAmount = _getTotalAmount().toInt();
                            final amountPaidValue = totalAmountPaid
                                ? totalBillAmount
                                : (int.tryParse(_amountPaidController.text) ??
                                      0);
                            final amountRemainingValue =
                                totalBillAmount - amountPaidValue;

                            AppNavigator.push(
                              context,
                              ReviewBillingDetails(
                                billDate: _dateController.text,
                                customerName: _customerNameController.text,
                                customerMobile: _customerMobileController.text,
                                customerVehicle:
                                    _customerVehicleController.text,
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
                                deliveryCharges: _deliveryChargesEnabled
                                    ? _deliveryCharges.toInt()
                                    : 0,
                                previousDueAmount: _previousDueEnabled
                                    ? _previousDueAmount
                                    : 0.0,
                                previousPaidAmount: 0.0,
                                previousDueDescription: _previousDueEnabled
                                    ? _previousDueDescriptionController.text
                                          .trim()
                                    : '',
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            localizations.translate('process_billing'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
            ElevatedButton(
              onPressed: () {
                // Add your delete logic here
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
      print('Error adding customer: $e');
      return null;
    }
  }

  int _getTotalAmount() {
    final productTotal = _billItems.fold(0.0, (sum, item) => sum + item.total);
    return (productTotal + _deliveryCharges).toInt();
  }

  int _getTotalQuantity() {
    return _billItems.fold(0, (sum, item) => sum + item.billQuantity.toInt());
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
            style: context.bodyLargeText,
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
                    (sum, item) => sum + item.billQuantity.toInt(),
                  );
                  final isBatchFullyUsed =
                      totalQuantityAlreadyAdded >= batch.quantity;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (batchLabel.isNotEmpty)
                            Text(
                              batchLabel,
                              style: TextStyle(
                                color: isFifo
                                    ? Colors.orange
                                    : context.secondaryTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '${dialogLocalizations.translate('buy')}: ${dialogLocalizations.translate('currency_symbol')}${batch.buyingPrice.toStringAsFixed(2)} | ${dialogLocalizations.translate('sell')}: ${dialogLocalizations.translate('currency_symbol')}${batch.sellingPrice.toStringAsFixed(2)}',
                            style: context.bodyLargeText?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dialogLocalizations.translate('available')}: ${batch.quantity} ${batch.unit}${batch.quantity != 1 ? 's' : ''}',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                          if (batch.profitMargin > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${dialogLocalizations.translate('profit_per_unit')}: ${dialogLocalizations.translate('currency_symbol')}${batch.profitMargin.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.purple[400],
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: isBatchFullyUsed
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                dialogLocalizations.translate('added'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
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
                    ),
                  );
                }),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                dialogLocalizations.translate('cancel'),
                style: context.bodyLargeText,
              ),
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
              title: Text(
                dialogLocalizations.translate('edit_product'),
                style: context.bodyLargeText,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      billItem.productName,
                      style: context.titleLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Bought Price Display (Reference)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
                          style: context.bodyLargeText,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                double currentQty =
                                    double.tryParse(quantityController.text) ??
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
                                    (double.tryParse(quantityController.text) ??
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
                                    double.tryParse(quantityController.text) ??
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
                                    (double.tryParse(quantityController.text) ??
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(dialogLocalizations.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final quantity =
                        double.tryParse(quantityController.text) ?? 0;
                    final price = double.tryParse(priceController.text) ?? 0;
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text(
                    dialogLocalizations.translate('save'),
                    style: TextStyle(color: Colors.white),
                  ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final modalLocalizations = AppLocalizations.of(context)!;
            return Column(
              children: [
                // Title and close button
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        modalLocalizations.translate('select_customer'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 45,
                    child: TextField(
                      controller: searchController,
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
                      decoration: InputDecoration(
                        hintText: modalLocalizations.translate(
                          'search_customer',
                        ),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Customers list
                Expanded(
                  child: _customersLoading
                      ? const Center(child: CircularProgressIndicator())
                      : displayCustomers.isEmpty
                      ? Center(
                          child: Text(
                            modalLocalizations.translate('no_customers_found'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: displayCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = displayCustomers[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 4.0,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: BorderSide(
                                  color:
                                      Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.1) ??
                                      Colors.grey,
                                  width: 1.5,
                                ),
                              ),
                              child: InkWell(
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
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 16.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer['name'],
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${modalLocalizations.translate('mobile_label')} ${customer['mobileNumber']}',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.color,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (customer['vehicleNumber']
                                              .isNotEmpty)
                                            Text(
                                              '${modalLocalizations.translate('vehicle_label')} ${customer['vehicleNumber']}',
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium?.color,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
    // Group products by name and show total quantity across all batches with quantity > 0 and not fully used in bill
    Map<String, Map<String, dynamic>> uniqueProducts = {};
    for (var product in _availableProducts) {
      // Calculate how much quantity is already used for this batch
      final existingBillItems = _billItems
          .where((item) => item.batchId == product.batchId)
          .toList();
      final totalQuantityAlreadyAdded = existingBillItems.fold(
        0,
        (int sum, item) => sum + item.billQuantity.toInt(),
      );

      // Only include products with remaining quantity > 0
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
          // Add quantity from additional batches
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final modalLocalizations = AppLocalizations.of(context)!;
            return Column(
              children: [
                // Title and close button
                Container(
                  padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        modalLocalizations.translate('select_product'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 50,
                    child: TextField(
                      controller: searchController,
                      onChanged: (query) {
                        setModalState(() {
                          if (query.isEmpty) {
                            // Show all unique products with total quantities
                            Map<String, Map<String, dynamic>>
                            uniqueFilteredProducts = {};
                            for (var product in _availableProducts) {
                              // Calculate how much quantity is already used for this batch
                              final existingBillItems = _billItems
                                  .where(
                                    (item) => item.batchId == product.batchId,
                                  )
                                  .toList();
                              final totalQuantityAlreadyAdded =
                                  existingBillItems.fold(
                                    0,
                                    (sum, item) =>
                                        sum + item.billQuantity.toInt(),
                                  );

                              // Only include products with remaining quantity > 0
                              if (product.quantity >
                                  totalQuantityAlreadyAdded) {
                                if (!uniqueFilteredProducts.containsKey(
                                  product.productName,
                                )) {
                                  uniqueFilteredProducts[product.productName] =
                                      {
                                        'product': product,
                                        'totalQuantity':
                                            _isProductAlreadyAdded(
                                              product.productName,
                                            )
                                            ? product.quantity
                                            : product.quantity -
                                                  totalQuantityAlreadyAdded,
                                        'batchCount': 1,
                                      };
                                } else {
                                  // Add quantity from additional batches
                                  final isAlreadyAdded = _isProductAlreadyAdded(
                                    product.productName,
                                  );
                                  uniqueFilteredProducts[product
                                          .productName]!['totalQuantity'] +=
                                      isAlreadyAdded
                                      ? product.quantity
                                      : (product.quantity -
                                            totalQuantityAlreadyAdded);
                                  uniqueFilteredProducts[product
                                          .productName]!['batchCount'] +=
                                      1;
                                }
                              }
                            }
                            displayProducts = uniqueFilteredProducts.values
                                .toList();
                          } else {
                            // Filter and show unique products with total quantities
                            Map<String, Map<String, dynamic>>
                            uniqueFilteredProducts = {};
                            for (var product in _availableProducts) {
                              if (SearchUtils.matchesSubsequence(
                                    product.productName,
                                    query,
                                  ) ||
                                  SearchUtils.matchesSubsequence(
                                    product.supplierName,
                                    query,
                                  )) {
                                // Calculate how much quantity is already used for this batch
                                final existingBillItems = _billItems
                                    .where(
                                      (item) => item.batchId == product.batchId,
                                    )
                                    .toList();
                                final totalQuantityAlreadyAdded =
                                    existingBillItems.fold(
                                      0,
                                      (sum, item) =>
                                          sum + item.billQuantity.toInt(),
                                    );

                                // Only include products with remaining quantity > 0
                                if (product.quantity >
                                    totalQuantityAlreadyAdded) {
                                  if (!uniqueFilteredProducts.containsKey(
                                    product.productName,
                                  )) {
                                    uniqueFilteredProducts[product
                                        .productName] = {
                                      'product': product,
                                      'totalQuantity':
                                          _isProductAlreadyAdded(
                                            product.productName,
                                          )
                                          ? product.quantity
                                          : product.quantity -
                                                totalQuantityAlreadyAdded,
                                      'batchCount': 1,
                                    };
                                  } else {
                                    // Add quantity from additional batches
                                    final isAlreadyAdded =
                                        _isProductAlreadyAdded(
                                          product.productName,
                                        );
                                    uniqueFilteredProducts[product
                                            .productName]!['totalQuantity'] +=
                                        isAlreadyAdded
                                        ? product.quantity
                                        : (product.quantity -
                                              totalQuantityAlreadyAdded);
                                    uniqueFilteredProducts[product
                                            .productName]!['batchCount'] +=
                                        1;
                                  }
                                }
                              }
                            }
                            displayProducts = uniqueFilteredProducts.values
                                .toList();
                          }
                        });
                      },
                      decoration: InputDecoration(
                        hintText: modalLocalizations.translate(
                          'search_products',
                        ),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Info text about batch selection rules
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            modalLocalizations.translate('batch_info_text'),
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Products list
                Expanded(
                  child: _productsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : displayProducts.isEmpty
                      ? Center(
                          child: Text(
                            modalLocalizations.translate('no_products_found'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: displayProducts.length,
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
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 6.0,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: BorderSide(
                                  color:
                                      Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.1) ??
                                      Colors.grey,
                                  width: 1.5,
                                ),
                              ),
                              child: InkWell(
                                onTap: isAlreadyAdded
                                    ? null
                                    : () {
                                        // Get all available batches for this product
                                        final productBatches =
                                            _availableProducts
                                                .where(
                                                  (p) =>
                                                      p.productName ==
                                                      product.productName,
                                                )
                                                .toList();

                                        if (productBatches.length == 1) {
                                          Navigator.pop(
                                            context,
                                          ); // Close product selection drawer
                                          // Only one batch available, add directly and show edit dialog
                                          _addProductToBill(
                                            productBatches.first,
                                          );

                                          _editBillProduct(
                                            context,
                                            _billItems.length - 1,
                                            _billItems.last,
                                          );
                                        } else {
                                          // Multiple batches available, show batch selection dialog
                                          _showBatchSelectionDialog(
                                            context,
                                            product.productName,
                                            productBatches,
                                          );
                                        }
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 12.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        product.productName[0]
                                                                .toUpperCase() +
                                                            product.productName
                                                                .substring(1),
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyLarge
                                                                  ?.color,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    if (batchCount > 1) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.purple
                                                              .withOpacity(
                                                                0.15,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                Colors.purple,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          '$batchCount ${modalLocalizations.translate('batches')}',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .purple,
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isAlreadyAdded)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                modalLocalizations.translate(
                                                  'already_added',
                                                ),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${modalLocalizations.translate('unit_label')} ${product.unit}',
                                            style: TextStyle(
                                              color: isAlreadyAdded
                                                  ? Colors.grey
                                                  : Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '${modalLocalizations.translate('qty_label')} $totalQuantity',
                                            style: TextStyle(
                                              color: isAlreadyAdded
                                                  ? Colors.grey
                                                  : Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${modalLocalizations.translate('buying_label')} ${modalLocalizations.translate('currency_symbol')}${product.buyingPrice.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: isAlreadyAdded
                                                  ? Colors.grey
                                                  : Colors.red[400],
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            '${modalLocalizations.translate('selling_label')} ${modalLocalizations.translate('currency_symbol')}${product.sellingPrice.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: isAlreadyAdded
                                                  ? Colors.grey
                                                  : Colors.green[400],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
    // Request permission to access contacts
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

    // Fetch contacts
    List<Contact> contacts = [];
    try {
      contacts = await FastContacts.getAllContacts();
      print('Fetched ${contacts.length} contacts');
    } catch (e) {
      print('Error fetching contacts: $e');
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final modalLocalizations = AppLocalizations.of(context)!;
            return Column(
              children: [
                // Title and close button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        modalLocalizations.translate('select_from_contacts'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 50,
                    child: TextField(
                      controller: searchController,
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
                                        (phone) =>
                                            SearchUtils.matchesSubsequence(
                                              phone.number,
                                              query,
                                            ),
                                      ),
                                )
                                .toList();
                          }
                        });
                      },
                      decoration: InputDecoration(
                        hintText: modalLocalizations.translate(
                          'search_contacts',
                        ),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Contacts list
                Expanded(
                  child: displayContacts.isEmpty
                      ? Center(
                          child: Text(
                            modalLocalizations.translate('no_contacts_found'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: displayContacts.length,
                          itemBuilder: (context, index) {
                            final contact = displayContacts[index];
                            final phoneNumber = contact.phones.isNotEmpty
                                ? contact.phones.first.number
                                : modalLocalizations.translate('no_phone');

                            // Clean phone number - remove all non-digit characters
                            final cleanedPhoneNumber = phoneNumber.replaceAll(
                              RegExp(r'[^\d]'),
                              '',
                            );

                            // Extract last 10 digits for Indian mobile numbers
                            final validPhoneNumber =
                                cleanedPhoneNumber.length >= 10
                                ? cleanedPhoneNumber.substring(
                                    cleanedPhoneNumber.length - 10,
                                  )
                                : cleanedPhoneNumber;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 6.0,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1.5,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  try {
                                    // Check if we have a valid phone number
                                    if (contact.phones.isEmpty ||
                                        phoneNumber == 'No phone') {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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

                                    // Check if cleaned phone number has at least 10 digits
                                    if (validPhoneNumber.length == 10) {
                                      setState(() {
                                        _customerNameController.text =
                                            contact.displayName;
                                        _customerMobileController.text =
                                            validPhoneNumber;
                                      });
                                      Navigator.pop(context);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            modalLocalizations
                                                .translate(
                                                  'invalid_phone_number',
                                                )
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
                                    print('Error selecting contact: $e');
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
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.blue[600],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              contact.displayName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              cleanedPhoneNumber,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    validPhoneNumber.length ==
                                                        10
                                                    ? Colors.green[600]
                                                    : Colors.red[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
