import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/billing/bill_success_page.dart';
import 'package:flashbill/pages/billing/review_billing_details.dart';
import 'package:flashbill/ui%20helpers/ui_helper.dart';
import 'package:fast_contacts/fast_contacts.dart';
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
  int billPrice;

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
  List<BillItem> _billItems = [];
  bool _productsLoading = true;
  List<Map<String, dynamic>> _customers = [];
  bool _customersLoading = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _customersSubscription;
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
    _loadProducts();
    _loadCustomers();

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
                quantity: (product['quantity'] ?? 0) as int,
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
              maxQuantity: matchingProduct.quantity,
              billQuantity: (product['quantity'] ?? 0).toDouble(),
              billPrice: (product['price'] ?? 0) as int,
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
    _productsSubscription?.cancel();
    _customersSubscription?.cancel();
    super.dispose();
  }

  String? _validateCustomerName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Customer name is required';
    }
    return null;
  }

  String? _validateMobileNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Mobile number is optional
    }
    final cleanedValue = value.trim();
    if (!RegExp(r'^[0-9]{10}$').hasMatch(cleanedValue)) {
      return 'Mobile number must be 10 digits';
    }
    return null;
  }

  String? _validateVehicleNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Vehicle number is optional
    }
    final cleanedValue = value.trim();
    // Indian vehicle number format: 2 letters, 2 digits, 2 letters, 4 digits (flexible)
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z]{2}[0-9]{4}$').hasMatch(cleanedValue)) {
      return 'Invalid vehicle number format (e.g., KA01AB1234)';
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

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(widget.isEditMode ? 'Edit Bill' : 'Create new bill'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                buildFormField(
                  'Select Date',
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
                    'Select Customer From',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryTextColor,
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
                        label: const Text(
                          'Contacts',
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
                        label: const Text(
                          'Existing',
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
                      'Customer Full Name *',
                      _customerNameController,
                      onChanged: (value) {
                        setState(() {
                          _customerNameError =
                              _validateCustomerName(value) ?? '';
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
                      'Customer Mobile Number',
                      _customerMobileController,
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        setState(() {
                          _customerMobileError =
                              _validateMobileNumber(value) ?? '';
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

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildFormField(
                      'Customer Vehicle Number',
                      _customerVehicleController,
                      keyboardType: TextInputType.text,
                      onChanged: (value) {
                        // Convert to uppercase
                        if (value != value.toUpperCase()) {
                          _customerVehicleController.text = value.toUpperCase();
                          _customerVehicleController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: value.toUpperCase().length),
                          );
                        }
                        setState(() {
                          _customerVehicleError =
                              _validateVehicleNumber(
                                _customerVehicleController.text,
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
                              ? 'Add Product'
                              : 'Add More Products',
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
                    const Text(
                      'Products Added for Billing:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_billItems.isEmpty) const SizedBox(height: 12),
                    if (_billItems.isEmpty)
                      Center(
                        child: Text(
                          'No products added for billing',
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
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryTextColor,
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
                                              'Qty:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: primaryTextColor,
                                              ),
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
                                          '₹${billItem.billPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Total: ₹${billItem.total.toStringAsFixed(2)}',
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
                      'Total Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_getTotalQuantity()} items',
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
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${_getTotalAmount().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                      'Total amount paid?',
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
                      'Payment Method',
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
                                      'Cash',
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
                                      'Online',
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
                        'Enter paid amount',
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
                        'Amount Remaining',
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
                            prefix: const Text('₹ '),
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
                        'Next Payment Date',
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
                              hintText: 'Select date',
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
                            child: const Text(
                              'Cancel',
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
                                  ) ??
                                  '';
                              _customerMobileError =
                                  _validateMobileNumber(
                                    _customerMobileController.text,
                                  ) ??
                                  '';
                              _customerVehicleError =
                                  _validateVehicleNumber(
                                    _customerVehicleController.text,
                                  ) ??
                                  '';
                            });

                            // Check if there are any errors
                            if (_customerNameError.isNotEmpty ||
                                _customerMobileError.isNotEmpty ||
                                _customerVehicleError.isNotEmpty) {
                              return;
                            }

                            // Check if products are added
                            if (_billItems.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please add products for billing',
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
                                  const SnackBar(
                                    content: Text('Failed to add customer'),
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
                                  _nextPaymentDateError =
                                      'Next payment date is required';
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
                          child: const Text(
                            'Process billing',
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
        return AlertDialog(
          title: const Text('Remove Product'),
          content: const Text(
            'Are you sure you want to remove this product from the bill?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No'),
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
              child: const Text('Yes'),
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

  double _getTotalAmount() {
    return _billItems.fold(0, (sum, item) => sum + item.total);
  }

  int _getTotalQuantity() {
    return _billItems.fold(0, (sum, item) => sum + item.billQuantity.toInt());
  }

  bool _isProductAlreadyAdded(String productName) {
    return _billItems.any((item) => item.productName == productName);
  }

  void _addProductToBill(BoughtProduct product) {
    setState(() {
      _billItems.add(
        BillItem(
          productName: product.productName,
          supplierName: product.supplierName,
          unit: product.unit,
          buyingPrice: product.buyingPrice,
          sellingPrice: product.sellingPrice,
          maxQuantity: product.quantity,
          billQuantity: 1,
          billPrice: product.sellingPrice.toInt(),
          batchId: product.batchId,
          profitMargin: product.profitMargin,
        ),
      );
    });
  }

  void _showBatchSelectionDialog(
    BuildContext context,
    String productName,
    List<BoughtProduct> batches,
  ) {
    // Filter batches to show only those with quantity > 0
    final availableBatches = batches.where((b) => b.quantity > 0).toList();

    // If no batches available, show message
    if (availableBatches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No batches available for this product')),
      );
      return;
    }

    // Sort batches by purchase date (oldest first - FIFO)
    availableBatches.sort((a, b) {
      DateTime dateA = DateTime.tryParse(a.purchaseDate) ?? DateTime.now();
      DateTime dateB = DateTime.tryParse(b.purchaseDate) ?? DateTime.now();
      return dateA.compareTo(dateB);
    });

    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Select Batch: $productName',
            style: TextStyle(color: primaryTextColor),
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
                      ? 'Batch ${index + 1} ${isFifo ? '(FIFO - Oldest)' : ''}'
                      : '';
                  final isBatchAlreadyAdded = _billItems.any(
                    (item) => item.batchId == batch.batchId,
                  );

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
                                    : secondaryTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Buy: ₹${batch.buyingPrice.toStringAsFixed(2)} | Sell: ₹${batch.sellingPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Available: ${batch.quantity} ${batch.unit}${batch.quantity != 1 ? 's' : ''}',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                          if (batch.profitMargin > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Profit/unit: ₹${batch.profitMargin.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.purple[400],
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: isBatchAlreadyAdded
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Added',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      onTap: isBatchAlreadyAdded
                          ? null
                          : () {
                              _addProductToBill(batch);
                              Navigator.pop(dialogContext);
                              Navigator.pop(context);
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
              child: Text('Cancel', style: TextStyle(color: primaryTextColor)),
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
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    String quantityError = '';
    String priceError = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Edit Product',
                style: TextStyle(color: primaryTextColor),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      billItem.productName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
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
                          const Text(
                            'Bought Price',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹ ${billItem.buyingPrice.toStringAsFixed(2)}',
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
                          'Quantity',
                          style: TextStyle(color: primaryTextColor),
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
                            decimal: false,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Selling Price',
                            prefixText: '₹ ',
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final quantity =
                        double.tryParse(quantityController.text) ?? 0;
                    final price = double.tryParse(priceController.text) ?? 0;
                    String qtyErr = '';
                    String priceErr = '';

                    if (quantity <= 0) {
                      qtyErr = 'Quantity must be greater than 0';
                    } else if (quantity > billItem.maxQuantity) {
                      qtyErr =
                          'Quantity cannot exceed ${billItem.maxQuantity} (available)';
                    }

                    if (price <= 0) {
                      priceErr = 'Price must be greater than 0';
                    }

                    if (qtyErr.isNotEmpty || priceErr.isNotEmpty) {
                      setDialogState(() {
                        quantityError = qtyErr;
                        priceError = priceErr;
                      });
                    } else {
                      setState(() {
                        _billItems[index].billQuantity = quantity;
                        _billItems[index].billPrice = price.toInt();
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text(
                    'Save',
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
          builder: (context, scrollController) => Column(
            children: [
              // Title and close button
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Customer',
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
                          displayCustomers = _customers;
                        } else {
                          displayCustomers = _customers
                              .where(
                                (customer) =>
                                    customer['name'].toLowerCase().contains(
                                      query.toLowerCase(),
                                    ) ||
                                    customer['mobileNumber'].contains(query),
                              )
                              .toList();
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search customer...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Customers list
              Expanded(
                child: _customersLoading
                    ? const Center(child: CircularProgressIndicator())
                    : displayCustomers.isEmpty
                    ? Center(
                        child: Text(
                          'No customers found',
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
                                  vertical: 12.0,
                                  horizontal: 16.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Mobile: ${customer['mobileNumber']}',
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
                                            'Vehicle: ${customer['vehicleNumber']}',
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
          ),
        ),
      ),
    );
  }

  void showAvailableProductsDrawer(BuildContext context) {
    final searchController = TextEditingController();
    // Group products by name and show total quantity across all batches
    Map<String, Map<String, dynamic>> uniqueProducts = {};
    for (var product in _availableProducts) {
      if (!uniqueProducts.containsKey(product.productName)) {
        uniqueProducts[product.productName] = {
          'product': product,
          'totalQuantity': product.quantity,
          'batchCount': 1,
        };
      } else {
        // Add quantity from additional batches
        uniqueProducts[product.productName]!['totalQuantity'] +=
            product.quantity;
        uniqueProducts[product.productName]!['batchCount'] += 1;
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
          builder: (context, scrollController) => Column(
            children: [
              // Title and close button
              Container(
                padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Product',
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
                            if (!uniqueFilteredProducts.containsKey(
                              product.productName,
                            )) {
                              uniqueFilteredProducts[product.productName] = {
                                'product': product,
                                'totalQuantity': product.quantity,
                                'batchCount': 1,
                              };
                            } else {
                              uniqueFilteredProducts[product
                                      .productName]!['totalQuantity'] +=
                                  product.quantity;
                              uniqueFilteredProducts[product
                                      .productName]!['batchCount'] +=
                                  1;
                            }
                          }
                          displayProducts = uniqueFilteredProducts.values
                              .toList();
                        } else {
                          // Filter and show unique products with total quantities
                          Map<String, Map<String, dynamic>>
                          uniqueFilteredProducts = {};
                          for (var product in _availableProducts) {
                            if ((product.productName.toLowerCase().contains(
                                  query.toLowerCase(),
                                ) ||
                                product.supplierName.toLowerCase().contains(
                                  query.toLowerCase(),
                                ))) {
                              if (!uniqueFilteredProducts.containsKey(
                                product.productName,
                              )) {
                                uniqueFilteredProducts[product.productName] = {
                                  'product': product,
                                  'totalQuantity': product.quantity,
                                  'batchCount': 1,
                                };
                              } else {
                                uniqueFilteredProducts[product
                                        .productName]!['totalQuantity'] +=
                                    product.quantity;
                                uniqueFilteredProducts[product
                                        .productName]!['batchCount'] +=
                                    1;
                              }
                            }
                          }
                          displayProducts = uniqueFilteredProducts.values
                              .toList();
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search products or supplier...',
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
                          'Single batch products add directly. Multi-batch products show batch options. Same batch cannot be added twice.',
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
                          'No products found',
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
                              productData['totalQuantity'] as int;
                          final batchCount = productData['batchCount'] as int;
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
                              onTap: () {
                                // Get all batches for this product from original list
                                final productBatches = _availableProducts
                                    .where(
                                      (p) =>
                                          p.productName == product.productName,
                                    )
                                    .toList();

                                if (productBatches.length == 1) {
                                  // Only one batch, add directly (but check if batch already added)
                                  final batch = productBatches.first;
                                  final isBatchAlreadyAdded = _billItems.any(
                                    (item) => item.batchId == batch.batchId,
                                  );
                                  if (!isBatchAlreadyAdded) {
                                    _addProductToBill(batch);
                                    Navigator.pop(context);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'This batch is already added to the bill',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  // Multiple batches, always show selection dialog
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                                        color: Theme.of(context)
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
                                                            .withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.purple,
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        '$batchCount Batches',
                                                        style: const TextStyle(
                                                          color: Colors.purple,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Already Added',
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
                                          'Unit: ${product.unit}',
                                          style: TextStyle(
                                            color: isAlreadyAdded
                                                ? Colors.grey
                                                : Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium?.color,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Qty: $totalQuantity',
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
                                          'Buying: ₹${product.buyingPrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: isAlreadyAdded
                                                ? Colors.grey
                                                : Colors.red[400],
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          'Selling: ₹${product.sellingPrice.toStringAsFixed(2)}',
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
          ),
        ),
      ),
    );
  }

  Future<void> _showContactsBottomSheet(BuildContext context) async {
    // Request permission to access contacts
    final status = await Permission.contacts.request();

    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Contact permission is required to select from contacts',
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
    } catch (e) {
      print('Error fetching contacts: $e');
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
          builder: (context, scrollController) => Column(
            children: [
              // Title and close button
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select from Contacts',
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
                                    contact.displayName.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ) ||
                                    contact.phones.any(
                                      (phone) => phone.number.contains(query),
                                    ),
                              )
                              .toList();
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search contacts by name or phone...',
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
                          'No contacts found',
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
                              : 'No phone';
                          final cleanedPhoneNumber = phoneNumber.replaceAll(
                            RegExp(r'[^\d]'),
                            '',
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
                                color: Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                // Check if phone number is valid (10 digits)
                                if (cleanedPhoneNumber.length == 10) {
                                  setState(() {
                                    _customerNameController.text =
                                        contact.displayName;
                                    _customerMobileController.text =
                                        cleanedPhoneNumber;
                                  });
                                  Navigator.pop(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Invalid phone number for ${contact.displayName}. Phone must have 10 digits.',
                                      ),
                                      backgroundColor: Colors.orange,
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
                                        borderRadius: BorderRadius.circular(8),
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
                                                  cleanedPhoneNumber.length ==
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
          ),
        ),
      ),
    );
  }
}
