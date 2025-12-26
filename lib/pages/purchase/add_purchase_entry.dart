import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:flashbill/pages/purchase/add_purchase_review.dart';

class AddPurchaseEntry extends StatefulWidget {
  const AddPurchaseEntry({super.key});

  @override
  State<AddPurchaseEntry> createState() => _AddPurchaseEntryState();
}

class BoughtItem {
  final String productName;
  final String supplierName;
  final String supplierId;
  final String unit;
  String? expiryDate;
  final int minLimit;
  int initialQuantity; // Original quantity bought (for purchase history)
  int quantity; // Current quantity (decreases as items are sold)
  int buyingPrice;
  int sellingPrice;

  BoughtItem({
    required this.productName,
    required this.supplierName,
    required this.supplierId,
    required this.unit,
    this.expiryDate,
    required this.minLimit,
    required this.initialQuantity,
    required this.quantity,
    required this.buyingPrice,
    this.sellingPrice = 0,
  });

  int get total => quantity * buyingPrice;
}

class _AddPurchaseEntryState extends State<AddPurchaseEntry> {
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _supplierDetails =
      []; // Store full supplier details
  List<Map<String, dynamic>> _allUnits = []; // Store all units
  List<BoughtItem> _boughtItems = [];
  late TextEditingController _searchController;
  late TextEditingController _dateController;
  late TextEditingController _supplierNameController;
  late TextEditingController _productController;
  late TextEditingController _unitController;
  late TextEditingController _expiryDateController;
  late TextEditingController _quantityController;
  late TextEditingController _buyingPriceController;
  late TextEditingController _sellingPriceController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _productsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _supplierSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _unitsSubscription;
  String _supplierNameError = '';
  String _selectedSupplierId = '';
  int _totalBoughtAmount = 0;

  late TextEditingController _minLimitController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );
    _supplierNameController = TextEditingController();
    _productController = TextEditingController();
    _unitController = TextEditingController();
    _expiryDateController = TextEditingController();
    _quantityController = TextEditingController();
    _buyingPriceController = TextEditingController();
    _sellingPriceController = TextEditingController();
    _minLimitController = TextEditingController();
    _loadProductNames();
    _loadSupplierDetails();
    _loadUnits();
  }

  void _loadProductNames() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _productsSubscription = FirebaseFirestore.instance
          .collection('product-names')
          .doc(user.uid)
          .collection('items')
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              final products = snapshot.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      'name': doc.data()['name'] ?? 'Unknown',
                    },
                  )
                  .toList();
              setState(() {
                _allProducts = products;
              });
            }
          });
    }
  }

  void _loadUnits() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _unitsSubscription = FirebaseFirestore.instance
          .collection('units')
          .doc(user.uid)
          .collection('items')
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              final units = snapshot.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      'name': doc.data()['name'] ?? 'Unknown',
                    },
                  )
                  .toList();
              setState(() {
                _allUnits = units;
              });
            }
          });
    }
  }

  void _loadSupplierDetails() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _supplierSubscription = FirebaseFirestore.instance
          .collection('suppliers')
          .doc(user.uid)
          .collection('items')
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              final suppliers = snapshot.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      'name': doc.data()['name'] ?? 'Unknown',
                      'contact': doc.data()['contact'] ?? '',
                      'location': doc.data()['location'] ?? '',
                    },
                  )
                  .toList();
              setState(() {
                _supplierDetails = suppliers;
              });
            }
          });
    }
  }

  void _calculateTotalBoughtAmount() {
    _totalBoughtAmount = _boughtItems.fold(0, (sum, item) => sum + item.total);
  }

  void _showEditBoughtItemDialog(BoughtItem item, Color primaryTextColor) {
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );
    final priceController = TextEditingController(
      text: item.buyingPrice.toString(),
    );
    final sellingPriceController = TextEditingController(
      text: item.sellingPrice.toString(),
    );
    final expiryDateController = TextEditingController(
      text: item.expiryDate ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Edit ${item.productName}',
            style: TextStyle(color: primaryTextColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Details (Read-only)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(color: Colors.blue, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Details',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unit: ${item.unit}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Supplier: ${item.supplierName}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Initial Quantity (Bought): ${item.initialQuantity}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                        ),
                      ),
                      if (item.expiryDate != null &&
                          item.expiryDate!.isNotEmpty)
                        Text(
                          'Expiry Date: ${item.expiryDate}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Current Quantity (Available)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Buying Price (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sellingPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Selling Price (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expiryDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Expiry Date (Optional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate:
                          item.expiryDate != null && item.expiryDate!.isNotEmpty
                          ? DateFormat('dd/MM/yyyy').parse(item.expiryDate!)
                          : DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      expiryDateController.text = DateFormat(
                        'dd/MM/yyyy',
                      ).format(pickedDate);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text) ?? 0;
                final price = int.tryParse(priceController.text) ?? 0;
                final sellingPrice =
                    int.tryParse(sellingPriceController.text) ?? 0;

                if (quantity > 0 && price > 0 && sellingPrice > 0) {
                  setState(() {
                    item.quantity = quantity;
                    item.buyingPrice = price;
                    item.sellingPrice = sellingPrice;
                    item.expiryDate = expiryDateController.text.isNotEmpty
                        ? expiryDateController.text
                        : null;
                    _calculateTotalBoughtAmount();
                  });
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid values')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _addProductToList() {
    // Validate all fields
    if (_supplierNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a supplier')));
      return;
    }

    if (_productController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a product')));
      return;
    }

    if (_unitController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a unit')));
      return;
    }

    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter quantity')));
      return;
    }

    if (_buyingPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter buying price')),
      );
      return;
    }

    if (_sellingPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter selling price')),
      );
      return;
    }

    // Parse values
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final buyingPrice = int.tryParse(_buyingPriceController.text) ?? 0;
    final sellingPrice = int.tryParse(_sellingPriceController.text) ?? 0;

    if (quantity <= 0 || buyingPrice <= 0 || sellingPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid values')),
      );
      return;
    }

    // Check if product already exists
    final productExists = _boughtItems.any(
      (item) => item.productName == _productController.text,
    );

    if (productExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is already added')),
      );
      return;
    }

    // Get minLimit from the input field
    final minLimit = int.tryParse(_minLimitController.text) ?? 0;

    // Create and add new bought item
    final newItem = BoughtItem(
      productName: _productController.text,
      supplierName: _supplierNameController.text,
      supplierId: _selectedSupplierId,
      unit: _unitController.text,
      expiryDate: _expiryDateController.text.isNotEmpty
          ? _expiryDateController.text
          : null,
      minLimit: minLimit,
      initialQuantity: quantity,
      quantity: quantity,
      buyingPrice: buyingPrice,
      sellingPrice: sellingPrice,
    );

    setState(() {
      _boughtItems.add(newItem);
      _calculateTotalBoughtAmount();
    });

    // Clear the fields
    _productController.clear();
    _unitController.clear();
    _expiryDateController.clear();
    _quantityController.clear();
    _buyingPriceController.clear();
    _sellingPriceController.clear();
    _minLimitController.clear();
  }

  void _removeBoughtItem(int index) {
    setState(() {
      _boughtItems.removeAt(index);
      _calculateTotalBoughtAmount();
    });
  }

  void _showSelectionSheet(
    String title,
    List<Map<String, dynamic>> items,
    TextEditingController controller,
  ) {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Use the live list from state (_allProducts or _allUnits) instead of the parameter
          // This ensures the modal always shows the latest items from Firestore listener
          List<Map<String, dynamic>> liveItems = title == 'Products'
              ? _allProducts
              : _allUnits;

          // Get current filtered items based on search and current items list
          List<Map<String, dynamic>> filteredItems = liveItems.where((item) {
            final itemName = item['productName'] ?? item['name'] ?? '';
            return itemName.toString().toLowerCase().contains(
              searchController.text.toLowerCase(),
            );
          }).toList();

          return DraggableScrollableSheet(
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
                      Text(
                        'Select $title',
                        style: const TextStyle(
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
                // Search bar and Add button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextField(
                            controller: searchController,
                            onChanged: (query) {
                              setModalState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: 'Search $title',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (title == 'Products' || title == 'Units')
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (title == 'Products') {
                                  _showAddProductNameDialog(
                                    context,
                                    setModalState,
                                  );
                                } else if (title == 'Units') {
                                  _showAddUnitDialog(context, setModalState);
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Items list
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(child: Text('No $title found'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return ListTile(
                              title: Text(
                                item['productName'] ?? item['name'] ?? '',
                              ),
                              onTap: () {
                                controller.text =
                                    item['productName'] ?? item['name'] ?? '';
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddProductNameDialog(
    BuildContext context,
    StateSetter setModalState,
  ) {
    final productNameController = TextEditingController();
    String productNameError = '';
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add New Product Name',
                style: TextStyle(color: primaryTextColor),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: productNameController,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (value) {
                        // Convert to uppercase in real-time
                        if (value != value.toUpperCase()) {
                          productNameController.text = value.toUpperCase();
                          productNameController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: value.toUpperCase().length),
                          );
                        }
                        setDialogState(() {
                          productNameError = value.trim().isEmpty
                              ? 'Product name required'
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        hintText: 'Enter Product Name',
                        errorText: productNameError.isNotEmpty
                            ? productNameError
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
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
                  onPressed:
                      (productNameError.isEmpty &&
                          productNameController.text.trim().isNotEmpty)
                      ? () async {
                          var productName = productNameController.text.trim();

                          // Capitalize first letter
                          productName = productName.isNotEmpty
                              ? productName[0].toUpperCase() +
                                    productName.substring(1)
                              : productName;

                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final productsRef = FirebaseFirestore.instance
                                  .collection('product-names')
                                  .doc(user.uid)
                                  .collection('items');

                              final newProduct = {'name': productName};

                              await productsRef.add(newProduct);

                              // Don't manually add - let the Firestore listener handle it
                              // This prevents duplicates when the listener fires

                              // Small delay to allow listener to update, then refresh modal
                              await Future.delayed(
                                const Duration(milliseconds: 200),
                              );

                              setModalState(() {
                                // This will trigger a rebuild of the modal sheet with updated items
                              });

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Product "$productName" added successfully',
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add',
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

  void _showAddUnitDialog(BuildContext context, StateSetter setModalState) {
    final unitNameController = TextEditingController();
    String unitNameError = '';
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add New Unit',
                style: TextStyle(color: primaryTextColor),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: unitNameController,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (value) {
                        // Convert to uppercase in real-time
                        if (value != value.toUpperCase()) {
                          unitNameController.text = value.toUpperCase();
                          unitNameController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: value.toUpperCase().length),
                          );
                        }
                        setDialogState(() {
                          unitNameError = value.trim().isEmpty
                              ? 'Unit name required'
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Unit Name',
                        hintText: 'Enter Unit Name',
                        errorText: unitNameError.isNotEmpty
                            ? unitNameError
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
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
                  onPressed:
                      (unitNameError.isEmpty &&
                          unitNameController.text.trim().isNotEmpty)
                      ? () async {
                          final unitName = unitNameController.text.trim();

                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final unitsRef = FirebaseFirestore.instance
                                  .collection('units')
                                  .doc(user.uid)
                                  .collection('items');

                              final newUnit = {'name': unitName};

                              await unitsRef.add(newUnit);

                              // Don't manually add - let the Firestore listener handle it
                              // This prevents duplicates when the listener fires

                              // Small delay to allow listener to update, then refresh modal
                              await Future.delayed(
                                const Duration(milliseconds: 200),
                              );

                              setModalState(() {
                                // This will trigger a rebuild of the modal sheet with updated items
                              });

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Unit "$unitName" added successfully',
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add',
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

  void _showSupplierSelectionDrawer(BuildContext context) {
    final searchController = TextEditingController();

    // Load suppliers fresh when drawer opens
    final user = FirebaseAuth.instance.currentUser;
    List<Map<String, dynamic>> displaySuppliers = [];

    if (user != null) {
      final suppliersRef = FirebaseFirestore.instance
          .collection('suppliers')
          .doc(user.uid)
          .collection('items');
      suppliersRef.get().then((snapshot) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          displaySuppliers.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'contact': data['contact'] ?? '',
            'location': data['location'] ?? '',
          });
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Load suppliers when drawer is built
          if (user != null && displaySuppliers.isEmpty) {
            final suppliersRef = FirebaseFirestore.instance
                .collection('suppliers')
                .doc(user.uid)
                .collection('items');
            suppliersRef.get().then((snapshot) {
              final suppliers = snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['name'] ?? 'Unknown',
                  'contact': data['contact'] ?? '',
                  'location': data['location'] ?? '',
                };
              }).toList();
              setModalState(() {
                displaySuppliers = suppliers;
              });
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
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
                        'Select Supplier',
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
                // Search field and Add button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextField(
                            controller: searchController,
                            onChanged: (query) {
                              setModalState(() {
                                if (query.isEmpty) {
                                  // Reload all suppliers
                                  if (user != null) {
                                    final suppliersRef = FirebaseFirestore
                                        .instance
                                        .collection('suppliers')
                                        .doc(user.uid)
                                        .collection('items');
                                    suppliersRef.get().then((snapshot) {
                                      displaySuppliers = snapshot.docs.map((
                                        doc,
                                      ) {
                                        final data = doc.data();
                                        return {
                                          'id': doc.id,
                                          'name': data['name'] ?? 'Unknown',
                                          'contact': data['contact'] ?? '',
                                          'location': data['location'] ?? '',
                                        };
                                      }).toList();
                                      setModalState(() {});
                                    });
                                  }
                                } else {
                                  displaySuppliers = _supplierDetails
                                      .where(
                                        (supplier) =>
                                            supplier['name']
                                                .toString()
                                                .toLowerCase()
                                                .contains(
                                                  query.toLowerCase(),
                                                ) ||
                                            supplier['contact']
                                                .toString()
                                                .toLowerCase()
                                                .contains(query.toLowerCase()),
                                      )
                                      .toList();
                                }
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search supplier...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Add Supplier Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showAddSupplierDialog(
                              context,
                              setModalState,
                              displaySuppliers,
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Suppliers list with full details
                Expanded(
                  child: displaySuppliers.isEmpty
                      ? Center(
                          child: Text(
                            'No suppliers found',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: displaySuppliers.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final supplier = displaySuppliers[index];
                            final name = supplier['name'] ?? 'Unknown';
                            final contact = supplier['contact'] ?? '';
                            final location = supplier['location'] ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Contact: $contact',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Location: $location',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                onTap: () {
                                  setState(() {
                                    _supplierNameController.text = name;
                                    _selectedSupplierId = supplier['id'] ?? '';
                                  });
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddSupplierDialog(
    BuildContext context,
    StateSetter setModalState,
    List<Map<String, dynamic>> displaySuppliers,
  ) {
    final newSupplierController = TextEditingController();
    final contactController = TextEditingController();
    final locationController = TextEditingController();
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;

    String nameError = '';
    String contactError = '';
    String locationError = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add New Supplier',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: newSupplierController,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (value) {
                        // Convert to uppercase in real-time
                        if (value != value.toUpperCase()) {
                          newSupplierController.text = value.toUpperCase();
                          newSupplierController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: value.toUpperCase().length),
                          );
                        }
                        setDialogState(() {
                          nameError = value.trim().isEmpty
                              ? 'Supplier name required'
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Supplier Name',
                        hintText: 'Enter Supplier Name',
                        errorText: nameError.isNotEmpty ? nameError : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contactController,
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value.trim().isEmpty) {
                            contactError = 'Contact number required';
                          } else if (value.trim().length < 10) {
                            contactError = 'Contact must be at least 10 digits';
                          } else {
                            contactError = '';
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Contact Number',
                        hintText: 'Enter Contact Number',
                        errorText: contactError.isNotEmpty
                            ? contactError
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (value) {
                        // Convert to uppercase in real-time
                        if (value != value.toUpperCase()) {
                          locationController.text = value.toUpperCase();
                          locationController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: value.toUpperCase().length),
                          );
                        }
                        setDialogState(() {
                          locationError = value.trim().isEmpty
                              ? 'Location required'
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: 'Enter Location',
                        errorText: locationError.isNotEmpty
                            ? locationError
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
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
                  onPressed:
                      (nameError.isEmpty &&
                          contactError.isEmpty &&
                          locationError.isEmpty &&
                          newSupplierController.text.trim().isNotEmpty &&
                          contactController.text.trim().isNotEmpty &&
                          locationController.text.trim().isNotEmpty)
                      ? () async {
                          var supplierName = newSupplierController.text.trim();
                          final contact = contactController.text.trim();
                          var location = locationController.text.trim();

                          // Capitalize first letter
                          supplierName = supplierName.isNotEmpty
                              ? supplierName[0].toUpperCase() +
                                    supplierName.substring(1)
                              : supplierName;
                          location = location.isNotEmpty
                              ? location[0].toUpperCase() +
                                    location.substring(1)
                              : location;

                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final suppliersRef = FirebaseFirestore.instance
                                  .collection('suppliers')
                                  .doc(user.uid)
                                  .collection('items');

                              // Check if supplier already exists
                              final existingSupplier = _supplierDetails
                                  .firstWhere(
                                    (s) =>
                                        s['name'].toString().toLowerCase() ==
                                        supplierName.toLowerCase(),
                                    orElse: () => {},
                                  );

                              if (existingSupplier.isEmpty) {
                                final newSupplier = {
                                  'name': supplierName,
                                  'contact': contact,
                                  'location': location,
                                };

                                await suppliersRef.add(newSupplier);

                                // Update local list
                                setState(() {
                                  _supplierDetails.add({
                                    'id': '',
                                    'name': supplierName,
                                    'contact': contact,
                                    'location': location,
                                  });
                                });

                                // Update the parent drawer state only (not dialog state)
                                setModalState(() {
                                  displaySuppliers.add({
                                    'id': '',
                                    'name': supplierName,
                                    'contact': contact,
                                    'location': location,
                                  });
                                });

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Supplier "$supplierName" added successfully',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Supplier already exists'),
                                    ),
                                  );
                                }
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add',
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

  Future<void> _saveBoughtEntry() async {
    // Validate form
    if (_supplierNameController.text.isEmpty) {
      setState(() {
        _supplierNameError = 'Supplier name is required';
      });
      return;
    }

    if (_boughtItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      final purchasesCol = firestore
          .collection('purchases')
          .doc(user.uid)
          .collection('items');
      final productsCol = firestore
          .collection('purchased-products')
          .doc(user.uid)
          .collection('items');

      // Calculate total products and total units
      int totalProducts = _boughtItems.length;
      int totalUnits = 0;
      for (var item in _boughtItems) {
        totalUnits += item.quantity;
      }

      // First, save the purchase entry to get its ID
      final purchaseEntry = {
        'date': _dateController.text,
        'supplierName': _supplierNameController.text,
        'totalAmount': _totalBoughtAmount,
        'totalProducts': totalProducts,
        'totalUnits': totalUnits,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final purchaseDoc = await purchasesCol.add(purchaseEntry);
      final purchaseId = purchaseDoc.id;

      // Then, save all purchased items with the purchase reference ID
      for (var item in _boughtItems) {
        // Generate unique batch ID based on product name + supplier name + buying price
        final batchHash = md5
            .convert(
              utf8.encode(
                '${item.productName}_${item.supplierName}_${item.buyingPrice}',
              ),
            )
            .toString()
            .substring(0, 8);
        final batchId = '${item.productName}_${item.supplierId}_$batchHash';

        // Check if product already exists in stock (qty > 0)
        // Get all existing batches for this product
        final existingSnapshot = await productsCol.get();
        int existingTotalQty = 0;
        int existingMinLimit = 0;
        String? existingMinLimitBatchId;

        for (var doc in existingSnapshot.docs) {
          final product = doc.data();
          if (product['productName'] == item.productName) {
            existingTotalQty += ((product['quantity'] ?? 0) as num).toInt();
            // Find the batch that holds the minLimit (minLimit > 0)
            final batchMinLimit = ((product['minLimit'] ?? 0) as num).toInt();
            if (batchMinLimit > 0 && existingMinLimitBatchId == null) {
              existingMinLimit = batchMinLimit;
              existingMinLimitBatchId = doc.id;
            }
          }
        }

        // Determine the minLimit for this new batch
        int batchMinLimit;
        if (existingTotalQty == 0) {
          // Product not in stock, this batch will store the minLimit
          batchMinLimit = item.minLimit;
        } else {
          // Product already in stock, new batch gets 0, we'll update the existing batch
          batchMinLimit = 0;
        }

        final productEntry = {
          'purchaseId': purchaseId,
          'productName': item.productName,
          'supplierId': item.supplierId,
          'supplierName': item.supplierName,
          'unit': item.unit,
          'expiryDate': item.expiryDate ?? '',
          'minLimit': batchMinLimit,
          'initialQuantity': item.initialQuantity,
          'quantity': item.quantity,
          'buyingPrice': item.buyingPrice,
          'sellingPrice': item.sellingPrice,
          'total': item.total,
          'date': _dateController.text,
          'timestamp': DateTime.now().toIso8601String(),
          'batchId': batchId,
          'purchaseDate': _dateController.text,
          'profitMargin': (item.sellingPrice - item.buyingPrice).toDouble(),
        };

        // Save to purchased-products and capture the generated product ID
        final productDoc = await productsCol.add(productEntry);
        final productId = productDoc.id; // Get the unique product ID

        // Also save to permanent purchase history using productId (not productName)
        // This ensures history is not affected if product name changes in future
        final historyCol = firestore
            .collection('product-purchase-history')
            .doc(user.uid)
            .collection('items');
        final historyEntry = {
          'purchaseId': purchaseId,
          'productId': productId, // Store the unique product ID
          'productName': item.productName,
          'supplierId': item.supplierId,
          'supplierName': item.supplierName,
          'unit': item.unit,
          'expiryDate': item.expiryDate ?? '',
          'quantity': item.initialQuantity,
          'buyingPrice': item.buyingPrice,
          'sellingPrice': item.sellingPrice,
          'total': item.total,
          'date': _dateController.text,
          'timestamp': DateTime.now().toIso8601String(),
          'batchId': batchId,
        };
        await historyCol.add(historyEntry);

        // If product already exists and we need to update minLimit
        if (existingTotalQty > 0 && existingMinLimitBatchId != null) {
          // Update the existing batch that holds the minLimit
          final updatedMinLimit = existingMinLimit + item.minLimit;
          await productsCol.doc(existingMinLimitBatchId).update({
            'minLimit': updatedMinLimit,
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bought entry saved successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error saving bought entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showReviewScreen() {
    final reviewItems = _boughtItems
        .map(
          (item) => BoughtItemReview(
            productName: item.productName,
            unit: item.unit,
            expiryDate: item.expiryDate,
            quantity: item.quantity,
            buyingPrice: item.buyingPrice,
            sellingPrice: item.sellingPrice,
          ),
        )
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddPurchaseReview(
          date: _dateController.text,
          supplierName: _supplierNameController.text,
          items: reviewItems,
          totalAmount: _totalBoughtAmount,
          onConfirm: _saveBoughtEntry,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateController.dispose();
    _supplierNameController.dispose();
    _productController.dispose();
    _unitController.dispose();
    _expiryDateController.dispose();
    _quantityController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    _productsSubscription?.cancel();
    _supplierSubscription?.cancel();
    _unitsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bought Entry')),
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
                buildFormField(
                  'Select Supplier',
                  _supplierNameController,
                  onTap: () => _showSupplierSelectionDrawer(context),
                  suffixIcon: Icons.arrow_drop_down,
                  enabled: false,
                ),
                if (_supplierNameError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _supplierNameError,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                // Info message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(color: Colors.blue, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'If you are buying more than one product from this supplier, you can add all products one by one here',
                          style: TextStyle(color: Colors.blue, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Product Name Field
                buildFormField(
                  'Select Product Name',
                  _productController,
                  suffixIcon: Icons.arrow_drop_down,
                  onTap: () => _showSelectionSheet(
                    'Products',
                    _allProducts,
                    _productController,
                  ),
                  enabled: false,
                ),
                // Unit Field
                buildFormField(
                  'Select product unit',
                  _unitController,
                  suffixIcon: Icons.arrow_drop_down,
                  onTap: () =>
                      _showSelectionSheet('Units', _allUnits, _unitController),
                  enabled: false,
                ),
                // Expiry Date Field
                buildFormField(
                  'Expiry Date (Optional)',
                  _expiryDateController,
                  suffixIcon: Icons.calendar_today_outlined,
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      _expiryDateController.text = DateFormat(
                        'dd/MM/yyyy',
                      ).format(pickedDate);
                    }
                  },
                  enabled: false,
                ),
                // Quantity Field
                Row(
                  children: [
                    Expanded(
                      child: buildFormField(
                        'Product Quantity',
                        _quantityController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: buildFormField(
                        'Min. QTY',
                        _minLimitController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                // Buying Price Field
                Row(
                  children: [
                    Expanded(
                      child: buildFormField(
                        'Buying Price Per Item',
                        _buyingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: buildFormField(
                        'Selling Price Per Item',
                        _sellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Products',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(
                      height: 25,
                      child: ElevatedButton.icon(
                        onPressed: _addProductToList,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text(
                          'Add Product',
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
                _boughtItems.isEmpty
                    ? const Text('No products added yet')
                    : SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _boughtItems.length,
                          itemBuilder: (context, index) {
                            final item = _boughtItems[index];
                            return InkWell(
                              onTap: () => _showEditBoughtItemDialog(
                                item,
                                primaryTextColor!,
                              ),
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
                                        Text(
                                          item.productName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: primaryTextColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          children: [
                                            const Text(
                                              'Qty:',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.quantity.toStringAsFixed(0),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // horizontal line
                                            Container(
                                              width: 10,
                                              height: 1,
                                              color: Colors.grey,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                            ),
                                            Text(
                                              '₹${item.buyingPrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              'Total: ₹${item.total.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              onPressed: () =>
                                                  _removeBoughtItem(index),
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
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹ $_totalBoughtAmount',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
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
                          onPressed: _boughtItems.isEmpty
                              ? null
                              : () {
                                  if (_supplierNameController.text.isEmpty) {
                                    setState(() {
                                      _supplierNameError =
                                          'Supplier name is required';
                                    });
                                    return;
                                  }
                                  _showReviewScreen();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save & Review',
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
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildFormField(
    String hint,
    TextEditingController controller, {
    IconData? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Function()? onTap,
    Function(String)? onChanged,
    bool enabled = true,
  }) {
    bool fontSizeSmall =
        hint == 'Buying Price Per Item' || hint == 'Selling Price Per Item';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final isDarkMode =
                  Theme.of(context).brightness == Brightness.dark;
              return GestureDetector(
                onTap: !enabled && onTap != null ? onTap : null,
                child: Card(
                  child: TextFormField(
                    enabled: enabled,
                    onTap: enabled ? onTap : null,
                    onChanged: onChanged,
                    controller: controller,
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                        fontSize: fontSizeSmall ? 12 : 14,
                      ),
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: maxLines > 1 ? 16.0 : 16.0,
                        horizontal: 16.0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: suffixIcon != null
                          ? Icon(
                              suffixIcon,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.grey[800],
                            )
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
