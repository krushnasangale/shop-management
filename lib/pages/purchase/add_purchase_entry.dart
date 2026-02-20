import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:flashbill/pages/purchase/add_purchase_review.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flashbill/services/image_upload_service.dart';

class AddPurchaseEntry extends StatefulWidget {
  final String? purchaseId;
  final Map<String, dynamic>? existingEntry;

  const AddPurchaseEntry({super.key, this.purchaseId, this.existingEntry});

  @override
  State<AddPurchaseEntry> createState() => _AddPurchaseEntryState();
}

class BoughtItem {
  final String productName;
  final String supplierName;
  final String supplierId;
  String unit;
  String? expiryDate;
  int minLimit;
  int initialQuantity; // Original quantity bought (for purchase history)
  int quantity; // Current quantity (decreases as items are sold)
  double buyingPrice;
  double sellingPrice;
  String? imageUrl;
  int? order; // Order field to maintain sequence

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
    this.imageUrl,
    this.order,
  });

  double get total => quantity * buyingPrice;
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
  double _totalBoughtAmount = 0.0;
  bool _expiryDateEnabled = false; // App setting for expiry date field
  bool _isFromScannedInvoice = false; // Track if this is from scanned invoice

  late TextEditingController _minLimitController;
  late ScrollController _selectedProductsScrollController;
  String? _selectedProductImageUrl;
  final ProfileService _profileService = ProfileService();
  StreamSubscription? _profileServiceSubscription;

  AppLocalizations get appLocalizations => AppLocalizations.of(context)!;

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
    _selectedProductsScrollController = ScrollController();
    _loadProductNames();
    _loadSupplierDetails();
    _loadUnits();
    _loadAppSettings();

    // Load existing data if editing or from scanned invoice
    if (widget.existingEntry != null) {
      _loadExistingPurchaseData();
    }
  }

  Future<void> _loadExistingPurchaseData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Set basic entry info
      setState(() {
        _dateController.text = widget.existingEntry!['date'] ?? '';
        _supplierNameController.text =
            widget.existingEntry!['supplierName'] ?? '';
      });

      List<BoughtItem> loadedItems = [];

      // Check if this is a scanned invoice (has products array) or existing purchase (needs Firebase load)
      if (widget.existingEntry!.containsKey('products') &&
          widget.existingEntry!['products'] != null) {
        // Scanned invoice data - just load items, don't auto-create yet (for performance)
        final products = widget.existingEntry!['products'] as List<dynamic>;
        final supplierName = widget.existingEntry!['supplierName'] ?? '';

        // Mark this as from scanned invoice
        _isFromScannedInvoice = true;

        // Create BoughtItem list (supplier ID will be set when saving)
        for (var i = 0; i < products.length; i++) {
          final product = products[i];
          final productMap = product as Map<String, dynamic>;
          loadedItems.add(
            BoughtItem(
              productName: productMap['name'] ?? '',
              supplierName: supplierName,
              supplierId: '', // Will be set when saving
              unit: productMap['unit'] ?? 'Pcs',
              expiryDate: null,
              minLimit: 0,
              initialQuantity: (productMap['quantity'] ?? 1) as int,
              quantity: (productMap['quantity'] ?? 1) as int,
              buyingPrice: (productMap['price'] ?? 0).toDouble(),
              sellingPrice: 0.0, // User will set this
              order: i,
            ),
          );
        }
      } else if (widget.purchaseId != null) {
        // Existing purchase - load from Firebase
        final itemsSnapshot = await FirebaseFirestore.instance
            .collection('purchased-products')
            .doc(user.uid)
            .collection('items')
            .where('purchaseId', isEqualTo: widget.purchaseId)
            .get();

        for (var doc in itemsSnapshot.docs) {
          final data = doc.data();
          loadedItems.add(
            BoughtItem(
              productName: data['productName'] ?? '',
              supplierName: data['supplierName'] ?? '',
              supplierId: data['supplierId'] ?? '',
              unit: data['unit'] ?? '',
              expiryDate: data['expiryDate'],
              minLimit: (data['minLimit'] ?? 0) as int,
              initialQuantity: (data['initialQuantity'] ?? 0) as int,
              quantity: (data['quantity'] ?? 0) as int,
              buyingPrice: (data['buyingPrice'] ?? 0) as double,
              sellingPrice: (data['sellingPrice'] ?? 0) as double,
              imageUrl: data['imageUrl'],
              order: (data['order'] as num?)?.toInt(),
            ),
          );
          _selectedSupplierId = data['supplierId'] ?? '';
        }

        // Sort by order field in memory
        loadedItems.sort((a, b) {
          final orderA = a.order ?? 999999;
          final orderB = b.order ?? 999999;
          return orderA.compareTo(orderB);
        });
      }

      setState(() {
        _boughtItems = loadedItems;
        _calculateTotalBoughtAmount();
      });
    } catch (e) {
      print('Error loading existing purchase data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading purchase data: $e')),
        );
      }
    }
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
                      'imageUrl': doc.data()['imageUrl'],
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

  Future<void> _loadAppSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Initialize ProfileService if not already initialized
      _profileService.initialize(user.uid);

      // Listen to app settings stream for real-time updates
      _profileServiceSubscription = _profileService.appSettingsStream.listen((
        appSettings,
      ) {
        if (mounted) {
          setState(() {
            _expiryDateEnabled = appSettings['expiryDateEnabled'] ?? false;
          });
        }
      });

      // Also try to get current settings immediately in case stream hasn't emitted yet
      final profileData = await _profileService.getCurrentUserProfile();
      if (profileData != null && mounted) {
        final appSettings =
            profileData['appSettings'] as Map<String, dynamic>? ?? {};
        setState(() {
          _expiryDateEnabled = appSettings['expiryDateEnabled'] ?? false;
        });
      }
    } catch (e) {
      print('Error loading app settings: $e');
      // Default to false if error
      if (mounted) {
        setState(() {
          _expiryDateEnabled = false;
        });
      }
    }
  }

  /// Auto-handle scanned supplier: check if exists, if not create it
  Future<String> _handleScannedSupplier(String supplierName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return '';

      // Check if supplier already exists (case-insensitive)
      final existingSupplier = _supplierDetails.firstWhere(
        (s) =>
            s['name'].toString().toLowerCase() ==
            supplierName.trim().toLowerCase(),
        orElse: () => {},
      );

      if (existingSupplier.isNotEmpty) {
        // Supplier exists, return the ID
        print('✅ Supplier exists: ${existingSupplier['name']}');
        return existingSupplier['id'] ?? '';
      }

      // Supplier doesn't exist, create it
      print('🆕 Creating new supplier: $supplierName');
      final suppliersRef = FirebaseFirestore.instance
          .collection('suppliers')
          .doc(user.uid)
          .collection('items');

      final newSupplier = {
        'name': supplierName.trim(),
        'contact': '', // Default empty - user can update later
        'location': '', // Default empty - user can update later
      };

      final docRef = await suppliersRef.add(newSupplier);

      // Update local list
      setState(() {
        _supplierDetails.add({
          'id': docRef.id,
          'name': supplierName.trim(),
          'contact': '',
          'location': '',
        });
      });

      print('✅ Supplier created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error handling scanned supplier: $e');
      return '';
    }
  }

  /// Auto-handle scanned products: check if exists, if not create them
  Future<void> _handleScannedProducts(List<String> productNames) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final productsRef = FirebaseFirestore.instance
          .collection('product-names')
          .doc(user.uid)
          .collection('items');

      for (final productName in productNames) {
        if (productName.trim().isEmpty) continue;

        // Check if product already exists (case-insensitive)
        final existingProduct = _allProducts.firstWhere(
          (p) =>
              p['name'].toString().toLowerCase() ==
              productName.trim().toLowerCase(),
          orElse: () => {},
        );

        if (existingProduct.isEmpty) {
          // Product doesn't exist, create it
          print('🆕 Creating new product: $productName');

          final newProduct = {
            'name': productName.trim(),
            'imageUrl': null, // No image for auto-created products
          };

          final docRef = await productsRef.add(newProduct);

          // Update local list
          setState(() {
            _allProducts.add({
              'id': docRef.id,
              'name': productName.trim(),
              'imageUrl': null,
            });
          });

          print('✅ Product created with ID: ${docRef.id}');
        } else {
          print('✅ Product exists: ${existingProduct['name']}');
        }
      }
    } catch (e) {
      print('❌ Error handling scanned products: $e');
    }
  }

  /// Auto-handle scanned units: check if exists, if not create them
  Future<void> _handleScannedUnits(List<String> unitNames) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final unitsRef = FirebaseFirestore.instance
          .collection('units')
          .doc(user.uid)
          .collection('items');

      for (final unitName in unitNames) {
        if (unitName.trim().isEmpty) continue;

        // Check if unit already exists (case-insensitive)
        final existingUnit = _allUnits.firstWhere(
          (u) =>
              u['name'].toString().toLowerCase() ==
              unitName.trim().toLowerCase(),
          orElse: () => {},
        );

        if (existingUnit.isEmpty) {
          // Unit doesn't exist, create it
          print('🆕 Creating new unit: $unitName');

          final newUnit = {'name': unitName.trim()};

          final docRef = await unitsRef.add(newUnit);

          // Update local list
          setState(() {
            _allUnits.add({'id': docRef.id, 'name': unitName.trim()});
          });

          print('✅ Unit created with ID: ${docRef.id}');
        } else {
          print('✅ Unit exists: ${existingUnit['name']}');
        }
      }
    } catch (e) {
      print('❌ Error handling scanned units: $e');
    }
  }

  void _calculateTotalBoughtAmount() {
    _totalBoughtAmount = _boughtItems.fold(
      0.0,
      (sum, item) => sum + item.total,
    );
  }

  Future<void> _showImageSourceDialog(
    Function(ImageSource) onSourceSelected,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose Image Source', style: context.bodyLargeText),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera),
              title: Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                onSourceSelected(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                onSourceSelected(ImageSource.gallery);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectImage(Function(File?) onImageSelected) async {
    await _showImageSourceDialog((source) async {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        onImageSelected(File(image.path));
      } else {
        onImageSelected(null);
      }
    });
  }

  void _showEditBoughtItemDialog(BoughtItem item) {
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );
    final priceController = TextEditingController(
      text: item.buyingPrice.toString(),
    );
    final sellingPriceController = TextEditingController(
      text: item.sellingPrice.toString(),
    );
    final minLimitController = TextEditingController(
      text: item.minLimit.toString(),
    );
    final unitController = TextEditingController(text: item.unit);
    final expiryDateController = TextEditingController(
      text: item.expiryDate ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '${appLocalizations.edit} ${item.productName}',
            style: context.bodyLargeText,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Details (Read-only)
                Container(
                  padding: const EdgeInsets.all(8),
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
                        appLocalizations.productDetails,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${appLocalizations.supplierLabel}${item.supplierName}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${appLocalizations.initialQuantityBought}${item.initialQuantity}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                        ),
                      ),
                      if (_expiryDateEnabled &&
                          item.expiryDate != null &&
                          item.expiryDate!.isNotEmpty)
                        Text(
                          '${appLocalizations.expiryDateLabel}${item.expiryDate}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                // Unit Selection
                TextField(
                  controller: unitController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: appLocalizations.unit,
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  onTap: () {
                    _showSelectionSheet('Units', _allUnits, unitController);
                  },
                ),
                const SizedBox(height: 12),
                // Current Quantity and Min Stock Limit in one row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: appLocalizations.currentQuantity,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minLimitController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: appLocalizations.minStock,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Buying Price and Selling Price in one row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: appLocalizations.buyingPriceRupees,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: sellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: appLocalizations.sellingPriceRupees,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_expiryDateEnabled)
                  TextField(
                    controller: expiryDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: appLocalizations.expiryDateOptional,
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate:
                            item.expiryDate != null &&
                                item.expiryDate!.isNotEmpty
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
              child: Text(appLocalizations.cancel),
            ),
            TextButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text) ?? 0;
                final price = double.tryParse(priceController.text) ?? 0.0;
                final sellingPrice =
                    double.tryParse(sellingPriceController.text) ?? 0.0;
                final minLimit = int.tryParse(minLimitController.text) ?? 0;

                if (quantity > 0 && price > 0 && sellingPrice > 0) {
                  setState(() {
                    item.quantity = quantity;
                    item.initialQuantity = quantity;
                    item.buyingPrice = price;
                    item.sellingPrice = sellingPrice;
                    item.minLimit = minLimit;
                    item.unit = unitController.text;
                    item.expiryDate =
                        _expiryDateEnabled &&
                            expiryDateController.text.isNotEmpty
                        ? expiryDateController.text
                        : null;
                    _calculateTotalBoughtAmount();
                  });
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appLocalizations.pleaseEnterValidValues),
                    ),
                  );
                }
              },
              child: Text(appLocalizations.save),
            ),
          ],
        );
      },
    );
  }

  void _addProductToList() {
    // Validate all fields
    if (_supplierNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLocalizations.pleaseSelectSupplier)),
      );
      return;
    }

    if (_productController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLocalizations.pleaseSelectProduct)),
      );
      return;
    }

    if (_unitController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLocalizations.pleaseSelectUnit)),
      );
      return;
    }

    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLocalizations.pleaseEnterQuantity)),
      );
      return;
    }

    if (_buyingPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLocalizations.pleaseEnterBuyingPrice)),
      );
      return;
    }

    if (_sellingPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLocalizations.pleaseEnterSellingPrice)),
      );
      return;
    }

    // Parse values
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final buyingPrice = double.tryParse(_buyingPriceController.text) ?? 0.0;
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0.0;

    if (quantity <= 0 || buyingPrice <= 0 || sellingPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLocalizations.pleaseEnterValidValues)),
      );
      return;
    }

    // Check if product already exists
    final productExists = _boughtItems.any(
      (item) => item.productName == _productController.text,
    );

    if (productExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLocalizations.productAlreadyAdded)),
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
      imageUrl: _selectedProductImageUrl,
      order: _boughtItems.length,
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
    _selectedProductImageUrl = null;
  }

  void _removeBoughtItem(int index) {
    final item = _boughtItems[index];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            appLocalizations.removeProduct,
            style: const TextStyle(color: Colors.red),
          ),
          content: Text(
            appLocalizations.confirmRemoveProduct.replaceAll(
              '{productName}',
              item.productName,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(appLocalizations.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _boughtItems.removeAt(index);
                  _calculateTotalBoughtAmount();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      appLocalizations.productRemoved.replaceAll(
                        '{productName}',
                        item.productName,
                      ),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                appLocalizations.delete,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Scroll to the first product with an error
  void _scrollToFirstError() {
    // Use WidgetsBinding to ensure this runs after the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_boughtItems.isEmpty) return;

      // Find the index of the first item with an error
      final errorIndex = _boughtItems.indexWhere(
        (item) => item.sellingPrice <= 0 || item.minLimit <= 0,
      );

      if (errorIndex == -1) return; // No errors found

      // Calculate the offset to scroll to (each item is 180 + 8 padding = 188)
      final itemWidth = 188.0;
      final offset = errorIndex * itemWidth;

      // Animate scroll to the error
      if (_selectedProductsScrollController.hasClients) {
        _selectedProductsScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _showSelectionSheet(
    String title,
    List<Map<String, dynamic>> items,
    TextEditingController controller,
  ) {
    final searchController = TextEditingController();
    final localizations =
        appLocalizations; // Store reference to avoid context shadowing

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
          List<Map<String, dynamic>> filteredItems =
              liveItems.where((item) {
                final itemName = item['productName'] ?? item['name'] ?? '';
                return SearchUtils.matchesSubsequence(
                  itemName.toString(),
                  searchController.text,
                );
              }).toList()..sort((a, b) {
                final aName = (a['productName'] ?? a['name'] ?? '')
                    .toString()
                    .toLowerCase();
                final bName = (b['productName'] ?? b['name'] ?? '')
                    .toString()
                    .toLowerCase();
                return aName.compareTo(bName);
              });

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                // Title and close button
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title == 'Products'
                            ? localizations.selectProductsTitle
                            : localizations.selectUnitsTitle,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                              hintText: title == 'Products'
                                  ? localizations.searchProducts
                                  : localizations.searchUnits,
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
                          padding: const EdgeInsets.only(left: 8),
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
                              label: Text(localizations.add),
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
                const SizedBox(height: 12),
                // Items list
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            title == 'Products'
                                ? localizations.noProductsFound
                                : localizations.noUnitsFoundModal,
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return ListTile(
                              tileColor:
                                  (item['productName'] ?? item['name'] ?? '') ==
                                      controller.text
                                  ? Colors.blue.withOpacity(0.1)
                                  : null,
                              leading: title == 'Products'
                                  ? Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: item['imageUrl'] != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: CachedNetworkImage(
                                                imageUrl: item['imageUrl'],
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                      child: SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(
                                                          Icons.inventory_2,
                                                          color: Colors.grey,
                                                          size: 24,
                                                        ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.inventory_2,
                                              color: Colors.grey,
                                              size: 24,
                                            ),
                                    )
                                  : null,
                              title: Text(
                                item['productName'] ?? item['name'] ?? '',
                              ),
                              trailing:
                                  (item['productName'] ?? item['name'] ?? '') ==
                                      controller.text
                                  ? Icon(Icons.check, color: Colors.blue)
                                  : null,
                              onTap: () {
                                controller.text =
                                    item['productName'] ?? item['name'] ?? '';
                                if (title == 'Products') {
                                  _selectedProductImageUrl = item['imageUrl'];
                                }
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
    File? selectedImage;
    bool isUploading = false;
    double uploadProgress = 0.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                appLocalizations.addProductName,
                style: context.bodyLargeText,
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
                              ? appLocalizations.nameIsRequired
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: appLocalizations.productName,
                        hintText: appLocalizations.enterProductName,
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
                    const SizedBox(height: 12),
                    // Image Selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Image (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            await _selectImage((file) {
                              setDialogState(() {
                                selectedImage = file;
                              });
                            });
                          },
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: selectedImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        size: 40,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to select image',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        if (selectedImage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  selectedImage = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('Remove Image'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                  child: Text(appLocalizations.cancel),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (productNameController.text.isNotEmpty) {
                            setDialogState(() {
                              isUploading = true;
                            });
                            try {
                              // Create product document first to get ID
                              final docRef = await FirebaseFirestore.instance
                                  .collection('product-names')
                                  .doc(FirebaseAuth.instance.currentUser!.uid)
                                  .collection('items')
                                  .add({
                                    'name': productNameController.text.trim(),
                                  });

                              // Upload image if selected
                              String? imageUrl;
                              if (selectedImage != null) {
                                imageUrl =
                                    await ImageUploadService.uploadProductImage(
                                      userId: FirebaseAuth
                                          .instance
                                          .currentUser!
                                          .uid,
                                      productId: docRef.id,
                                      image: selectedImage,
                                      deleteOldImage: false,
                                      onProgress: (progress) {
                                        setDialogState(() {
                                          uploadProgress = progress;
                                        });
                                      },
                                    );
                                if (imageUrl != null) {
                                  await docRef.update({'imageUrl': imageUrl});
                                }
                              }

                              // Small delay to allow Firestore listener to update, then refresh modal
                              await Future.delayed(
                                const Duration(milliseconds: 200),
                              );

                              setModalState(() {});

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              setDialogState(() {
                                isUploading = false;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${appLocalizations.error}: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isUploading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            if (uploadProgress > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${(uploadProgress * 100).round()}%',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        )
                      : Text(appLocalizations.add),
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
              title: Text(
                appLocalizations.addNewUnit,
                style: context.bodyLargeText,
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
                              ? appLocalizations.nameIsRequired
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: appLocalizations.unitNameExample,
                        hintText: appLocalizations.enterUnitName,
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
                  child: Text(appLocalizations.cancel),
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
                                      appLocalizations.unitAddedSuccessfully
                                          .replaceAll('{unitName}', unitName),
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${appLocalizations.error}: $e',
                                  ),
                                ),
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
                  child: Text(
                    appLocalizations.add,
                    style: const TextStyle(color: Colors.white),
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
        displaySuppliers.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
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
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        appLocalizations.selectSupplierTitle,
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
                // Search field and Add button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                            SearchUtils.matchesSubsequence(
                                              supplier['name'].toString(),
                                              query,
                                            ) ||
                                            SearchUtils.matchesSubsequence(
                                              supplier['contact'].toString(),
                                              query,
                                            ),
                                      )
                                      .toList();
                                }
                              });
                            },
                            decoration: InputDecoration(
                              hintText: appLocalizations.searchSupplier,
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
                          label: Text(appLocalizations.add),
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
                const SizedBox(height: 12),
                // Suppliers list with full details
                Expanded(
                  child: displaySuppliers.isEmpty
                      ? Center(
                          child: Text(
                            appLocalizations.noSuppliersFound,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: displaySuppliers.length,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemBuilder: (context, index) {
                            final supplier = displaySuppliers[index];
                            final name = supplier['name'] ?? 'Unknown';
                            final contact = supplier['contact'] ?? '';
                            final location = supplier['location'] ?? '';

                            final isSelected =
                                supplier['id'] == _selectedSupplierId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.shade50
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.blue.shade200,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                    _supplierNameController.text = name;
                                    _selectedSupplierId = supplier['id'] ?? '';
                                  });
                                  Navigator.pop(context);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isSelected
                                            ? Colors.blue.shade100
                                            : Colors.white,
                                        radius: 18,
                                        child: Icon(
                                          Icons.business,
                                          color: isSelected
                                              ? Colors.blue.shade800
                                              : Colors.grey.shade600,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.blue.shade800
                                                    : Theme.of(context)
                                                          .textTheme
                                                          .bodyLarge
                                                          ?.color,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.phone,
                                                  size: 12,
                                                  color: isSelected
                                                      ? Colors.blue.shade600
                                                      : Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.color,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    contact,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isSelected
                                                          ? Colors.blue.shade600
                                                          : Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.color,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.location_on,
                                                  size: 12,
                                                  color: isSelected
                                                      ? Colors.blue.shade600
                                                      : Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.color,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    location,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isSelected
                                                          ? Colors.blue.shade600
                                                          : Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.color,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.blue.shade800,
                                          size: 20,
                                        ),
                                    ],
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
                appLocalizations.addNewSupplier,
                style: context.bodyLargeText?.copyWith(
                  fontWeight: FontWeight.bold,
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
                              ? appLocalizations.supplierNameRequired
                              : '';
                        });
                      },
                      decoration: InputDecoration(
                        labelText: appLocalizations.supplierName,
                        hintText: appLocalizations.enterSupplierName,
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
                            contactError =
                                appLocalizations.contactNumberRequired;
                          } else if (value.trim().length < 10) {
                            contactError =
                                appLocalizations.contactMustBeAtLeast10Digits;
                          } else {
                            contactError = '';
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: appLocalizations.contactNumber,
                        hintText: appLocalizations.enterContactNumber,
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
                  child: Text(appLocalizations.cancel),
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
                                        appLocalizations
                                            .supplierAddedSuccessfully
                                            .replaceAll(
                                              '{supplierName}',
                                              supplierName,
                                            ),
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        appLocalizations.supplierAlreadyExists,
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${appLocalizations.error}: $e',
                                  ),
                                ),
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
                  child: Text(
                    appLocalizations.add,
                    style: const TextStyle(color: Colors.white),
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
        _supplierNameError = appLocalizations.supplierNameRequired;
      });
      return;
    }

    if (_boughtItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLocalizations.pleaseAddAtLeastOneProduct)),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ✨ AUTO-HANDLE scanned invoice data (if applicable)
      if (_isFromScannedInvoice) {
        final supplierName = _supplierNameController.text.trim();

        // Auto-handle supplier
        final supplierId = await _handleScannedSupplier(supplierName);
        _selectedSupplierId = supplierId;

        // Auto-handle products
        final productNames = _boughtItems
            .map((item) => item.productName)
            .toList();
        await _handleScannedProducts(productNames);

        // Auto-handle units
        final unitNames = _boughtItems
            .map((item) => item.unit)
            .toSet()
            .toList();
        await _handleScannedUnits(unitNames);

        // Update all items with the proper supplier ID (recreate items as supplierId is final)
        _boughtItems = _boughtItems.map((item) {
          return BoughtItem(
            productName: item.productName,
            supplierName: item.supplierName,
            supplierId: supplierId, // Update with proper supplier ID
            unit: item.unit,
            expiryDate: item.expiryDate,
            minLimit: item.minLimit,
            initialQuantity: item.initialQuantity,
            quantity: item.quantity,
            buyingPrice: item.buyingPrice,
            sellingPrice: item.sellingPrice,
            imageUrl: item.imageUrl,
            order: item.order,
          );
        }).toList();

        // Show feedback about new supplier (if created)
        final existingSupplier = _supplierDetails.firstWhere(
          (s) => s['id'] == supplierId,
          orElse: () => {},
        );
        if (existingSupplier['contact']?.isEmpty ?? true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                appLocalizations.newSupplierAdded.replaceAll(
                  '{supplierName}',
                  supplierName,
                ),
              ),
              backgroundColor: Colors.green.shade600,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      final firestore = FirebaseFirestore.instance;
      final purchasesCol = firestore
          .collection('purchases')
          .doc(user.uid)
          .collection('items');
      final productsCol = firestore
          .collection('purchased-products')
          .doc(user.uid)
          .collection('items');
      final historyCol = firestore
          .collection('product-purchase-history')
          .doc(user.uid)
          .collection('items');

      // Calculate total products and total units
      int totalProducts = _boughtItems.length;
      int totalUnits = 0;
      for (var item in _boughtItems) {
        totalUnits += item.initialQuantity;
        print(
          'Item: ${item.productName}, initialQuantity: ${item.initialQuantity}',
        );
      }
      print(
        'Calculated totalUnits: $totalUnits, totalProducts: $totalProducts, totalAmount: $_totalBoughtAmount',
      );

      String purchaseId;
      bool isEditMode = widget.purchaseId != null;

      if (isEditMode) {
        // EDIT MODE: Update existing purchase
        purchaseId = widget.purchaseId!;

        // Delete old items from purchased-products
        final oldItems = await productsCol
            .where('purchaseId', isEqualTo: purchaseId)
            .get();
        for (var doc in oldItems.docs) {
          await doc.reference.delete();
        }

        // Delete old items from history
        final oldHistory = await historyCol
            .where('purchaseId', isEqualTo: purchaseId)
            .get();
        for (var doc in oldHistory.docs) {
          await doc.reference.delete();
        }

        // Update purchase entry
        await purchasesCol.doc(purchaseId).update({
          'date': _dateController.text,
          'supplierName': _supplierNameController.text,
          'totalAmount': _totalBoughtAmount,
          'totalProducts': totalProducts,
          'totalUnits': totalUnits,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        // CREATE MODE: Create new purchase
        final purchaseEntry = {
          'date': _dateController.text,
          'supplierName': _supplierNameController.text,
          'totalAmount': _totalBoughtAmount,
          'totalProducts': totalProducts,
          'totalUnits': totalUnits,
          'timestamp': DateTime.now().toIso8601String(),
        };

        final purchaseDoc = await purchasesCol.add(purchaseEntry);
        purchaseId = purchaseDoc.id;
      }

      // Save all items (same for both create and edit)
      for (var i = 0; i < _boughtItems.length; i++) {
        final item = _boughtItems[i];
        final batchHash = md5
            .convert(
              utf8.encode(
                '${item.productName}_${item.supplierName}_${item.buyingPrice}',
              ),
            )
            .toString()
            .substring(0, 8);
        final batchId = '${item.productName}_${item.supplierId}_$batchHash';

        // For new purchases, check if product exists in stock
        int batchMinLimit = item.minLimit;
        if (!isEditMode) {
          final existingSnapshot = await productsCol.get();
          int existingTotalQty = 0;
          int existingMinLimit = 0;
          String? existingMinLimitBatchId;

          for (var doc in existingSnapshot.docs) {
            final product = doc.data();
            if (product['productName'] == item.productName) {
              existingTotalQty += ((product['quantity'] ?? 0) as num).toInt();
              final minLim = ((product['minLimit'] ?? 0) as num).toInt();
              if (minLim > 0 && existingMinLimitBatchId == null) {
                existingMinLimit = minLim;
                existingMinLimitBatchId = doc.id;
              }
            }
          }

          if (existingTotalQty > 0) {
            batchMinLimit = 0;
            if (existingMinLimitBatchId != null) {
              await productsCol.doc(existingMinLimitBatchId).update({
                'minLimit': existingMinLimit + item.minLimit,
              });
            }
          }
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
          'imageUrl': item.imageUrl,
          'order': i,
        };

        final productDoc = await productsCol.add(productEntry);

        final historyEntry = {
          'purchaseId': purchaseId,
          'productId': productDoc.id,
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
          'imageUrl': item.imageUrl,
          'order': i,
        };
        await historyCol.add(historyEntry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode
                  ? appLocalizations.purchaseEntryUpdatedSuccessfully
                  : appLocalizations.purchaseEntrySavedSuccessfully,
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error saving bought entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${appLocalizations.error}: $e')),
        );
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
    _profileServiceSubscription?.cancel();
    _profileService.dispose();
    _selectedProductsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.purchaseId != null;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade600, Colors.blue.shade800],
            ),
          ),
        ),
        title: Text(
          isEditMode
              ? appLocalizations.editPurchaseEntry
              : appLocalizations.addBoughtEntry,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50.withValues(alpha: 0.3), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Purchase Details Card
                  Card(
                    elevation: 4,
                    shadowColor: Colors.blue.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: Colors.blue.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                appLocalizations.purchaseDetails,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          buildModernFormField(
                            appLocalizations.selectDate,
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
                          buildModernFormField(
                            appLocalizations.selectSupplier,
                            _supplierNameController,
                            onTap: () => _showSupplierSelectionDrawer(context),
                            suffixIcon: Icons.arrow_drop_down,
                            readOnly: true,
                            bottomPadding: false,
                          ),
                          if (_supplierNameError.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade600,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _supplierNameError,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Info message with modern styling
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                      ),
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            appLocalizations.purchaseInfoMessage,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Product Details Card
                  Card(
                    elevation: 4,
                    shadowColor: Colors.blue.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                color: Colors.blue.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                appLocalizations.productDetails,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          buildModernFormField(
                            appLocalizations.selectProductName,
                            _productController,
                            suffixIcon: Icons.arrow_drop_down,
                            onTap: () => _showSelectionSheet(
                              'Products',
                              _allProducts,
                              _productController,
                            ),
                            readOnly: true,
                          ),
                          buildModernFormField(
                            appLocalizations.selectProductUnit,
                            _unitController,
                            suffixIcon: Icons.arrow_drop_down,
                            onTap: () => _showSelectionSheet(
                              'Units',
                              _allUnits,
                              _unitController,
                            ),
                            readOnly: true,
                          ),
                          if (_expiryDateEnabled) ...[
                            buildModernFormField(
                              appLocalizations.expiryDateOptional,
                              _expiryDateController,
                              suffixIcon: Icons.calendar_today_outlined,
                              onTap: () async {
                                final DateTime? pickedDate =
                                    await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2101),
                                    );
                                if (pickedDate != null) {
                                  _expiryDateController.text = DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(pickedDate);
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: buildModernFormField(
                                  appLocalizations.productQuantity,
                                  _quantityController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: buildModernFormField(
                                  appLocalizations.minQty,
                                  _minLimitController,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: buildModernFormField(
                                  appLocalizations.buyingPricePerItem,
                                  _buyingPriceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  bottomPadding: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: buildModernFormField(
                                  appLocalizations.sellingPricePerItem,
                                  _sellingPriceController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  bottomPadding: false,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Add Product Button
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade500, Colors.blue.shade700],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _addProductToList,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(
                        appLocalizations.addProduct,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  // Selected Products Section
                  if (_boughtItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      appLocalizations.selectedProducts,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  _boughtItems.isEmpty
                      ? Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.grey.shade400,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    appLocalizations.noProductsAddedYet,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          height: 228,
                          child: ListView.builder(
                            controller: _selectedProductsScrollController,
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: false,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            itemCount: _boughtItems.length,
                            itemBuilder: (context, index) {
                              final item = _boughtItems[index];
                              final hasSellingPriceError =
                                  item.sellingPrice <= 0;
                              final hasMinLimitError = item.minLimit <= 0;
                              final hasAnyError =
                                  hasSellingPriceError || hasMinLimitError;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      height: 185,
                                      width: 180,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.blue.shade50,
                                            Colors.white,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              hasSellingPriceError ||
                                                  hasMinLimitError
                                              ? Colors.red.withOpacity(0.5)
                                              : Colors.blue.withOpacity(0.2),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                hasSellingPriceError ||
                                                    hasMinLimitError
                                                ? Colors.red.withOpacity(0.1)
                                                : Colors.blue.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Index Badge
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.blue.shade600,
                                                    Colors.blue.shade400,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.blue
                                                        .withOpacity(0.3),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '#${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // edit button
                                          Positioned(
                                            top: 8,
                                            left: 50,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () =>
                                                    _showEditBoughtItemDialog(
                                                      item,
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.orange.shade50,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.edit,
                                                    color:
                                                        Colors.orange.shade600,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Delete Button
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () =>
                                                    _removeBoughtItem(index),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.close,
                                                    color: Colors.red.shade600,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Content
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              12,
                                              40,
                                              12,
                                              12,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                // Product Image
                                                if (item.imageUrl != null)
                                                  SizedBox(
                                                    width: double.infinity,
                                                    height: 60,
                                                    child: CachedNetworkImage(
                                                      imageUrl: item.imageUrl!,
                                                      fit: BoxFit.cover,
                                                      placeholder:
                                                          (
                                                            context,
                                                            url,
                                                          ) => Container(
                                                            color: Colors
                                                                .grey[200],
                                                            child: const Center(
                                                              child:
                                                                  CircularProgressIndicator(),
                                                            ),
                                                          ),
                                                      errorWidget:
                                                          (
                                                            context,
                                                            url,
                                                            error,
                                                          ) => Container(
                                                            color: Colors
                                                                .grey[200],
                                                            child: const Icon(
                                                              Icons
                                                                  .image_not_supported,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 4),
                                                // Product Name
                                                Text(
                                                  item.productName,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                // Quantity and Price Row
                                                Row(
                                                  children: [
                                                    // Quantity Badge
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.blue.shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .blue
                                                              .shade200,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .inventory_2_outlined,
                                                            size: 14,
                                                            color: Colors
                                                                .blue
                                                                .shade700,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            item.quantity
                                                                .toStringAsFixed(
                                                                  0,
                                                                ),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .blue
                                                                  .shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Price
                                                    Expanded(
                                                      child: Text(
                                                        '₹${item.buyingPrice.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors
                                                              .grey
                                                              .shade700,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                // Total Amount
                                                Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.blue.shade600,
                                                        Colors.blue.shade500,
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '₹${item.total.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Error messages section with fixed height
                                    SizedBox(
                                      height: 39,
                                      child: hasAnyError
                                          ? Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                                left: 2,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (hasSellingPriceError)
                                                    Text(
                                                      'Selling price is 0',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  if (hasSellingPriceError &&
                                                      hasMinLimitError)
                                                    const SizedBox(height: 2),
                                                  if (hasMinLimitError)
                                                    Text(
                                                      'Min limit is 0',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 12),

                  // Total Amount Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade500, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          appLocalizations.totalAmount,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '₹${_totalBoughtAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade300,
                              width: 2,
                            ),
                          ),
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              appLocalizations.cancel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade500,
                                Colors.blue.shade700,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _boughtItems.isEmpty
                                ? null
                                : () {
                                    if (_supplierNameController.text.isEmpty) {
                                      setState(() {
                                        _supplierNameError = appLocalizations
                                            .supplierNameRequired;
                                      });
                                      return;
                                    }
                                    if (_boughtItems.any(
                                      (item) =>
                                          item.sellingPrice <= 0 ||
                                          item.minLimit <= 0,
                                    )) {
                                      _scrollToFirstError();
                                    } else {
                                      _showReviewScreen();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              appLocalizations.saveReview,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
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

  Widget buildModernFormField(
    String hint,
    TextEditingController controller, {
    IconData? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Function()? onTap,
    Function(String)? onChanged,
    bool enabled = true,
    bool readOnly = false,
    bool bottomPadding = true,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding ? 12.0 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        enabled: enabled,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.grey.shade600,
            fontSize: 14,
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade800
              : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade600
                  : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade600
                  : Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          suffixIcon: suffixIcon != null
              ? Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    suffixIcon,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
