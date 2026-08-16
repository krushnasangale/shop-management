import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/product_image_preview_page.dart';
import 'package:flashbill/pages/purchase/add_purchase_review.dart';
import 'package:flashbill/services/image_upload_service.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

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
  final GlobalKey _selectedProductsKey = GlobalKey();
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
      appLog('Error loading existing purchase data: $e');
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
      appLog('Error loading app settings: $e');
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
        appLog('✅ Supplier exists: ${existingSupplier['name']}');
        return existingSupplier['id'] ?? '';
      }

      // Supplier doesn't exist, create it
      appLog('🆕 Creating new supplier: $supplierName');
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

      appLog('✅ Supplier created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      appLog('❌ Error handling scanned supplier: $e');
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
          appLog('🆕 Creating new product: $productName');

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

          appLog('✅ Product created with ID: ${docRef.id}');
        } else {
          appLog('✅ Product exists: ${existingProduct['name']}');
        }
      }
    } catch (e) {
      appLog('❌ Error handling scanned products: $e');
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
          appLog('🆕 Creating new unit: $unitName');

          final newUnit = {'name': unitName.trim()};

          final docRef = await unitsRef.add(newUnit);

          // Update local list
          setState(() {
            _allUnits.add({'id': docRef.id, 'name': unitName.trim()});
          });

          appLog('✅ Unit created with ID: ${docRef.id}');
        } else {
          appLog('✅ Unit exists: ${existingUnit['name']}');
        }
      }
    } catch (e) {
      appLog('❌ Error handling scanned units: $e');
    }
  }

  void _calculateTotalBoughtAmount() {
    _totalBoughtAmount = _boughtItems.fold(
      0.0,
      (total, item) => total + item.total,
    );
  }

  AlertDialog _wideDialog({
    required Widget title,
    required Widget content,
    List<Widget>? actions,
  }) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: title,
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        child: content,
      ),
      actions: actions,
    );
  }

  Future<void> _showImageSourceDialog(
    Function(ImageSource) onSourceSelected,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          appLocalizations.chooseImageSource,
          style: context.bodyLargeText,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera),
              title: Text(appLocalizations.camera),
              onTap: () {
                Navigator.pop(context);
                onSourceSelected(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text(appLocalizations.gallery),
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
            child: Text(appLocalizations.cancel),
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
      text: item.sellingPrice.toInt().toString(),
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
        final scheme = Theme.of(context).colorScheme;
        return _wideDialog(
          title: Text('${appLocalizations.edit} ${item.productName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appLocalizations.productDetails.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${appLocalizations.supplierLabel}${item.supplierName}',
                        ),
                        Text(
                          '${appLocalizations.initialQuantityBought}${item.initialQuantity}',
                        ),
                        if (_expiryDateEnabled &&
                            item.expiryDate != null &&
                            item.expiryDate!.isNotEmpty)
                          Text(
                            '${appLocalizations.expiryDateLabel}${item.expiryDate}',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: unitController,
                  readOnly: true,
                  onTap: () {
                    _showSelectionSheet('Units', _allUnits, unitController);
                  },
                  decoration:
                      Adaptive.compactField(
                        label: appLocalizations.unit,
                        icon: Icons.straighten_outlined,
                      ).copyWith(
                        suffixIcon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: Adaptive.compactIconSize,
                          color: scheme.onSurfaceVariant,
                        ),
                        suffixIconConstraints: Adaptive.compactPrefixConstraints,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: Adaptive.compactField(
                          label: appLocalizations.currentQuantity,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minLimitController,
                        keyboardType: TextInputType.number,
                        decoration: Adaptive.compactField(
                          label: appLocalizations.minStock,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: Adaptive.compactField(
                          label: appLocalizations.buyingPriceRupees,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: sellingPriceController,
                        keyboardType: TextInputType.number,
                        decoration: Adaptive.compactField(
                          label: appLocalizations.sellingPriceRupees,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_expiryDateEnabled) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: expiryDateController,
                    readOnly: true,
                    decoration: Adaptive.compactField(
                      label: appLocalizations.expiryDateOptional,
                      icon: Icons.calendar_today_outlined,
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(appLocalizations.cancel),
            ),
            FilledButton(
              style: Adaptive.compactFilled,
              onPressed: () {
                final quantity = int.tryParse(quantityController.text) ?? 0;
                final price = double.tryParse(priceController.text) ?? 0.0;
                final sellingPrice =
                    (int.tryParse(sellingPriceController.text) ?? 0).toDouble();
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
    final sellingPrice = (int.tryParse(_sellingPriceController.text) ?? 0)
        .toDouble();

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
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(appLocalizations.removeProduct),
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
            FilledButton(
              style: Adaptive.compactFilled.copyWith(
                backgroundColor: WidgetStatePropertyAll(scheme.error),
                foregroundColor: WidgetStatePropertyAll(scheme.onError),
              ),
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
              child: Text(appLocalizations.delete),
            ),
          ],
        );
      },
    );
  }

  void _openReviewIfValid() {
    if (_supplierNameController.text.isEmpty) {
      setState(() {
        _supplierNameError = appLocalizations.supplierNameRequired;
      });
      return;
    }
    if (_boughtItems.any(
      (item) => item.sellingPrice <= 0 || item.minLimit <= 0,
    )) {
      _scrollToFirstError();
      return;
    }
    _showReviewScreen();
  }

  void _scrollToFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedProductsKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title == 'Products'
                              ? localizations.selectProductsTitle
                              : localizations.selectUnitsTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        style: Adaptive.compactIconButton,
                        tooltip: localizations.add,
                        icon: const Icon(Icons.add_rounded, size: 32),
                        onPressed: () async {
                          if (title == 'Products') {
                            final newProductName =
                                await _showAddProductNameDialog(
                                  context,
                                  setModalState,
                                );
                            if (newProductName != null &&
                                newProductName.isNotEmpty) {
                              setState(() {
                                controller.text = newProductName;
                                final newProduct = _allProducts.firstWhere(
                                  (p) => p['name'] == newProductName,
                                  orElse: () => {},
                                );
                                if (newProduct.isNotEmpty) {
                                  _selectedProductImageUrl =
                                      newProduct['imageUrl'];
                                }
                              });
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          } else if (title == 'Units') {
                            _showAddUnitDialog(context, setModalState);
                          }
                        },
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
                    placeholder: title == 'Products'
                        ? localizations.searchProducts
                        : localizations.searchUnits,
                    padding: Adaptive.compactFieldPadding,
                    itemSize: Adaptive.compactIconSize,
                    prefixIcon: const Icon(CupertinoIcons.search),
                    suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill),
                    onChanged: (_) => setModalState(() {}),
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
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 64),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final scheme = Theme.of(context).colorScheme;
                            final name =
                                (item['productName'] ?? item['name'] ?? '')
                                    .toString();
                            final isSelected = name == controller.text;
                            final imageUrl = item['imageUrl'] as String?;
                            final hasImage =
                                imageUrl != null && imageUrl.isNotEmpty;

                            void selectItem() {
                              controller.text = name;
                              if (title == 'Products') {
                                _selectedProductImageUrl = hasImage
                                    ? imageUrl
                                    : null;
                              }
                              Navigator.pop(context);
                            }

                            return _SelectSheetTile(
                              title: name,
                              selected: isSelected,
                              onTap: selectItem,
                              leading: title == 'Products'
                                  ? GestureDetector(
                                      onTap: hasImage
                                          ? () => AppNavigator.push(
                                              context,
                                              ProductImagePreviewPage(
                                                imageUrl: imageUrl,
                                                productName: name,
                                              ),
                                            )
                                          : selectItem,
                                      child: _productThumb(
                                        scheme,
                                        imageUrl: imageUrl,
                                        name: name,
                                      ),
                                    )
                                  : _squareIcon(
                                      Icons.straighten_outlined,
                                      scheme,
                                    ),
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

  Future<String?> _showAddProductNameDialog(
    BuildContext context,
    StateSetter setModalState,
  ) async {
    final productNameController = TextEditingController();
    String productNameError = '';
    File? selectedImage;
    bool isUploading = false;
    double uploadProgress = 0.0;

    return await showDialog<String?>(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _wideDialog(
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
                              label: Text(appLocalizations.removeImage),
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
                FilledButton(
                  style: Adaptive.compactFilled,
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
                                Navigator.pop(
                                  context,
                                  productNameController.text.trim(),
                                );
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
            return _wideDialog(
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
                FilledButton(
                  style: Adaptive.compactFilled,
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

                              if (context.mounted) {
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
                      : null,
                  child: Text(appLocalizations.add),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          appLocalizations.selectSupplierTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        style: Adaptive.compactIconButton,
                        tooltip: appLocalizations.add,
                        icon: const Icon(Icons.add_rounded, size: 32),
                        onPressed: () {
                          _showAddSupplierDialog(
                            context,
                            setModalState,
                            displaySuppliers,
                          );
                        },
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
                    placeholder: appLocalizations.searchSupplier,
                    padding: Adaptive.compactFieldPadding,
                    itemSize: Adaptive.compactIconSize,
                    prefixIcon: const Icon(CupertinoIcons.search),
                    suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill),
                    onChanged: (query) {
                      setModalState(() {
                        if (query.isEmpty) {
                          if (user != null) {
                            final suppliersRef = FirebaseFirestore.instance
                                .collection('suppliers')
                                .doc(user.uid)
                                .collection('items');
                            suppliersRef.get().then((snapshot) {
                              displaySuppliers = snapshot.docs.map((doc) {
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
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: displaySuppliers.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 64),
                          itemBuilder: (context, index) {
                            final supplier = displaySuppliers[index];
                            final name = supplier['name'] ?? 'Unknown';
                            final contact = supplier['contact'] ?? '';
                            final location = supplier['location'] ?? '';
                            final isSelected =
                                supplier['id'] == _selectedSupplierId;
                            final scheme = Theme.of(context).colorScheme;
                            final subtitle = [
                              if (contact.toString().isNotEmpty) contact,
                              if (location.toString().isNotEmpty) location,
                            ].join('  ·  ');

                            return _SelectSheetTile(
                              title: name,
                              subtitle: subtitle.isEmpty ? null : subtitle,
                              selected: isSelected,
                              leading: _squareIcon(
                                Icons.local_shipping_outlined,
                                scheme,
                              ),
                              onTap: () {
                                setState(() {
                                  _supplierNameController.text = name;
                                  _selectedSupplierId = supplier['id'] ?? '';
                                  _supplierNameError = '';
                                });
                                Navigator.pop(context);
                              },
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

    // Capture before showDialog so it isn't shadowed by the builder's context param
    final bottomSheetContext = context;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _wideDialog(
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
                FilledButton(
                  style: Adaptive.compactFilled,
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

                                final docRef = await suppliersRef.add(
                                  newSupplier,
                                );
                                final newId = docRef.id;

                                // Update local list with real ID and auto-select
                                setState(() {
                                  _supplierDetails.add({
                                    'id': newId,
                                    'name': supplierName,
                                    'contact': contact,
                                    'location': location,
                                  });
                                  _selectedSupplierId = newId;
                                  _supplierNameController.text = supplierName;
                                  _supplierNameError = '';
                                });

                                // Update the parent drawer state
                                setModalState(() {
                                  displaySuppliers.add({
                                    'id': newId,
                                    'name': supplierName,
                                    'contact': contact,
                                    'location': location,
                                  });
                                });

                                if (context.mounted) {
                                  Navigator.pop(context); // close dialog
                                }
                                if (bottomSheetContext.mounted) {
                                  Navigator.pop(
                                    bottomSheetContext,
                                  ); // close bottom sheet
                                  ScaffoldMessenger.of(
                                    bottomSheetContext,
                                  ).showSnackBar(
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
                                if (context.mounted) {
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
                      : null,
                  child: Text(appLocalizations.add),
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
          if (!mounted) return;
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
        appLog(
          'Item: ${item.productName}, initialQuantity: ${item.initialQuantity}',
        );
      }
      appLog(
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
      appLog('Error saving bought entry: $e');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.purchaseId != null;
    final loc = appLocalizations;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditMode ? loc.editPurchaseEntry : 'Add ${loc.purchases}',
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sectionLabel(context, loc.purchaseDetails),
                _compactInput(
                  label: loc.selectDate,
                  controller: _dateController,
                  icon: Icons.calendar_today_outlined,
                  readOnly: true,
                  onTap: _pickPurchaseDate,
                ),
                const SizedBox(height: 12),
                _compactInput(
                  label: loc.selectSupplier,
                  controller: _supplierNameController,
                  icon: Icons.local_shipping_outlined,
                  readOnly: true,
                  dropdown: true,
                  errorText: _supplierNameError,
                  onTap: () => _showSupplierSelectionDrawer(context),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.purchaseInfoMessage,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _sectionLabel(context, loc.productDetails),
                _compactInput(
                  label: loc.selectProductName,
                  controller: _productController,
                  icon: Icons.inventory_2_outlined,
                  readOnly: true,
                  dropdown: true,
                  onTap: () => _showSelectionSheet(
                    'Products',
                    _allProducts,
                    _productController,
                  ),
                ),
                const SizedBox(height: 12),
                _compactInput(
                  label: loc.selectProductUnit,
                  controller: _unitController,
                  icon: Icons.straighten_outlined,
                  readOnly: true,
                  dropdown: true,
                  onTap: () => _showSelectionSheet(
                    'Units',
                    _allUnits,
                    _unitController,
                  ),
                ),
                if (_expiryDateEnabled) ...[
                  const SizedBox(height: 12),
                  _compactInput(
                    label: loc.expiryDateOptional,
                    controller: _expiryDateController,
                    icon: Icons.calendar_today_outlined,
                    readOnly: true,
                    onTap: _pickExpiryDate,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _compactInput(
                        label: loc.productQuantity,
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _compactInput(
                        label: loc.minQty,
                        controller: _minLimitController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _compactInput(
                            label: loc.buyingPrice,
                            controller: _buyingPriceController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            loc.buyingPricePerItem,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _compactInput(
                            label: loc.sellingPrice,
                            controller: _sellingPriceController,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            loc.sellingPricePerItem,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: Adaptive.compactFilled,
                    onPressed: _addProductToList,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(loc.addProduct),
                  ),
                ),
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: _selectedProductsKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(context, loc.selectedProducts),
                      if (_boughtItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            loc.noProductsAddedYet,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      else
                        for (var i = 0; i < _boughtItems.length; i++) ...[
                          _BoughtItemCard(
                            item: _boughtItems[i],
                            loc: loc,
                            onEdit: () =>
                                _showEditBoughtItemDialog(_boughtItems[i]),
                            onRemove: () => _removeBoughtItem(i),
                          ),
                          if (i != _boughtItems.length - 1)
                            const SizedBox(height: 8),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Adaptive.box(
                  context: context,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        _squareIcon(Icons.payments_outlined, scheme),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            loc.totalAmount,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          '₹${_formatAmount(_totalBoughtAmount)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Adaptive.sliverBottomAction(
            child: FilledButton(
              style: Adaptive.compactFilled,
              onPressed: _boughtItems.isEmpty ? null : _openReviewIfValid,
              child: Text(loc.saveReview),
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
    bool dropdown = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      decoration: Adaptive.compactField(
        label: label,
        icon: icon,
        errorText: (errorText == null || errorText.isEmpty) ? null : errorText,
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

  Future<void> _pickPurchaseDate() async {
    DateTime initialDate = DateTime.now();
    try {
      if (_dateController.text.isNotEmpty) {
        initialDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
      }
    } catch (_) {}

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      _dateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
    }
  }

  Future<void> _pickExpiryDate() async {
    DateTime initialDate = DateTime.now().add(const Duration(days: 30));
    try {
      if (_expiryDateController.text.isNotEmpty) {
        initialDate = DateFormat(
          'dd/MM/yyyy',
        ).parse(_expiryDateController.text);
      }
    } catch (_) {}

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      _expiryDateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
    }
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

class _SelectSheetTile extends StatelessWidget {
  const _SelectSheetTile({
    required this.title,
    required this.leading,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.45),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      minVerticalPadding: 4,
      leading: leading,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        Icons.check,
        size: 22,
        color: selected ? scheme.primary : Colors.transparent,
      ),
      onTap: onTap,
    );
  }
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

Widget _productThumb(
  ColorScheme scheme, {
  required String? imageUrl,
  required String name,
}) {
  final hasImage = imageUrl != null && imageUrl.isNotEmpty;
  final fallback = name.isNotEmpty ? name[0].toUpperCase() : '?';
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 36,
      height: 36,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => ColoredBox(
                color: scheme.primaryContainer,
                child: Center(
                  child: Text(
                    fallback,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            )
          : ColoredBox(
              color: scheme.primaryContainer,
              child: Center(
                child: Text(
                  fallback,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
    ),
  );
}

class _BoughtItemCard extends StatelessWidget {
  const _BoughtItemCard({
    required this.item,
    required this.loc,
    required this.onEdit,
    required this.onRemove,
  });

  final BoughtItem item;
  final AppLocalizations loc;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSellingPriceError = item.sellingPrice <= 0;
    final hasMinLimitError = item.minLimit <= 0;
    final profit = item.sellingPrice - item.buyingPrice;
    final meta = [
      if (item.expiryDate != null && item.expiryDate!.isNotEmpty)
        item.expiryDate!,
      if (item.unit.isNotEmpty) item.unit,
    ].join('  ·  ');

    return Card(
      color: (hasSellingPriceError || hasMinLimitError)
          ? scheme.errorContainer.withValues(alpha: 0.35)
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? () => AppNavigator.push(
                          context,
                          ProductImagePreviewPage(
                            imageUrl: item.imageUrl!,
                            productName: item.productName,
                          ),
                        )
                      : null,
                  child: _productThumb(
                    scheme,
                    imageUrl: item.imageUrl,
                    name: item.productName,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '₹${_formatAmount(item.total)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                AppContextMenu.iconButton(
                  dense: true,
                  width: 168,
                  items: () => [
                    AppContextMenuItem(
                      label: loc.edit,
                      icon: CupertinoIcons.pencil,
                      onPressed: onEdit,
                    ),
                    AppContextMenuItem(
                      label: loc.removeProduct,
                      icon: CupertinoIcons.delete,
                      destructive: true,
                      onPressed: onRemove,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _BoughtMetric(
                  label: 'Qty',
                  value: item.unit.isEmpty
                      ? '${item.quantity}'
                      : '${item.quantity} ${item.unit}',
                ),
                _BoughtMetric(
                  label: 'Buy',
                  value: '₹${_formatAmount(item.buyingPrice)}',
                ),
                _BoughtMetric(
                  label: 'Sell',
                  value: '₹${_formatAmount(item.sellingPrice)}',
                ),
                _BoughtMetric(
                  label: 'Min',
                  value: '${item.minLimit}',
                  valueColor: hasMinLimitError ? scheme.error : null,
                ),
              ],
            ),
            if (hasSellingPriceError || hasMinLimitError) ...[
              const SizedBox(height: 8),
              if (hasSellingPriceError)
                Text(
                  'Selling price is 0',
                  style: TextStyle(
                    color: scheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (hasMinLimitError)
                Text(
                  'Min limit is 0',
                  style: TextStyle(
                    color: scheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
            if (!hasSellingPriceError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${loc.profitPerUnit}: ${profit >= 0 ? '+' : ''}₹${_formatAmount(profit)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: profit >= 0 ? scheme.primary : scheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoughtMetric extends StatelessWidget {
  const _BoughtMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
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
              fontWeight: FontWeight.w700,
              color: valueColor ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(num amount) {
  if (amount == amount.roundToDouble()) return amount.toInt().toString();
  return amount.toStringAsFixed(2);
}
