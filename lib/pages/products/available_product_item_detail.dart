import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flashbill/pages/products/available_products.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:flashbill/pages/products/tabs/sales_history_tab.dart';
import 'package:flashbill/pages/products/tabs/purchase_history_tab.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/services/image_upload_service.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/pages/product_image_preview_page.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/services/subscription_guard.dart';

class AvailableProductDetailScreen extends StatefulWidget {
  final BoughtProduct product;
  final String userId; // Pass userId for correct database path

  const AvailableProductDetailScreen({
    super.key,
    required this.product,
    required this.userId,
  });

  @override
  State<AvailableProductDetailScreen> createState() =>
      _AvailableProductDetailScreenState();
}

class _AvailableProductDetailScreenState
    extends State<AvailableProductDetailScreen>
    with SingleTickerProviderStateMixin {
  // Local state for editable fields
  late TextEditingController _quantityController;
  late TextEditingController _minLimitController;
  late TabController _tabController;
  List<BoughtProduct> _allBatches = [];
  bool _isLoadingBatches = true;
  bool _editingMinLimit = false;
  final Map<String, bool> _editingBatchPrices = {};
  final Map<String, TextEditingController> _batchPriceControllers = {};
  final Map<String, bool> _editingBatchQuantities = {};
  final Map<String, TextEditingController> _batchQuantityControllers = {};
  List<Map<String, dynamic>> _purchaseHistory = []; // Complete purchase history
  List<Map<String, dynamic>> _filteredPurchaseHistory = [];
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _soldHistory = []; // Complete sold history
  List<Map<String, dynamic>> _filteredSoldHistory = []; // Filtered sold history
  bool _isLoadingSoldHistory = true;
  final Map<int, bool> _expandedBatches = {};
  String? _currentImageUrl; // Track current product image URL

  // Search and filter state for purchases
  late TextEditingController _searchController;
  final String _sortBy = 'date'; // date, amount, supplier, profit
  final bool _sortAscending = false;
  final String _filterSupplier = 'all';

  // Search and filter state for sales
  late TextEditingController _searchSalesController;
  final String _sortSalesBy = 'date'; // date, amount, customer, profit
  final bool _sortSalesAscending = false;
  final String _filterCustomer = 'all';

  @override
  void initState() {
    super.initState();

    // Initialize current image URL
    _currentImageUrl = widget.product.imageUrl;

    // Initialize TabController
    _tabController = TabController(length: 3, vsync: this);

    // Initialize search controllers
    _searchController = TextEditingController();
    _searchController.addListener(_filterAndSortPurchaseHistory);

    _searchSalesController = TextEditingController();
    _searchSalesController.addListener(_filterAndSortSoldHistory);

    // Initialize controllers with current product values
    _quantityController = TextEditingController(
      text: widget.product.quantity.toString(),
    );

    // Calculate min limit from all available batches
    _minLimitController = TextEditingController();

    // Load all batches for this product
    _loadAllBatches();

    // Load complete purchase history for this product
    _loadPurchaseHistory();

    // Load complete sold history for this product
    _loadSoldHistory();
  }

  Future<void> _loadAllBatches() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(widget.userId)
          .collection('items')
          .get();

      final batches = <BoughtProduct>[];
      for (var doc in snapshot.docs) {
        final product = doc.data();
        final quantity = product['quantity'] ?? 0;

        // Only process batches with quantity > 0 and matching product name
        if (quantity > 0 &&
            product['productName'] == widget.product.productName) {
          final batch = BoughtProduct.fromMap(doc.id, product);
          batches.add(batch);
        }
      }

      // Sort by purchase date (oldest first for FIFO)
      batches.sort(
        (a, b) =>
            DateTime.tryParse(
              a.purchaseDate,
            )?.compareTo(DateTime.tryParse(b.purchaseDate) ?? DateTime.now()) ??
            0,
      );

      if (mounted) {
        // Calculate min limit - get it from the one batch that stores it (minLimit > 0)
        int minLimit = 0;
        for (var batch in batches) {
          if (batch.minLimit > 0) {
            minLimit = batch.minLimit;
            break;
          }
        }

        setState(() {
          _allBatches = batches;
          _isLoadingBatches = false;
          _minLimitController.text = minLimit.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBatches = false;
        });
      }
    }
  }

  Future<void> _loadPurchaseHistory() async {
    try {
      // Read from the purchased-products collection to show live/current data
      final snapshot = await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(widget.userId)
          .collection('items')
          .get();

      final history = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final item = doc.data();

        // Match by product name and only include items with quantity > 0
        if (item['productName'] == widget.product.productName) {
          // Calculate total amount
          final quantity = (item['initialQuantity'] as num?)?.toInt() ?? 0;
          final buyingPrice = (item['buyingPrice'] as num?)?.toDouble() ?? 0.0;
          final total = quantity * buyingPrice;

          // Add with all required fields for display.
          // `id` / `purchaseId` point at the parent purchase entry so the
          // history row can open PurchaseEntryDetails.
          final purchaseId = (item['purchaseId'] ?? '').toString();
          history.add({
            'id': purchaseId.isNotEmpty ? purchaseId : doc.id,
            'purchaseId': purchaseId,
            'productItemId': doc.id,
            'productName': item['productName'],
            'supplierName': item['supplierName'] ?? 'Unknown',
            'date': item['date'] ?? item['purchaseDate'] ?? '',
            'quantity': quantity,
            'buyingPrice': buyingPrice,
            'sellingPrice': (item['sellingPrice'] as num?)?.toDouble() ?? 0.0,
            'unit': item['unit'] ?? 'units',
            'total': total,
            'paymentMethod': item['paymentMethod'] ?? 'N/A',
            'minLimit': item['minLimit'] ?? 0,
            'batchId': item['batchId'] ?? doc.id,
          });
        }
      }

      // Sort by date (newest first)
      history.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _purchaseHistory = history;
          _filteredPurchaseHistory = history;
          _isLoadingHistory = false;
        });
        _filterAndSortPurchaseHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  // Filter and sort purchase history
  void _filterAndSortPurchaseHistory() {
    setState(() {
      // First filter
      _filteredPurchaseHistory = _purchaseHistory.where((purchase) {
        // Filter by search query
        final searchQuery = _searchController.text;
        final supplierName = (purchase['supplierName'] ?? '').toString();
        final date = (purchase['date'] ?? '').toString();

        if (searchQuery.isNotEmpty &&
            !SearchUtils.matchesSubsequence(supplierName, searchQuery) &&
            !SearchUtils.matchesSubsequence(date, searchQuery)) {
          return false;
        }

        // Filter by supplier
        if (_filterSupplier != 'all' &&
            purchase['supplierName'] != _filterSupplier) {
          return false;
        }

        return true;
      }).toList();

      // Then sort
      _filteredPurchaseHistory.sort((a, b) {
        int comparison = 0;

        switch (_sortBy) {
          case 'date':
            DateTime dateA =
                DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
            DateTime dateB =
                DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
            comparison = dateA.compareTo(dateB);
            break;
          case 'amount':
            comparison = ((a['total'] ?? 0) as num).compareTo(
              (b['total'] ?? 0) as num,
            );
            break;
          case 'supplier':
            comparison = (a['supplierName'] ?? '').toString().compareTo(
              (b['supplierName'] ?? '').toString(),
            );
            break;
          case 'profit':
            final profitA =
                ((a['sellingPrice'] ?? 0) - (a['buyingPrice'] ?? 0)) *
                (a['quantity'] ?? 0);
            final profitB =
                ((b['sellingPrice'] ?? 0) - (b['buyingPrice'] ?? 0)) *
                (b['quantity'] ?? 0);
            comparison = profitA.compareTo(profitB);
            break;
        }

        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  Future<void> _loadSoldHistory() async {
    try {
      // Read from the bills collection and extract products sold
      final snapshot = await FirebaseFirestore.instance
          .collection('bills')
          .doc(widget.userId)
          .collection('items')
          .get();

      final history = <Map<String, dynamic>>[];
      for (var billDoc in snapshot.docs) {
        final billData = billDoc.data();
        final productsMap = billData['products'] as Map<String, dynamic>?;

        if (productsMap != null) {
          // Iterate through products in this bill
          for (var productEntry in productsMap.entries) {
            final product = productEntry.value as Map<String, dynamic>;

            // Match by product name. Keep full bill fields so the row can
            // open ViewBillDetailsScreen without a second fetch.
            if (product['productName'] == widget.product.productName) {
              history.add({
                'id': billDoc.id,
                'billId': billDoc.id,
                'date': billData['billDate'] ?? 'N/A',
                'billDate': billData['billDate'] ?? 'N/A',
                'timestamp': billData['timestamp'] ?? '',
                'customerName': billData['customerName'] ?? 'Unknown',
                'customerMobile': billData['customerMobile'] ?? 'N/A',
                'customerVehicle': billData['customerVehicle'],
                'totalAmount': billData['totalAmount'] ?? 0,
                'totalAmountPaid': billData['totalAmountPaid'] ?? false,
                'amountPaid': billData['amountPaid'] ?? 0,
                'amountRemaining':
                    billData['amountRemaining'] ?? billData['totalAmount'] ?? 0,
                'products': billData['products'],
                'paymentMethod': billData['paymentMethod'] ?? 'cash',
                'nextPaymentDate': billData['nextPaymentDate'],
                'previousDueAmount': billData['previousDueAmount'] ?? 0,
                'previousPaidAmount': billData['previousPaidAmount'] ?? 0,
                'previousDueDescription':
                    billData['previousDueDescription'] ?? '',
                'quantity': product['quantity'] ?? 0,
                'sellingPrice': product['price'] ?? 0,
                'total': product['total'] ?? 0,
                'unit': product['unit'] ?? 'units',
                'buyingPrice': product['boughtPrice'] ?? 0,
              });
            }
          }
        }
      }

      // Sort by timestamp (newest first)
      history.sort((a, b) {
        final timestampA = a['timestamp'] ?? '';
        final timestampB = b['timestamp'] ?? '';
        return timestampB.compareTo(timestampA);
      });

      if (mounted) {
        setState(() {
          _soldHistory = history;
          _filteredSoldHistory = history;
          _isLoadingSoldHistory = false;
        });
        _filterAndSortSoldHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSoldHistory = false;
        });
      }
    }
  }

  // Filter and sort sold history
  void _filterAndSortSoldHistory() {
    setState(() {
      // First filter
      _filteredSoldHistory = _soldHistory.where((sale) {
        // Filter by search query
        final searchQuery = _searchSalesController.text;
        final customerName = (sale['customerName'] ?? '').toString();
        final date = (sale['date'] ?? '').toString();

        if (searchQuery.isNotEmpty &&
            !SearchUtils.matchesSubsequence(customerName, searchQuery) &&
            !SearchUtils.matchesSubsequence(date, searchQuery)) {
          return false;
        }

        // Filter by customer
        if (_filterCustomer != 'all' &&
            sale['customerName'] != _filterCustomer) {
          return false;
        }

        return true;
      }).toList();

      // Then sort
      _filteredSoldHistory.sort((a, b) {
        int comparison = 0;

        switch (_sortSalesBy) {
          case 'date':
            final timestampA = a['timestamp'] ?? '';
            final timestampB = b['timestamp'] ?? '';
            comparison = timestampA.compareTo(timestampB);
            break;
          case 'amount':
            comparison = ((a['total'] ?? 0) as num).compareTo(
              (b['total'] ?? 0) as num,
            );
            break;
          case 'customer':
            comparison = (a['customerName'] ?? '').toString().compareTo(
              (b['customerName'] ?? '').toString(),
            );
            break;
          case 'profit':
            final profitA =
                ((a['sellingPrice'] ?? 0) - (a['buyingPrice'] ?? 0)) *
                (a['quantity'] ?? 0);
            final profitB =
                ((b['sellingPrice'] ?? 0) - (b['buyingPrice'] ?? 0)) *
                (b['quantity'] ?? 0);
            comparison = profitA.compareTo(profitB);
            break;
        }

        return _sortSalesAscending ? comparison : -comparison;
      });
    });
  }

  Future<void> _showImageSourceDialog(
    Function(ImageSource) onSourceSelected,
  ) async {
    showDialog(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(loc.chooseImageSource, style: context.bodyLargeText),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera),
                title: Text(loc.camera),
                onTap: () {
                  Navigator.pop(context);
                  onSourceSelected(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text(loc.gallery),
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
              child: Text(loc.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectImage() async {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    await _showImageSourceDialog((source) async {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (!mounted) return;
      if (image != null) {
        // Show loading dialog with progress
        double uploadProgress = 0.0;
        StateSetter? dialogSetState;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setState) {
                dialogSetState = setState;
                return Dialog(
                  backgroundColor: Colors.white,
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Uploading Image...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(
                          uploadProgress > 0
                              ? '${(uploadProgress * 100).round()}%'
                              : 'Preparing image...',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );

        try {
          // Upload image to Firebase Storage
          final imageUrl = await ImageUploadService.uploadProductImage(
            userId: widget.userId,
            productId: widget.product.id,
            image: File(image.path),
            deleteOldImage: true,
            onProgress: (progress) {
              if (dialogSetState != null) {
                dialogSetState!(() {
                  uploadProgress = progress;
                });
              }
            },
          );

          if (imageUrl != null) {
            // Update Firestore and local state in parallel for faster UX
            final updateFuture = FirebaseFirestore.instance
                .collection('purchased-products')
                .doc(widget.userId)
                .collection('items')
                .doc(widget.product.id)
                .update({'imageUrl': imageUrl});

            // Update UI immediately (optimistic update)
            if (mounted) {
              setState(() {
                _currentImageUrl = imageUrl;
              });
            }

            // Wait for Firestore update to complete
            await updateFuture;

            // Close loading dialog
            if (mounted) {
              Navigator.pop(context);
            }

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.productImageUpdated,
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            // Close loading dialog
            if (mounted) {
              Navigator.pop(context);
            }

            // Show error message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.failedToUploadImage,
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } catch (e) {
          // Close loading dialog
          if (mounted) {
            Navigator.pop(context);
          }

          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${AppLocalizations.of(context)!.error}: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  void _shareProduct(String productName, String? imageUrl) async {
    // Check if there are multiple batches
    if (_allBatches.length > 1) {
      // Show batch selection dialog
      final selectedBatch = await showDialog<BoughtProduct>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              AppLocalizations.of(context)!.selectBatchToShare,
              style: context.bodyLargeText,
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _allBatches.length,
                itemBuilder: (context, index) {
                  final batch = _allBatches[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(color: Colors.blue.shade800),
                      ),
                    ),
                    title: Text(
                      '${batch.supplierName} - ${batch.purchaseDate}',
                    ),
                    subtitle: Text(
                      '${batch.quantity} ${batch.unit} @ ₹${batch.sellingPrice.toStringAsFixed(2)}',
                    ),
                    onTap: () => Navigator.of(context).pop(batch),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
            ],
          );
        },
      );

      if (selectedBatch == null) return; // User cancelled

      // Share selected batch
      await _shareBatch(selectedBatch, imageUrl);
    } else if (_allBatches.length == 1) {
      // Share the single batch
      await _shareBatch(_allBatches.first, imageUrl);
    } else {
      // No batches available
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.noBatchesToShare),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _shareBatch(BoughtProduct batch, String? imageUrl) async {
    try {
      // Create share text with essential product details
      final shareText =
          '📦 ${batch.productName}\n'
          '💰 Price: ₹${batch.sellingPrice.toStringAsFixed(2)}\n'
          '📊 Available Stock: ${batch.quantity} ${batch.unit}';

      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Show loading dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Preparing image for sharing...',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Download the image
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          // Close loading dialog
          if (mounted) {
            Navigator.pop(context);
          }

          // Save to temporary file
          final tempDir = await getTemporaryDirectory();
          final fileName =
              'shared_product_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(response.bodyBytes);

          // Share with image
          await SharePlus.instance.share(
            ShareParams(files: [XFile(tempFile.path)], text: shareText),
          );

          // Clean up temp file after sharing
          tempFile.delete().ignore();
        } else {
          // Close loading dialog
          if (mounted) {
            Navigator.pop(context);
          }

          // Fallback to text-only sharing if image download fails
          await SharePlus.instance.share(ShareParams(text: shareText));
        }
      } else {
        // Share text only
        await SharePlus.instance.share(ShareParams(text: shareText));
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (mounted) {
        Navigator.pop(context);
      }

      // Fallback to text-only sharing on any error
      try {
        // Create fallback share text with essential product details
        final fallbackText =
            '📦 ${batch.productName}\n'
            '💰 Price: ₹${batch.sellingPrice.toStringAsFixed(2)}\n'
            '📊 Available: ${batch.quantity} ${batch.unit}';

        await SharePlus.instance.share(ShareParams(text: fallbackText));
      } catch (fallbackError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)!.failedToShareProduct}: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quantityController.dispose();
    _minLimitController.dispose();
    _searchController.dispose();
    _searchSalesController.dispose();
    // Dispose all batch price controllers
    for (var controller in _batchPriceControllers.values) {
      controller.dispose();
    }
    // Dispose all batch quantity controllers
    for (var controller in _batchQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- SAVE BATCH SELLING PRICE ---
  Future<void> _saveBatchSellingPrice(String batchId, double newPrice) async {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    try {
      await FirebaseFirestore.instance
          .collection('purchased-products')
          .doc(widget.userId)
          .collection('items')
          .doc(batchId)
          .update({'sellingPrice': newPrice});

      // Reload batches to reflect changes
      await _loadAllBatches();
      // Reload purchase history to reflect changes in purchase tab
      await _loadPurchaseHistory();

      if (mounted) {
        setState(() {
          _editingBatchPrices[batchId] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.sellingPriceUpdated),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.errorUpdatingPrice}: $e',
            ),
          ),
        );
      }
    }
  }

  // --- SHOW EDIT QUANTITY DIALOG ---
  void _showEditQuantityDialog(BoughtProduct batch) {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final localizations = AppLocalizations.of(context)!;
    final quantityController = TextEditingController(
      text: batch.quantity.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.editQuantity, style: context.bodyLargeText),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: localizations.quantity,
            hintText: localizations.enterQuantity,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(quantityController.text);
              if (newQuantity != null) {
                _saveBatchQuantity(batch.id, newQuantity);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(localizations.enterValidQuantity)),
                );
              }
            },
            child: Text(localizations.save),
          ),
        ],
      ),
    );
  }

  // --- SHOW EDIT SELLING PRICE DIALOG ---
  void _showEditSellingPriceDialog(BoughtProduct batch) {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final localizations = AppLocalizations.of(context)!;
    final priceController = TextEditingController(
      text: batch.sellingPrice.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localizations.editSellingPrice,
          style: context.bodyLargeText,
        ),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: localizations.sellingPrice,
            hintText: localizations.enterPrice,
            prefix: const Text('₹'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice > 0) {
                _saveBatchSellingPrice(batch.id, newPrice);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(localizations.enterValidPrice)),
                );
              }
            },
            child: Text(localizations.save),
          ),
        ],
      ),
    );
  }

  // --- SAVE BATCH QUANTITY ---
  Future<void> _saveBatchQuantity(String batchId, int newQuantity) async {
    final localizations = AppLocalizations.of(context)!;
    try {
      final firestore = FirebaseFirestore.instance;

      // Get the product batch to find the old quantity and purchaseId
      final batchDoc = await firestore
          .collection('purchased-products')
          .doc(widget.userId)
          .collection('items')
          .doc(batchId)
          .get();

      if (!batchDoc.exists) {
        throw Exception('Product batch not found');
      }

      final batchData = batchDoc.data()!;
      final oldQuantity = (batchData['quantity'] as num?)?.toInt() ?? 0;
      final oldInitialQuantity =
          (batchData['initialQuantity'] as num?)?.toInt() ?? 0;
      final buyingPrice = (batchData['buyingPrice'] as num?)?.toDouble() ?? 0.0;
      final purchaseId = batchData['purchaseId'] as String?;

      // Calculate the quantity difference and amount difference
      final quantityDifference = newQuantity - oldQuantity;
      final oldTotal = oldQuantity * buyingPrice;
      final newTotal = newQuantity * buyingPrice;
      final amountDifference = newTotal - oldTotal;

      // Calculate new initial quantity (adjust by the difference)
      final newInitialQuantity = oldInitialQuantity + quantityDifference;

      // If newQuantity is 0, delete the batch
      if (newQuantity == 0) {
        await firestore
            .collection('purchased-products')
            .doc(widget.userId)
            .collection('items')
            .doc(batchId)
            .delete();
      } else {
        // Update the product batch quantity
        await firestore
            .collection('purchased-products')
            .doc(widget.userId)
            .collection('items')
            .doc(batchId)
            .update({
              'quantity': newQuantity,
              'initialQuantity': newInitialQuantity,
            });
      }

      // Update the purchase record's totalUnits and totalAmount if purchaseId exists
      if (purchaseId != null && purchaseId.isNotEmpty) {
        final purchaseDoc = await firestore
            .collection('purchases')
            .doc(widget.userId)
            .collection('items')
            .doc(purchaseId)
            .get();

        if (purchaseDoc.exists) {
          final purchaseData = purchaseDoc.data()!;
          final currentTotalUnits =
              (purchaseData['totalUnits'] as num?)?.toInt() ?? 0;
          final currentTotalAmount =
              (purchaseData['totalAmount'] as num?)?.toDouble() ?? 0.0;

          final newTotalUnits = currentTotalUnits + quantityDifference;
          final newTotalAmount = currentTotalAmount + amountDifference;

          // Update the purchase record
          await firestore
              .collection('purchases')
              .doc(widget.userId)
              .collection('items')
              .doc(purchaseId)
              .update({
                'totalUnits': newTotalUnits > 0 ? newTotalUnits : 0,
                'totalAmount': newTotalAmount > 0 ? newTotalAmount : 0,
              });
        }
      }

      // Reload batches to reflect changes
      await _loadAllBatches();
      // Reload purchase history to reflect changes in purchase tab
      await _loadPurchaseHistory();

      if (mounted) {
        setState(() {
          _editingBatchQuantities[batchId] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newQuantity == 0
                  ? '${localizations.quantityUpdated} (Batch removed)'
                  : localizations.quantityUpdated,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.errorUpdatingQuantity}: $e')),
        );
      }
    }
  }

  // --- FINANCIAL CALCULATIONS (From all batches with their individual prices) ---
  double get totalStockQty {
    if (_isLoadingBatches) return 0;
    return _allBatches.fold<double>(0, (double sum, b) => sum + b.quantity);
  }

  double get totalPotentialRevenue {
    if (_isLoadingBatches) return 0;
    double total = 0;
    for (var batch in _allBatches) {
      total += batch.sellingPrice * batch.quantity;
    }
    return total;
  }

  double get totalPotentialProfit {
    if (_isLoadingBatches) return 0;
    double totalProfit = 0;
    for (var batch in _allBatches) {
      totalProfit += (batch.sellingPrice - batch.buyingPrice) * batch.quantity;
    }
    return totalProfit;
  }

  double get averageBuyingPrice {
    if (_isLoadingBatches || totalStockQty == 0) {
      return widget.product.buyingPrice;
    }
    double totalCost = 0;
    for (var batch in _allBatches) {
      totalCost += batch.buyingPrice * batch.quantity;
    }
    return totalCost / totalStockQty;
  }

  double get averageSellingPrice {
    if (_isLoadingBatches || totalStockQty == 0) {
      return widget.product.sellingPrice;
    }
    return totalPotentialRevenue / totalStockQty;
  }

  double get profitMargin {
    final avgBuy = averageBuyingPrice;
    final avgSell = averageSellingPrice;
    if (avgBuy <= 0) return 0.0;
    return ((avgSell - avgBuy) / avgBuy) * 100;
  }

  // --- UI BUILDERS ---
  /// Section headings across the info tab: small, uppercase-weight labels
  /// matching the purchases and bills screens.
  TextStyle _sectionLabelStyle(BuildContext context) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  ButtonStyle get _denseIconButtonStyle => IconButton.styleFrom(
    minimumSize: const Size(32, 32),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    iconSize: 18,
  );

  Widget _buildDetailRow(
    BuildContext context,
    String title,
    String subtitle, {
    IconData? icon,
    Color? valueColor,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: scheme.onSurfaceVariant, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: valueColor ?? scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final totalPotentialRevenue = this.totalPotentialRevenue;
    final totalPotentialProfit = this.totalPotentialProfit;
    final profitMargin = this.profitMargin;
    final avgBuyingPrice = averageBuyingPrice;
    final avgSellingPrice = averageSellingPrice;

    // Calculate total invested amount
    final totalInvestedAmount = _allBatches.fold<double>(
      0,
      (double sum, batch) => sum + (batch.buyingPrice * batch.quantity),
    );

    // Calculate total quantity by unit
    final totalQuantityByUnit = _allBatches.fold<Map<String, int>>({}, (
      map,
      batch,
    ) {
      map[batch.unit] = (map[batch.unit] ?? 0) + batch.quantity;
      return map;
    });

    // Capitalize product name for display
    final displayedProductName =
        widget.product.productName[0].toUpperCase() +
        widget.product.productName.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(displayedProductName),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 4),
                  Text(localizations.info),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(localizations.purchases),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.point_of_sale_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(localizations.sales),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              if (!SubscriptionGuard.ensureCanWrite(context)) return;
              bool isDeleting = false;
              // Confirm deletion
              showDialog(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setState) {
                    return AlertDialog(
                      title: Text(
                        localizations.deleteProduct,
                        style: context.bodyLargeText,
                      ),
                      content: Text(localizations.deleteProductConfirmation),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(localizations.cancel),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: isDeleting
                              ? null
                              : () async {
                                  setState(() => isDeleting = true);
                                  try {
                                    // Delete all batches of this product from purchased-products collection
                                    final batchesSnapshot =
                                        await FirebaseFirestore.instance
                                            .collection('purchased-products')
                                            .doc(widget.userId)
                                            .collection('items')
                                            .where(
                                              'productName',
                                              isEqualTo:
                                                  widget.product.productName,
                                            )
                                            .get();

                                    // Collect unique purchase IDs from all batches
                                    Set<String> affectedPurchaseIds = {};
                                    for (var doc in batchesSnapshot.docs) {
                                      final purchaseId =
                                          doc.data()['purchaseId'] as String?;
                                      if (purchaseId != null &&
                                          purchaseId.isNotEmpty) {
                                        affectedPurchaseIds.add(purchaseId);
                                      }
                                    }

                                    // Delete each batch
                                    for (var doc in batchesSnapshot.docs) {
                                      await doc.reference.delete();
                                    }

                                    // Update or delete affected purchase entries
                                    for (String purchaseId
                                        in affectedPurchaseIds) {
                                      // Get remaining items for this purchase
                                      final remainingItems =
                                          await FirebaseFirestore.instance
                                              .collection('purchased-products')
                                              .doc(widget.userId)
                                              .collection('items')
                                              .where(
                                                'purchaseId',
                                                isEqualTo: purchaseId,
                                              )
                                              .get();

                                      if (remainingItems.docs.isEmpty) {
                                        // No items left, delete the purchase entry
                                        await FirebaseFirestore.instance
                                            .collection('purchases')
                                            .doc(widget.userId)
                                            .collection('items')
                                            .doc(purchaseId)
                                            .delete();
                                      } else {
                                        // Recalculate purchase totals
                                        double newTotalAmount = 0;
                                        int newTotalUnits = 0;
                                        int newTotalProducts =
                                            remainingItems.docs.length;

                                        for (var doc in remainingItems.docs) {
                                          final total =
                                              (doc['total'] ?? 0) as num;
                                          final quantity =
                                              (doc['initialQuantity'] ?? 0)
                                                  as num;
                                          newTotalAmount += total.toDouble();
                                          newTotalUnits += quantity.toInt();
                                        }

                                        // Update the purchase entry
                                        await FirebaseFirestore.instance
                                            .collection('purchases')
                                            .doc(widget.userId)
                                            .collection('items')
                                            .doc(purchaseId)
                                            .update({
                                              'totalAmount': newTotalAmount,
                                              'totalUnits': newTotalUnits,
                                              'totalProducts': newTotalProducts,
                                            });
                                      }
                                    }

                                    setState(() => isDeleting = false);
                                    if (context.mounted) {
                                      Navigator.of(
                                        context,
                                      ).pop(); // Close dialog
                                      Navigator.of(
                                        context,
                                      ).pop(); // Go back after deletion
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${widget.product.productName} deleted successfully (${batchesSnapshot.docs.length} batches removed)',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isDeleting = false);
                                    if (context.mounted) {
                                      Navigator.of(
                                        context,
                                      ).pop(); // Close dialog
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${localizations.errorDeletingProduct}: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isDeleting
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(localizations.delete),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Info Tab
          _buildInfoTab(
            context,
            localizations,
            totalPotentialRevenue,
            totalPotentialProfit,
            profitMargin,
            totalInvestedAmount,
            avgBuyingPrice,
            avgSellingPrice,
            totalQuantityByUnit,
          ),
          // Purchase History Tab
          PurchaseHistoryTab(
            purchaseHistory: _purchaseHistory,
            isLoading: _isLoadingHistory,
          ),
          // Sold History Tab
          SalesHistoryTab(
            soldHistory: _soldHistory,
            isLoading: _isLoadingSoldHistory,
          ),
        ],
      ),
    );
  }

  // Build Info Tab
  Widget _buildInfoTab(
    BuildContext context,
    AppLocalizations localizations,
    double totalPotentialRevenue,
    double totalPotentialProfit,
    double profitMargin,
    double totalInvestedAmount,
    double avgBuyingPrice,
    double avgSellingPrice,
    Map<String, int> totalQuantityByUnit,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          // Product Header Card
          Adaptive.box(
            context: context,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // Product Image (Left side)
                  SizedBox(
                    width: 160,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                      children: [
                        // Main image with tap functionality
                        Positioned.fill(
                          child: InkWell(
                            onTap: () {
                              if (_currentImageUrl != null &&
                                  _currentImageUrl!.isNotEmpty) {
                                AppNavigator.push(
                                  context,
                                  ProductImagePreviewPage(
                                    imageUrl: _currentImageUrl!,
                                    productName: widget.product.productName,
                                  ),
                                );
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child:
                                  _currentImageUrl != null &&
                                      _currentImageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: _currentImageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey.shade100,
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color: Colors.grey.shade100,
                                            child: const Center(
                                              child: Icon(
                                                Icons.inventory_2,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                    )
                                  : Container(
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: Icon(
                                          Icons.inventory_2,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        // Maximize button overlay
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.fullscreen,
                                size: 14,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (_currentImageUrl != null &&
                                    _currentImageUrl!.isNotEmpty) {
                                  AppNavigator.push(
                                    context,
                                    ProductImagePreviewPage(
                                      imageUrl: _currentImageUrl!,
                                      productName: widget.product.productName,
                                    ),
                                  );
                                }
                              },
                              tooltip: AppLocalizations.of(context)
                                      ?.viewFullImage ??
                                  'View full image',
                            ),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Product Details and Actions (Right side)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name
                        Text(
                          widget.product.productName[0].toUpperCase() +
                              widget.product.productName.substring(1),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${localizations.totalQuantity}: $totalStockQty',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: Adaptive.compactOutlined,
                            onPressed: () => _shareProduct(
                              widget.product.productName,
                              _currentImageUrl,
                            ),
                            icon: const Icon(Icons.share, size: 16),
                            label: Text(AppLocalizations.of(context)!.share),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Edit Image Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: Adaptive.compactFilled.copyWith(
                              minimumSize: const WidgetStatePropertyAll(
                                Size.fromHeight(42),
                              ),
                            ),
                            onPressed: _selectImage,
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: Text(
                              AppLocalizations.of(context)!.editImage,
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
          ),

          // --- Total Quantity By Unit ---
          if (_allBatches.isNotEmpty)
            Adaptive.box(
              context: context,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations.totalQuantity,
                          style: _sectionLabelStyle(context),
                        ),
                        Text(
                          _allBatches
                              .fold(0, (int sum, batch) => sum + batch.quantity)
                              .toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Group by unit and show individual totals
                    ..._allBatches
                        .fold<Map<String, int>>({}, (map, batch) {
                          map[batch.unit] =
                              (map[batch.unit] ?? 0) + batch.quantity;
                          return map;
                        })
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  entry.value.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                    const Divider(height: 20),

                    // Minimum Limit Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.minimumLimit,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _editingMinLimit
                                ? SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: _minLimitController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 6,
                                            ),
                                      ),
                                      style: context.bodyLargeText?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _minLimitController.text,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                          ],
                        ),
                        Row(
                          children: [
                            if (_editingMinLimit)
                              IconButton(
                                style: _denseIconButtonStyle,
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  // Reload the original min limit
                                  int minLimit = 0;
                                  for (var batch in _allBatches) {
                                    if (batch.minLimit > 0) {
                                      minLimit = batch.minLimit;
                                      break;
                                    }
                                  }
                                  setState(() {
                                    _minLimitController.text = minLimit
                                        .toString();
                                    _editingMinLimit = false;
                                  });
                                },
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              style: _denseIconButtonStyle,
                              icon: Icon(
                                _editingMinLimit
                                    ? Icons.check
                                    : Icons.edit_outlined,
                              ),
                              onPressed: () {
                                if (_editingMinLimit) {
                                  if (!SubscriptionGuard.ensureCanWrite(
                                    context,
                                  )) {
                                    return;
                                  }
                                  // Save the new min limit
                                  final newMinLimit =
                                      int.tryParse(_minLimitController.text) ??
                                      0;
                                  if (newMinLimit >= 0) {
                                    // Find the batch that stores minLimit and update it
                                    BoughtProduct? batchWithMinLimit;
                                    for (var batch in _allBatches) {
                                      if (batch.minLimit > 0) {
                                        batchWithMinLimit = batch;
                                        break;
                                      }
                                    }

                                    // If no batch has minLimit, use the first one
                                    batchWithMinLimit ??= _allBatches.isNotEmpty
                                        ? _allBatches.first
                                        : null;

                                    if (batchWithMinLimit != null) {
                                      FirebaseFirestore.instance
                                          .collection('purchased-products')
                                          .doc(widget.userId)
                                          .collection('items')
                                          .doc(batchWithMinLimit.id)
                                          .update({'minLimit': newMinLimit})
                                          .then((_) async {
                                            // Reload batches and purchase history to reflect changes
                                            await _loadAllBatches();
                                            await _loadPurchaseHistory();
                                            if (!context.mounted) return;
                                            setState(() {
                                              _editingMinLimit = false;
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.minimumLimitUpdated,
                                                ),
                                              ),
                                            );
                                          })
                                          .catchError((e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${AppLocalizations.of(context)!.error}: $e',
                                                ),
                                              ),
                                            );
                                          });
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.pleaseEnterAValidNumber,
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  if (!SubscriptionGuard.ensureCanWrite(
                                    context,
                                  )) {
                                    return;
                                  }
                                  setState(() {
                                    _editingMinLimit = true;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // --- 2. All Batches Card (Always show) ---
          Adaptive.box(
            context: context,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 16.0,
                left: 16.0,
                top: 12.0,
                bottom: 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _allBatches.length > 1
                        ? localizations.allBatchesFifo
                        : localizations.batchDetails,
                    style: _sectionLabelStyle(context),
                  ),

                  if (_isLoadingBatches)
                    const Center(child: CircularProgressIndicator())
                  else if (_allBatches.isEmpty)
                    Center(
                      child: Text(
                        localizations.noBatchesFound,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _allBatches.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final batch = _allBatches[index];
                        final isFirstBatch = index == 0;
                        final isLastBatch = index == _allBatches.length - 1;
                        final isExpanded = _expandedBatches[index] ?? false;
                        final scheme = Theme.of(context).colorScheme;

                        return Column(
                          children: [
                            // Batch Tile (Always visible)
                            InkWell(
                              onTap: () => setState(() {
                                _expandedBatches[index] = !isExpanded;
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Supplier name with FIFO indicator
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  batch.supplierName,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: scheme.onSurface,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isFirstBatch
                                                    ? localizations
                                                          .oldestSellFirst
                                                    : isLastBatch
                                                    ? localizations.newest
                                                    : '${localizations.batchNumber} ${index + 1}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isFirstBatch
                                                      ? Colors.orange[700]
                                                      : scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),

                                          // Quick info: Date and Quantity
                                          Text(
                                            '${batch.purchaseDate}  ·  ${batch.quantity} ${batch.unit}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₹${batch.sellingPrice.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 20,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Expanded content
                            if (isExpanded) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Quantity and Profit/Unit
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Row(
                                        children: [
                                          // Quantity
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        localizations.quantity,
                                                        style: TextStyle(
                                                          color: scheme
                                                              .onSurfaceVariant,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              '${batch.quantity} ${batch.unit}',
                                                              style: TextStyle(
                                                                color: scheme
                                                                    .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ),
                                                          IconButton(
                                                            style:
                                                                _denseIconButtonStyle,
                                                            icon: const Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                            ),
                                                            onPressed: () =>
                                                                _showEditQuantityDialog(
                                                                  batch,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Profit/Unit
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        localizations
                                                            .profitPerUnit,
                                                        style: TextStyle(
                                                          color: scheme
                                                              .onSurfaceVariant,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '₹${batch.profitMargin.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          color:
                                                              batch.profitMargin >=
                                                                  0
                                                              ? Colors
                                                                    .green[400]
                                                              : Colors.red[400],
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Row 2: Buying Price and Selling Price
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Row(
                                        children: [
                                          // Buying Price
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        localizations
                                                            .buyingPrice,
                                                        style: TextStyle(
                                                          color: scheme
                                                              .onSurfaceVariant,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '₹${batch.buyingPrice.toStringAsFixed(2)}/${batch.unit}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.red[400],
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Selling Price
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        localizations
                                                            .sellingPrice,
                                                        style: TextStyle(
                                                          color: scheme
                                                              .onSurfaceVariant,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              '₹${batch.sellingPrice.toStringAsFixed(2)}/${batch.unit}',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .green[600],
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize: 14,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                          IconButton(
                                                            style:
                                                                _denseIconButtonStyle,
                                                            icon: const Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                            ),
                                                            onPressed: () =>
                                                                _showEditSellingPriceDialog(
                                                                  batch,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (batch.expiryDate != null &&
                                        batch.expiryDate!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      _buildDetailRow(
                                        context,
                                        localizations.expiryDate,
                                        batch.expiryDate!,
                                        icon: Icons.calendar_today,
                                        valueColor: Colors.orange[700],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // --- 3. Financial Metrics Card (Current Stock) ---
          Adaptive.box(
            context: context,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.financialMetricsCurrentStock,
                    style: _sectionLabelStyle(context),
                  ),
                  const SizedBox(height: 4),

                  _buildDetailRow(
                    context,
                    localizations.totalPotentialRevenue,
                    '₹${totalPotentialRevenue.toStringAsFixed(2)}',
                    valueColor: Colors.green[600],
                  ),
                  const Divider(height: 16),

                  _buildDetailRow(
                    context,
                    localizations.totalPotentialProfit,
                    '₹${totalPotentialProfit.toStringAsFixed(2)}',
                    valueColor: Theme.of(context).colorScheme.primary,
                  ),
                  const Divider(height: 16),

                  _buildDetailRow(
                    context,
                    localizations.profitMarginPerUnit,
                    '${profitMargin.toStringAsFixed(1)}%',
                    valueColor: profitMargin >= 0
                        ? Colors.green[600]
                        : Colors.red,
                  ),
                  const Divider(height: 16),

                  _buildDetailRow(
                    context,
                    localizations.totalAmount,
                    '₹${totalInvestedAmount.toStringAsFixed(2)}',
                  ),
                  const Divider(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          context,
                          localizations.buyingPrice,
                          '₹${avgBuyingPrice.toStringAsFixed(2)}',
                        ),
                      ),
                      Expanded(
                        child: _buildDetailRow(
                          context,
                          localizations.sellingPrice,
                          '₹${avgSellingPrice.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
