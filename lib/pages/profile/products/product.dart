import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flashbill/services/image_upload_service.dart';
import 'package:flashbill/utils/search_utils.dart';

class Product {
  final String id;
  final String name;
  final String? imageUrl;

  Product({required this.id, required this.name, this.imageUrl});

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {'name': name, 'imageUrl': imageUrl};
  }

  // Create from Map
  factory Product.fromMap(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'],
    );
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
  final ScrollController _scrollController = ScrollController();
  final int _itemsPerPage = 100;
  int _currentlyLoadedItems = 0; // Will be set properly in filterProducts
  bool _isLoadingMore = false;

  // Controllers for the Add Product Popup
  final TextEditingController _productNameController = TextEditingController();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterProducts);
    _scrollController.addListener(_onScroll);
    _getUserAndLoadProducts();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _productsSubscription?.cancel();
    super.dispose();
  }

  // Handle scroll events for infinite loading
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreItems();
    }
  }

  // Load more items when scrolled near bottom
  void _loadMoreItems() {
    if (_isLoadingMore || _currentlyLoadedItems >= _filteredProducts.length) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    // Simulate loading delay for smooth UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          final remainingItems =
              _filteredProducts.length - _currentlyLoadedItems;
          final itemsToLoad = _itemsPerPage.clamp(0, remainingItems);
          _currentlyLoadedItems += itemsToLoad;
          _isLoadingMore = false;
        });
      }
    });
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

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    await ImageUploadService.deleteImageByUrl(imageUrl);
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

      // Sort products alphabetically by name (A to Z)
      loadedProducts.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

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
    _searchQuery = _searchController.text;
    if (!mounted) return;
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products
            .where(
              (product) =>
                  SearchUtils.matchesSubsequence(product.name, _searchQuery),
            )
            .toList();
      }
      // Reset pagination when filtering
      _currentlyLoadedItems = _itemsPerPage.clamp(0, _filteredProducts.length);
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.productNames ?? 'Product Names'),
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
                  hintText:
                      localizations?.searchProducts ?? 'Search products...',
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
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _currentlyLoadedItems + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _currentlyLoadedItems) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final product = _filteredProducts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: product.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: product.imageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
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
                      ),
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
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onPressed: _showAddProductPopup,
        backgroundColor: const Color(0xFF2196F3),
        tooltip: localizations?.addProductName ?? 'Add Product Name',
        child: const Icon(Icons.add, color: Colors.white, size: 45),
      ),
    );
  }

  void _showAddProductPopup() {
    final localizations = AppLocalizations.of(context);
    _productNameController.clear();
    _selectedImage = null;
    bool isUploading = false;
    double uploadProgress = 0.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              localizations?.addProductName ?? 'Add Product Name',
              style: context.bodyLargeText,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Name Field
                  TextField(
                    controller: _productNameController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (value) {
                      if (value != value.toUpperCase()) {
                        _productNameController.text = value.toUpperCase();
                        _productNameController.selection =
                            TextSelection.fromPosition(
                              TextPosition(offset: value.toUpperCase().length),
                            );
                      }
                    },
                    decoration: InputDecoration(
                      labelText: localizations?.productName ?? 'Product Name',
                      hintText:
                          localizations?.enterProductName ??
                          'Enter product name',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
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
                            setState(() {
                              _selectedImage = file;
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
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedImage!,
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
                      if (_selectedImage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
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
                child: Text(localizations?.cancel ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (_productNameController.text.isNotEmpty) {
                          setState(() {
                            isUploading = true;
                          });
                          try {
                            // Create product document first to get ID
                            final docRef = await _productsRef.add({
                              'name': _productNameController.text.trim(),
                            });

                            // Upload image if selected
                            String? imageUrl;
                            if (_selectedImage != null) {
                              imageUrl =
                                  await ImageUploadService.uploadProductImage(
                                    userId: _userId,
                                    productId: docRef.id,
                                    image: _selectedImage,
                                    deleteOldImage: false,
                                    onProgress: (progress) {
                                      setState(() {
                                        uploadProgress = progress;
                                      });
                                    },
                                  );
                              if (imageUrl != null) {
                                await docRef.update({'imageUrl': imageUrl});
                              }
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              _selectedImage = null;
                            }
                          } catch (e) {
                            setState(() {
                              isUploading = false;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${localizations?.errorAddingProduct ?? 'Error adding product'}: $e',
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
                    : Text(localizations?.add ?? 'Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProductPopup(Product product) {
    final localizations = AppLocalizations.of(context);
    final nameController = TextEditingController(text: product.name);
    File? editSelectedImage;
    bool isUploadingImage = false;
    bool removeImage = false;
    double uploadProgress = 0.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              localizations?.editProductName ?? 'Edit Product Name',
              style: context.bodyLargeText,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Product Name Field
                  TextField(
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
                    decoration: InputDecoration(
                      labelText: localizations?.productName ?? 'Product Name',
                      hintText:
                          localizations?.enterProductName ??
                          'Enter product name',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
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
                            setState(() {
                              editSelectedImage = file;
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
                          child: editSelectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    editSelectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : product.imageUrl != null && !removeImage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: product.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
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
                      Row(
                        children: [
                          if (editSelectedImage != null ||
                              (product.imageUrl != null && !removeImage))
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton.icon(
                                  onPressed: () async {
                                    // Delete existing image from storage if it exists
                                    if (product.imageUrl != null &&
                                        !removeImage) {
                                      await _deleteImageFromStorage(
                                        product.imageUrl!,
                                      );
                                    }
                                    setState(() {
                                      editSelectedImage = null;
                                      removeImage = true;
                                    });
                                  },
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Remove Image'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(localizations?.cancel ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: isUploadingImage
                    ? null
                    : () async {
                        if (nameController.text.isNotEmpty) {
                          try {
                            setState(() {
                              isUploadingImage = true;
                            });

                            // Prepare update data
                            final updateData = {
                              'name': nameController.text.trim(),
                            };

                            // Handle image update
                            if (editSelectedImage != null) {
                              // Upload new image
                              final imageUrl =
                                  await ImageUploadService.uploadProductImage(
                                    userId: _userId,
                                    productId: product.id,
                                    image: editSelectedImage,
                                    deleteOldImage: false,
                                    onProgress: (progress) {
                                      setState(() {
                                        uploadProgress = progress;
                                      });
                                    },
                                  );
                              if (imageUrl != null) {
                                updateData['imageUrl'] = imageUrl;
                              }
                            } else if (!removeImage &&
                                product.imageUrl != null) {
                              // Keep existing image only if not removing
                              updateData['imageUrl'] = product.imageUrl!;
                            }
                            // If removeImage is true or no image exists, no imageUrl field

                            await _productsRef
                                .doc(product.id)
                                .update(updateData);

                            setState(() {
                              isUploadingImage = false;
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            setState(() {
                              isUploadingImage = false;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${localizations?.errorUpdatingProduct ?? 'Error updating product'}: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                child: isUploadingImage
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
                    : Text(localizations?.save ?? 'Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Product product) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations?.deleteProduct ?? 'Delete Product'),
          content: Text(
            '${localizations?.confirmDeleteProduct ?? 'Are you sure you want to delete'} ${product.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations?.cancel ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  // Delete associated image from storage if it exists
                  if (product.imageUrl != null) {
                    await _deleteImageFromStorage(product.imageUrl!);
                  }

                  await _productsRef.doc(product.id).delete();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${localizations?.errorDeletingProduct ?? 'Error deleting product'}: $e',
                        ),
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(localizations?.delete ?? 'Delete'),
            ),
          ],
        );
      },
    );
  }
}
