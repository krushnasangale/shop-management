import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:nkt/pages/purchase/add_purchase_review.dart';

class AddPurchaseEntry extends StatefulWidget {
  const AddPurchaseEntry({super.key});

  @override
  State<AddPurchaseEntry> createState() => _AddPurchaseEntryState();
}

class BoughtItem {
  final String productName;
  final String supplierName;
  final String unit;
  final int minLimit;
  int initialQuantity; // Original quantity bought (for purchase history)
  int quantity; // Current quantity (decreases as items are sold)
  int buyingPrice;
  int sellingPrice;

  BoughtItem({
    required this.productName,
    required this.supplierName,
    required this.unit,
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
  late TextEditingController _quantityController;
  late TextEditingController _buyingPriceController;
  late TextEditingController _sellingPriceController;
  StreamSubscription<DatabaseEvent>? _productsSubscription;
  StreamSubscription<DatabaseEvent>? _supplierSubscription;
  StreamSubscription<DatabaseEvent>? _unitsSubscription;
  String _supplierNameError = '';
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
      final productNamesRef = FirebaseDatabase.instance.ref(
        'product-names/${user.uid}/items',
      );
      _productsSubscription = productNamesRef.onValue.listen((event) {
        if (mounted) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data != null) {
            final products = data.entries.map((e) {
              return {'id': e.key, 'name': e.value['name'] ?? 'Unknown'};
            }).toList();
            setState(() {
              _allProducts = products;
            });
          } else {
            setState(() {
              _allProducts = [];
            });
          }
        }
      });
    }
  }

  void _loadUnits() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final unitsRef = FirebaseDatabase.instance.ref('units/${user.uid}/items');
      _unitsSubscription = unitsRef.onValue.listen((event) {
        if (mounted) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data != null) {
            final units = data.entries.map((e) {
              return {
                'id': e.key,
                'name': e.value['name'] ?? 'Unknown',
              };
            }).toList();
            setState(() {
              _allUnits = units;
            });
          } else {
            setState(() {
              _allUnits = [];
            });
          }
        }
      });
    }
  }

  void _loadSupplierDetails() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final suppliersRef = FirebaseDatabase.instance.ref(
        'suppliers/${user.uid}/items',
      );
      _supplierSubscription = suppliersRef.onValue.listen((event) {
        if (mounted) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data != null) {
            final suppliers = data.entries.map((e) {
              return {
                'id': e.key,
                'name': e.value['name'] ?? 'Unknown',
                'contact': e.value['contact'] ?? '',
                'location': e.value['location'] ?? '',
              };
            }).toList();
            setState(() {
              _supplierDetails = suppliers;
            });
          } else {
            setState(() {
              _supplierDetails = [];
            });
          }
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
      unit: _unitController.text,
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
          // Get current filtered items based on search and current items list
          List<Map<String, dynamic>> filteredItems = items.where((item) {
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
                      onChanged: (value) {
                        setDialogState(() {
                          productNameError = value.trim().isEmpty
                              ? 'Product name required'
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        hintText: 'Enter product name',
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
                              final productsRef = FirebaseDatabase.instance.ref(
                                'product-names/${user.uid}/items',
                              );

                              final newProduct = {'name': productName};

                              await productsRef.push().set(newProduct);

                              // Update local list
                              setState(() {
                                _allProducts.add({
                                  'id': '',
                                  'name': productName,
                                });
                              });

                              // Refresh modal state to show updated list
                              setModalState(() {});

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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Unit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: unitNameController,
                      onChanged: (value) {
                        setDialogState(() {
                          unitNameError = value.trim().isEmpty
                              ? 'Unit name required'
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Unit Name',
                        hintText: 'Enter unit name',
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
                              final unitsRef = FirebaseDatabase.instance.ref(
                                'units/${user.uid}/items',
                              );

                              final newUnit = {'name': unitName};

                              await unitsRef.push().set(newUnit);

                              // Update local list
                              setState(() {
                                _allUnits.add({'id': '', 'name': unitName});
                              });

                              // Refresh modal state to show updated list
                              setModalState(() {});

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
      final suppliersRef = FirebaseDatabase.instance.ref(
        'suppliers/${user.uid}/items',
      );
      suppliersRef.get().then((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          final suppliers = data.entries.map((e) {
            return {
              'id': e.key,
              'name': e.value['name'] ?? 'Unknown',
              'contact': e.value['contact'] ?? '',
              'location': e.value['location'] ?? '',
            };
          }).toList();
          displaySuppliers = suppliers;
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
            final suppliersRef = FirebaseDatabase.instance.ref(
              'suppliers/${user.uid}/items',
            );
            suppliersRef.get().then((snapshot) {
              if (snapshot.exists) {
                final data = snapshot.value as Map<dynamic, dynamic>;
                final suppliers = data.entries.map((e) {
                  return {
                    'id': e.key,
                    'name': e.value['name'] ?? 'Unknown',
                    'contact': e.value['contact'] ?? '',
                    'location': e.value['location'] ?? '',
                  };
                }).toList();
                setModalState(() {
                  displaySuppliers = suppliers;
                });
              }
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
                                    final suppliersRef = FirebaseDatabase
                                        .instance
                                        .ref('suppliers/${user.uid}/items');
                                    suppliersRef.get().then((snapshot) {
                                      if (snapshot.exists) {
                                        final data =
                                            snapshot.value
                                                as Map<dynamic, dynamic>;
                                        displaySuppliers = data.entries.map((
                                          e,
                                        ) {
                                          return {
                                            'id': e.key,
                                            'name':
                                                e.value['name'] ?? 'Unknown',
                                            'contact': e.value['contact'] ?? '',
                                            'location':
                                                e.value['location'] ?? '',
                                          };
                                        }).toList();
                                        setModalState(() {});
                                      }
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
                      onChanged: (value) {
                        setDialogState(() {
                          nameError = value.trim().isEmpty
                              ? 'Supplier name required'
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Supplier Name',
                        hintText: 'Enter supplier name',
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
                        hintText: 'Enter contact number',
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
                      onChanged: (value) {
                        setDialogState(() {
                          locationError = value.trim().isEmpty
                              ? 'Location required'
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: 'Enter location',
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
                              final suppliersRef = FirebaseDatabase.instance
                                  .ref('suppliers/${user.uid}/items');

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

                                await suppliersRef.push().set(newSupplier);

                                // Update local list
                                setState(() {
                                  _supplierDetails.add({
                                    'id': '',
                                    'name': supplierName,
                                    'contact': contact,
                                    'location': location,
                                  });
                                });

                                // Update modal display
                                setDialogState(() {
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

  void _saveBoughtEntry() async {
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

      final database = FirebaseDatabase.instance;
      final purchasesRef = database.ref('purchases/${user.uid}');
      final productsRef = database.ref('purchased-products/${user.uid}');

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

      final newPurchaseRef = purchasesRef.push();
      await newPurchaseRef.set(purchaseEntry);
      final purchaseId = newPurchaseRef.key!;

      // Then, save all purchased items with the purchase reference ID
      for (var item in _boughtItems) {
        final productEntry = {
          'purchaseId': purchaseId,
          'productName': item.productName,
          'supplierName': item.supplierName,
          'unit': item.unit,
          'minLimit': item.minLimit,
          'initialQuantity': item.initialQuantity,
          'quantity': item.quantity,
          'buyingPrice': item.buyingPrice,
          'sellingPrice': item.sellingPrice,
          'total': item.total,
          'timestamp': DateTime.now().toIso8601String(),
        };
        await productsRef.push().set(productEntry);
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
                              fontSize: 16,
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
                              fontSize: 18,
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
