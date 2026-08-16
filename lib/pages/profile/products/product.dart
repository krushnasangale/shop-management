import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/product_image_preview_page.dart';
import 'package:flashbill/services/image_upload_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flashbill/services/subscription_guard.dart';

class Product {
  final String id;
  final String name;
  final String? imageUrl;

  Product({required this.id, required this.name, this.imageUrl});

  Map<String, dynamic> toMap() {
    return {'name': name, 'imageUrl': imageUrl};
  }

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
  String _userId = '';
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late TextEditingController _searchController;
  StreamSubscription<QuerySnapshot>? _productsSubscription;
  final ScrollController _scrollController = ScrollController();
  final int _itemsPerPage = 100;
  int _currentlyLoadedItems = 0;
  bool _isLoadingMore = false;
  bool _showSearchBar = false;

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
    _searchController.dispose();
    _scrollController.dispose();
    _productsSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore || _currentlyLoadedItems >= _filteredProducts.length) {
      return;
    }

    setState(() => _isLoadingMore = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        final remaining = _filteredProducts.length - _currentlyLoadedItems;
        _currentlyLoadedItems += _itemsPerPage.clamp(0, remaining);
        _isLoadingMore = false;
      });
    });
  }

  List<Product> _applyFilter(List<Product> products, String query) {
    if (query.isEmpty) return products;
    return products
        .where((product) => SearchUtils.matchesSubsequence(product.name, query))
        .toList();
  }

  void _filterProducts() {
    setState(() {
      _searchQuery = _searchController.text;
      _filteredProducts = _applyFilter(_products, _searchQuery);
      _currentlyLoadedItems = _itemsPerPage.clamp(0, _filteredProducts.length);
      _isLoadingMore = false;
    });
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
      if (!mounted) return;
      final loadedProducts = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromMap(doc.id, data);
      }).toList();
      loadedProducts.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      setState(() {
        _products = loadedProducts;
        _filteredProducts = _applyFilter(
          loadedProducts,
          _searchController.text,
        );
        _currentlyLoadedItems = _itemsPerPage.clamp(
          0,
          _filteredProducts.length,
        );
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc?.productNames ?? 'Product Names';

    if (Adaptive.isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _toggleSearch,
                child: Icon(
                  _showSearchBar ? CupertinoIcons.xmark : CupertinoIcons.search,
                  size: 28,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.only(left: 8),
                onPressed: () => _showProductForm(),
                child: const Icon(CupertinoIcons.add, size: 32),
              ),
            ],
          ),
        ),
        child: SafeArea(child: _buildBody(loc)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            style: Adaptive.compactIconButton,
            icon: Icon(
              _showSearchBar ? Icons.close : Icons.search,
              size: 28,
            ),
            onPressed: _toggleSearch,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, size: 32),
              tooltip: loc?.addProductName ?? 'Add Product Name',
              onPressed: () => _showProductForm(),
            ),
          ),
        ],
      ),
      body: _buildBody(loc),
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) _searchController.clear();
    });
  }

  Widget _buildBody(AppLocalizations? loc) {
    if (_isLoading) {
      return Center(child: Adaptive.progress());
    }

    return Column(
      children: [
        if (_showSearchBar)
          Adaptive.searchField(
            controller: _searchController,
            query: _searchQuery,
            hint: loc?.searchProducts ?? 'Search products...',
          ),
        Expanded(
          child: _filteredProducts.isEmpty
              ? _EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: _searchQuery.isEmpty
                      ? 'No products yet. Add one to get started!'
                      : 'No products found for "$_searchQuery"',
                )
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
                  children: [
                    Adaptive.fullWidthGroup(
                      context: context,
                      children: [
                        for (final product in _filteredProducts.take(
                          _currentlyLoadedItems,
                        ))
                          _ProductTile(
                            product: product,
                            onEdit: () => _showProductForm(product: product),
                            onDelete: () => _confirmDelete(product),
                            editLabel: loc?.edit ?? 'Edit',
                            deleteLabel: loc?.delete ?? 'Delete',
                          ),
                      ],
                    ),
                    if (_isLoadingMore)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(child: Adaptive.progress()),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showProductForm({Product? product}) async {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final loc = AppLocalizations.of(context);
    final result = await Adaptive.showSheet<_ProductFormResult>(
      context: context,
      builder: (sheetContext) {
        return _ProductFormSheet(
          title: product == null
              ? (loc?.addProductName ?? 'Add Product Name')
              : (loc?.editProductName ?? 'Edit Product Name'),
          saveLabel: product == null
              ? (loc?.add ?? 'Add')
              : (loc?.save ?? 'Save'),
          cancelLabel: loc?.cancel ?? 'Cancel',
          nameLabel: loc?.productName ?? 'Product Name',
          nameHint: loc?.enterProductName ?? 'Enter product name',
          initialName: product?.name ?? '',
          existingImageUrl: product?.imageUrl,
        );
      },
    );
    if (result == null) return;

    if (product == null) {
      await _addProduct(result, loc);
    } else {
      await _updateProduct(product, result, loc);
    }
  }

  Future<void> _addProduct(
    _ProductFormResult result,
    AppLocalizations? loc,
  ) async {
    try {
      final docRef = await _productsRef.add({'name': result.name});
      if (result.imageFile != null) {
        final imageUrl = await ImageUploadService.uploadProductImage(
          userId: _userId,
          productId: docRef.id,
          image: result.imageFile,
          deleteOldImage: false,
        );
        if (imageUrl != null) {
          await docRef.update({'imageUrl': imageUrl});
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc?.errorAddingProduct ?? 'Error adding product'}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _updateProduct(
    Product product,
    _ProductFormResult result,
    AppLocalizations? loc,
  ) async {
    try {
      final updateData = <String, dynamic>{'name': result.name};
      if (result.imageFile != null) {
        final imageUrl = await ImageUploadService.uploadProductImage(
          userId: _userId,
          productId: product.id,
          image: result.imageFile,
          deleteOldImage: false,
        );
        if (imageUrl != null) {
          updateData['imageUrl'] = imageUrl;
        }
      } else if (result.removeImage) {
        if (product.imageUrl != null) {
          await ImageUploadService.deleteImageByUrl(product.imageUrl!);
        }
        updateData['imageUrl'] = FieldValue.delete();
      } else if (product.imageUrl != null) {
        updateData['imageUrl'] = product.imageUrl;
      }
      await _productsRef.doc(product.id).update(updateData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc?.errorUpdatingProduct ?? 'Error updating product'}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(Product product) async {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final loc = AppLocalizations.of(context);
    final confirmed = Adaptive.isCupertino
        ? await showCupertinoDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return CupertinoAlertDialog(
                title: Text(loc?.deleteProduct ?? 'Delete Product'),
                content: Text(
                  '${loc?.confirmDeleteProduct ?? 'Are you sure you want to delete'} ${product.name}?',
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(loc?.cancel ?? 'Cancel'),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(loc?.delete ?? 'Delete'),
                  ),
                ],
              );
            },
          )
        : await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: Text(loc?.deleteProduct ?? 'Delete Product'),
                content: Text(
                  '${loc?.confirmDeleteProduct ?? 'Are you sure you want to delete'} ${product.name}?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(loc?.cancel ?? 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: Text(loc?.delete ?? 'Delete'),
                  ),
                ],
              );
            },
          );

    if (confirmed != true) return;
    try {
      if (product.imageUrl != null) {
        await ImageUploadService.deleteImageByUrl(product.imageUrl!);
      }
      await _productsRef.doc(product.id).delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc?.errorDeletingProduct ?? 'Error deleting product'}: $e',
          ),
        ),
      );
    }
  }
}

class _ProductFormResult {
  const _ProductFormResult({
    required this.name,
    this.imageFile,
    this.removeImage = false,
  });

  final String name;
  final File? imageFile;
  final bool removeImage;
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.editLabel,
    required this.deleteLabel,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editLabel;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nameStyle = TextStyle(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    );
    final initials = Text(
      product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: scheme.onPrimaryContainer,
      ),
    );
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 36,
        height: 36,
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: product.imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => ColoredBox(
                  color: scheme.primaryContainer,
                  child: Center(child: initials),
                ),
              )
            : ColoredBox(
                color: scheme.primaryContainer,
                child: Center(child: initials),
              ),
      ),
    );

    void openPreview() {
      AppNavigator.push(
        context,
        ProductImagePreviewPage(
          imageUrl: product.imageUrl!,
          productName: product.name,
        ),
      );
    }

    final imageButton = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasImage ? openPreview : onEdit,
        borderRadius: BorderRadius.circular(8),
        child: avatar,
      ),
    );

    final name = Text(
      product.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nameStyle,
    );

    if (Adaptive.isCupertino) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        child: Row(
          children: [
            GestureDetector(
              onTap: hasImage ? openPreview : onEdit,
              child: avatar,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: name,
                ),
              ),
            ),
            AppContextMenu.iconButton(
              dense: true,
              width: 168,
              items: () => [
                AppContextMenuItem(
                  label: editLabel,
                  icon: CupertinoIcons.pencil,
                  onPressed: onEdit,
                ),
                AppContextMenuItem(
                  label: deleteLabel,
                  icon: CupertinoIcons.delete,
                  onPressed: onDelete,
                  destructive: true,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
      child: Row(
        children: [
          imageButton,
          Expanded(
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.fromLTRB(12, 0, 0, 0),
              minVerticalPadding: 4,
              title: name,
              onTap: onEdit,
              trailing: AppContextMenu.iconButton(
                dense: true,
                width: 168,
                items: () => [
                  AppContextMenuItem(
                    label: editLabel,
                    icon: CupertinoIcons.pencil,
                    onPressed: onEdit,
                  ),
                  AppContextMenuItem(
                    label: deleteLabel,
                    icon: CupertinoIcons.delete,
                    onPressed: onDelete,
                    destructive: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({
    required this.title,
    required this.saveLabel,
    required this.cancelLabel,
    required this.nameLabel,
    required this.nameHint,
    required this.initialName,
    this.existingImageUrl,
  });

  final String title;
  final String saveLabel;
  final String cancelLabel;
  final String nameLabel;
  final String nameHint;
  final String initialName;
  final String? existingImageUrl;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  late final TextEditingController _nameController;
  File? _imageFile;
  bool _removeImage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _upper() {
    final value = _nameController.text;
    final upper = value.toUpperCase();
    if (value != upper) {
      _nameController.value = _nameController.value.copyWith(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
  }

  Future<void> _pickImage() async {
    final source = await _chooseImageSource();
    if (source == null) return;
    final image = await ImagePicker().pickImage(source: source);
    if (image == null) return;
    setState(() {
      _imageFile = File(image.path);
      _removeImage = false;
    });
  }

  Future<ImageSource?> _chooseImageSource() {
    if (Adaptive.isCupertino) {
      return showCupertinoModalPopup<ImageSource>(
        context: context,
        builder: (sheetContext) {
          return CupertinoActionSheet(
            title: Text(
              AppLocalizations.of(sheetContext)?.chooseImageSource ??
                  'Choose Image Source',
            ),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () =>
                    Navigator.pop(sheetContext, ImageSource.camera),
                child: Text(
                  AppLocalizations.of(sheetContext)?.camera ?? 'Camera',
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () =>
                    Navigator.pop(sheetContext, ImageSource.gallery),
                child: Text(
                  AppLocalizations.of(sheetContext)?.gallery ?? 'Gallery',
                ),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(
                AppLocalizations.of(sheetContext)?.cancel ?? 'Cancel',
              ),
            ),
          );
        },
      );
    }

    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product image',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how to add an image',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          child: const Icon(Icons.camera_alt_outlined),
                        ),
                        title: Text(
                          AppLocalizations.of(sheetContext)?.camera ?? 'Camera',
                        ),
                        subtitle: Text(
                          AppLocalizations.of(sheetContext)?.takeAPhoto ??
                              'Take a photo',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            Navigator.pop(sheetContext, ImageSource.camera),
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          child: const Icon(Icons.image_outlined),
                        ),
                        title: Text(
                          AppLocalizations.of(sheetContext)?.gallery ??
                              'Gallery',
                        ),
                        subtitle: Text(
                          AppLocalizations.of(sheetContext)
                                  ?.chooseExistingPhoto ??
                              'Choose an existing photo',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            Navigator.pop(sheetContext, ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    Navigator.pop(
      context,
      _ProductFormResult(
        name: name,
        imageFile: _imageFile,
        removeImage: _removeImage,
      ),
    );
  }

  bool get _hasPreview =>
      _imageFile != null || (widget.existingImageUrl != null && !_removeImage);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final preview = GestureDetector(
      onTap: _pickImage,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: SizedBox(
          height: 140,
          width: double.infinity,
          child: _imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_imageFile!, fit: BoxFit.cover),
                )
              : widget.existingImageUrl != null && !_removeImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: widget.existingImageUrl!,
                    fit: BoxFit.cover,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 36,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to select image',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
        ),
      ),
    );

    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (Adaptive.isCupertino)
          CupertinoTextFormFieldRow(
            controller: _nameController,
            prefix: Text(widget.nameLabel),
            placeholder: widget.nameHint,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => _upper(),
          )
        else
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => _upper(),
            decoration: Adaptive.compactField(
              label: widget.nameLabel,
              hint: widget.nameHint,
              icon: Icons.inventory_2_outlined,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Product Image (Optional)',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        preview,
        if (_hasPreview)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _imageFile = null;
                  _removeImage = true;
                });
              },
              child: Text(
                AppLocalizations.of(context)?.removeImage ?? 'Remove Image',
              ),
            ),
          ),
      ],
    );

    if (Adaptive.isCupertino) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Material(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoNavigationBar(
                    automaticallyImplyLeading: false,
                    middle: Text(widget.title),
                    leading: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.cancelLabel),
                    ),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _save,
                      child: Text(widget.saveLabel),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: fields,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              fields,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: Adaptive.compactOutlined,
                      child: Text(widget.cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: Adaptive.compactFilled,
                      child: Text(widget.saveLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
