import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flashbill/ui helpers/app_text_styles.dart';

class Product {
  final String id;
  final String name;

  Product({required this.id, required this.name});

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {'name': name};
  }

  // Create from Map
  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(id: id, name: data['name'] ?? '');
  }
}

class ProductName extends StatefulWidget {
  const ProductName({super.key});

  @override
  State<ProductName> createState() => _ProductNameState();
}

class _ProductNameState extends State<ProductName> {
  late CollectionReference _productsRef;
  late String _userId;
  late List<Product> _products;
  late List<Product> _filteredProducts;
  bool _isLoading = true;
  String _searchQuery = '';
  late TextEditingController _searchController;
  StreamSubscription<QuerySnapshot>? _productsSubscription;

  // Controllers for the Add Product Popup
  final TextEditingController _productNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterProducts);
    _getUserAndLoadProducts();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _searchController.dispose();
    _productsSubscription?.cancel();
    super.dispose();
  }

  void _getUserAndLoadProducts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      _productsRef = FirebaseFirestore.instance
          .collection('product-names')
          .doc(_userId)
          .collection('items');
      _loadProductsFromDatabase();
    } else {
      setState(() {
        _isLoading = false;
        _products = [];
        _filteredProducts = [];
      });
    }
  }

  void _loadProductsFromDatabase() {
    _productsSubscription = _productsRef.snapshots().listen((snapshot) {
      // Early return if widget is disposed
      if (!mounted) return;

      final loadedProducts = <Product>[];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        loadedProducts.add(Product.fromMap(doc.id, data));
      }

      // Single setState call with all updates
      if (mounted) {
        setState(() {
          _products = loadedProducts;
          _isLoading = false;
        });
        _filterProducts();
      }
    });
  }

  void _filterProducts() {
    _searchQuery = _searchController.text.toLowerCase();
    if (!mounted) return;
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products
            .where(
              (product) => product.name.toLowerCase().contains(_searchQuery),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Products'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: false,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: ListTile(
                      title: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditProductPopup(product),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteConfirmation(product),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onPressed: _showAddProductPopup,
          backgroundColor: const Color(0xFF2196F3),
          tooltip: 'Add Product Name',
          child: const Icon(Icons.add, color: Colors.white, size: 45),
        ),
      ),
    );
  }

  void _showAddProductPopup() {
    _productNameController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Product Name', style: context.bodyLargeText),
          content: TextField(
            controller: _productNameController,
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) {
              if (value != value.toUpperCase()) {
                _productNameController.text = value.toUpperCase();
                _productNameController.selection = TextSelection.fromPosition(
                  TextPosition(offset: value.toUpperCase().length),
                );
              }
            },
            decoration: const InputDecoration(
              labelText: 'Product Name',
              hintText: 'Enter product name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_productNameController.text.isNotEmpty) {
                  try {
                    await _productsRef.add({
                      'name': _productNameController.text.trim(),
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding product: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditProductPopup(Product product) {
    final nameController = TextEditingController(text: product.name);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Product Name'),
          content: TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) {
              if (value != value.toUpperCase()) {
                nameController.text = value.toUpperCase();
                nameController.selection = TextSelection.fromPosition(
                  TextPosition(offset: value.toUpperCase().length),
                );
              }
            },
            decoration: const InputDecoration(
              labelText: 'Product Name',
              hintText: 'Enter product name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  try {
                    await _productsRef.doc(product.id).update({
                      'name': nameController.text.trim(),
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating product: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text('Are you sure you want to delete ${product.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _productsRef.doc(product.id).delete();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting product: $e')),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
