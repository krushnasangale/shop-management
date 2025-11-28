import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/billing/bill_success_page.dart';
import 'package:flashbill/pages/billing/review_billing_details.dart';
import 'package:flashbill/ui%20helpers/ui_helper.dart';

class CreateNewBill extends StatefulWidget {
  const CreateNewBill({super.key});

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

  factory BoughtProduct.fromMap(String id, Map<dynamic, dynamic> data) {
    return BoughtProduct(
      id: id,
      date: data['date'] ?? '',
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

class BillItem {
  final String productName;
  final String supplierName;
  final String unit;
  final double buyingPrice;
  final double sellingPrice;
  final int maxQuantity;
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
  });

  double get total => billQuantity * billPrice;
}

class _CreateNewBillState extends State<CreateNewBill> {
  bool totalAmountPaid = true;
  String paymentMethod = 'cash'; // 'cash' or 'online'
  late DatabaseReference _boughtProductsRef;
  late String _userId;
  List<BoughtProduct> _availableProducts = [];
  List<BillItem> _billItems = [];
  bool _productsLoading = true;
  List<Map<String, dynamic>> _customers = [];
  bool _customersLoading = true;
  StreamSubscription<DatabaseEvent>? _customersSubscription;
  late TextEditingController _searchController;
  late TextEditingController _dateController;
  late TextEditingController _customerNameController;
  late TextEditingController _customerMobileController;
  late TextEditingController _customerVehicleController;
  StreamSubscription<DatabaseEvent>? _productsSubscription;
  String _customerNameError = '';
  String _customerMobileError = '';
  String _customerVehicleError = '';
  late TextEditingController _amountPaidController;
  late TextEditingController _amountRemainingController;

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
    _loadProducts();
    _loadCustomers();
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
      return 'Mobile number is required';
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
      _boughtProductsRef = FirebaseDatabase.instance.ref(
        'purchased-products/$_userId',
      );
      _productsSubscription = _boughtProductsRef.onValue.listen((
        DatabaseEvent event,
      ) {
        if (!mounted) return;

        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        final loadedProducts = <BoughtProduct>[];

        if (data != null) {
          for (var entry in data.entries) {
            loadedProducts.add(
              BoughtProduct.fromMap(
                entry.key as String,
                entry.value as Map<dynamic, dynamic>,
              ),
            );
          }
        }

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

    final database = FirebaseDatabase.instance;
    final customersRef = database.ref('customers/${user.uid}');

    _customersSubscription = customersRef.onValue.listen((event) {
      if (!mounted) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final customers = data.entries.map((e) {
          return {
            'id': e.key,
            'name': e.value['name'] ?? '',
            'mobileNumber': e.value['mobileNumber'] ?? '',
            'vehicleNumber': e.value['vehicleNumber'] ?? '',
          };
        }).toList();
        setState(() {
          _customers = customers;
          _customersLoading = false;
        });
      } else {
        setState(() {
          _customers = [];
          _customersLoading = false;
        });
      }
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
        title: const Text('Create new bill'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                buildFormField(
                  'Date',
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

                // Select Customer section
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 25,
                      child: ElevatedButton.icon(
                        onPressed: () => _showCustomersDrawer(context),
                        icon: const Icon(Icons.person_add, color: Colors.white),
                        label: const Text(
                          'Select existing Customer',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildFormField(
                      'Customer Name',
                      'Enter Customer Name',
                      _customerNameController,
                      onChanged: (value) {
                        setState(() {
                          _customerNameError = _validateCustomerName(value) ?? '';
                        });
                      },
                    ),
                    if (_customerNameError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 16),
                        child: Text(
                          _customerNameError,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildFormField(
                      'Customer Mobile Number',
                      'Enter Mobile Number',
                      _customerMobileController,
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        setState(() {
                          _customerMobileError = _validateMobileNumber(value) ?? '';
                        });
                      },
                    ),
                    if (_customerMobileError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 16),
                        child: Text(
                          _customerMobileError,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildFormField(
                      'Customer Vehicle Number',
                      'Enter Vehicle Number',
                      _customerVehicleController,
                      keyboardType: TextInputType.text,
                      onChanged: (value) {
                        // Convert to uppercase
                        if (value != value.toUpperCase()) {
                          _customerVehicleController.text = value.toUpperCase();
                          _customerVehicleController.selection = TextSelection.fromPosition(
                            TextPosition(offset: value.toUpperCase().length),
                          );
                        }
                        setState(() {
                          _customerVehicleError = _validateVehicleNumber(_customerVehicleController.text) ?? '';
                        });
                      },
                    ),
                    if (_customerVehicleError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 16),
                        child: Text(
                          _customerVehicleError,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
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
                          _billItems.isEmpty ? 'Add Product' : 'Add More Products',
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
                                padding: const EdgeInsets.symmetric(vertical: 8),
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
                                padding: const EdgeInsets.symmetric(vertical: 8),
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

                if (!totalAmountPaid)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildFormField(
                        'Amount Paid',
                        'Enter paid amount',
                        _amountPaidController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            // Auto-calculate remaining amount
                            final totalAmount = _getTotalAmount().toInt();
                            final amountPaid = int.tryParse(value) ?? 0;
                            final remaining = totalAmount - amountPaid;
                            _amountRemainingController.text = remaining.toString();
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                              _customerNameError = _validateCustomerName(_customerNameController.text) ?? '';
                              _customerMobileError = _validateMobileNumber(_customerMobileController.text) ?? '';
                              _customerVehicleError = _validateVehicleNumber(_customerVehicleController.text) ?? '';
                            });
                
                            // Check if there are any errors
                            if (_customerNameError.isNotEmpty || _customerMobileError.isNotEmpty || _customerVehicleError.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fix the errors in the form'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                
                            // Check if products are added
                            if (_billItems.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please add products for billing'),
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
                              );
                            }).toList();
                
                            final totalBillAmount = _getTotalAmount().toInt();
                            final amountPaidValue = totalAmountPaid ? totalBillAmount : (int.tryParse(_amountPaidController.text) ?? 0);
                            final amountRemainingValue = totalBillAmount - amountPaidValue;
                
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

      final database = FirebaseDatabase.instance;
      final customerData = {
        'name': _customerNameController.text.trim(),
        'mobileNumber': _customerMobileController.text.trim(),
        'vehicleNumber': _customerVehicleController.text.trim(),
        'createdAt': DateTime.now().toString(),
      };

      await database.ref('customers/${user.uid}').push().set(customerData);
      
      // Get the key of the newly added customer
      final snapshot = await database
          .ref('customers/${user.uid}')
          .orderByChild('createdAt')
          .limitToLast(1)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final customerId = data.keys.first as String;
        return customerId;
      }
      return null;
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
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textAlign: TextAlign.center,
                              onChanged: (value) {
                                setDialogState(() {
                                  // Validate input
                                  final quantity = double.tryParse(value) ?? 0;
                                  if (quantity > billItem.maxQuantity) {
                                    quantityController.text = billItem.maxQuantity.toStringAsFixed(0);
                                    quantityController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: quantityController.text.length),
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
                                    color: Theme.of(context)
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${customer['name']} selected',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                      horizontal: 16.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customer['name'],
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
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
    List<BoughtProduct> displayProducts = _availableProducts;

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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 50,
                  child: TextField(
                    controller: searchController,
                    onChanged: (query) {
                      setModalState(() {
                        if (query.isEmpty) {
                          displayProducts = _availableProducts;
                        } else {
                          displayProducts = _availableProducts
                              .where(
                                (product) =>
                                    product.productName.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ) ||
                                    product.supplierName.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ),
                              )
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
              const SizedBox(height: 16),
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
                          final product = displayProducts[index];
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
                                color: isAlreadyAdded
                                    ? Colors.orange
                                    : (Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withOpacity(0.1) ??
                                          Colors.grey),
                                width: 1.5,
                              ),
                            ),
                            child: InkWell(
                              onTap: isAlreadyAdded
                                  ? null
                                  : () {
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
                                          ),
                                        );
                                      });
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${product.productName} added to bill',
                                          ),
                                        ),
                                      );
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 16.0,
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
                                              Text(
                                                product.productName[0]
                                                        .toUpperCase() +
                                                    product.productName
                                                        .substring(1),
                                                style: TextStyle(
                                                  color: isAlreadyAdded
                                                      ? Colors.grey
                                                      : Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.color,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
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
                                    const SizedBox(height: 8),
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
                                          'Qty: ${product.quantity}',
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
}
