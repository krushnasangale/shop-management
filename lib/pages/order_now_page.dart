import 'package:cached_network_image/cached_network_image.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/product_image_preview_page.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:material_ui/material_ui.dart';

class OrderNowPage extends StatefulWidget {
  final List<Map<String, dynamic>> orderNowProducts;

  const OrderNowPage({super.key, required this.orderNowProducts});

  @override
  State<OrderNowPage> createState() => _OrderNowPageState();
}

class _OrderNowPageState extends State<OrderNowPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  String _sortBy = 'name';
  List<Map<String, dynamic>> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = List<Map<String, dynamic>>.from(
      widget.orderNowProducts,
    );
    _searchController.addListener(_filterProducts);
    _filterProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final query = _searchController.text;
    setState(() {
      _filteredProducts = widget.orderNowProducts.where((product) {
        final name = product['productName']?.toString() ?? '';
        final supplier = product['supplierName']?.toString() ?? '';
        return SearchUtils.matchesSubsequence(name, query) ||
            SearchUtils.matchesSubsequence(supplier, query);
      }).toList();

      switch (_sortBy) {
        case 'supplier':
          _filteredProducts.sort(
            (a, b) => (a['supplierName'] as String).toLowerCase().compareTo(
              (b['supplierName'] as String).toLowerCase(),
            ),
          );
          break;
        case 'name':
        default:
          _filteredProducts.sort(
            (a, b) => (a['productName'] as String).toLowerCase().compareTo(
              (b['productName'] as String).toLowerCase(),
            ),
          );
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.orderNow ?? 'Order Now'),
        actions: [
          IconButton(
            style: Adaptive.compactIconButton,
            icon: Icon(
              _showSearchBar ? CupertinoIcons.xmark : CupertinoIcons.search,
              size: 28,
            ),
            tooltip: _showSearchBar
                ? (loc?.closeSearch ?? 'Close Search')
                : (loc?.search ?? 'Search'),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  _filterProducts();
                }
              });
            },
          ),
          AppContextMenu.iconButton(
            icon: Icons.sort,
            tooltip: loc?.sort ?? 'Sort',
            style: Adaptive.compactIconButton,
            items: () => [
              AppContextMenuItem(
                label: loc?.sortByName ?? 'Sort by Name',
                icon: Icons.inventory_2_outlined,
                selected: _sortBy == 'name',
                onPressed: () {
                  setState(() => _sortBy = 'name');
                  _filterProducts();
                },
              ),
              AppContextMenuItem(
                label: 'Sort by Supplier',
                icon: Icons.local_shipping_outlined,
                selected: _sortBy == 'supplier',
                onPressed: () {
                  setState(() => _sortBy = 'supplier');
                  _filterProducts();
                },
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (widget.orderNowProducts.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                child: Text(
                  '${(loc?.products ?? 'Products').toUpperCase()}  ·  ${_filteredProducts.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          if (_showSearchBar)
            Adaptive.searchField(
              controller: _searchController,
              query: _searchController.text,
              hint:
                  loc?.searchProductOrSupplier ?? 'Search product or supplier',
            ),
          Expanded(child: _buildList(loc, scheme)),
        ],
      ),
    );
  }

  Widget _buildList(AppLocalizations? loc, ColorScheme scheme) {
    if (_filteredProducts.isEmpty) {
      final searching = _searchController.text.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: scheme.primaryContainer,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      searching ? Icons.search_off : Icons.inventory_2_outlined,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                searching
                    ? (loc?.noResultsFound ?? 'No results found')
                    : (loc?.noProductsToOrder ?? 'No products to order'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
      children: [
        Adaptive.fullWidthGroup(
          context: context,
          children: [
            for (final product in _filteredProducts)
              _ProductTile(
                product: product,
                stockLabel: loc?.stock0 ?? 'Stock: 0',
              ),
          ],
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.stockLabel});

  final Map<String, dynamic> product;
  final String stockLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = product['productName']?.toString() ?? '';
    final supplier = product['supplierName']?.toString() ?? '';
    final unit = product['unit']?.toString() ?? '';
    final imageUrl = product['imageUrl']?.toString();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final initials = Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: scheme.onPrimaryContainer,
      ),
    );

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      minVerticalPadding: 4,
      leading: GestureDetector(
        onTap: hasImage
            ? () => AppNavigator.push(
                context,
                ProductImagePreviewPage(imageUrl: imageUrl, productName: name),
              )
            : null,
        child: ClipRRect(
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
                      child: Center(child: initials),
                    ),
                  )
                : ColoredBox(
                    color: scheme.primaryContainer,
                    child: Center(child: initials),
                  ),
          ),
        ),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: Text(
        [
          if (supplier.isNotEmpty) supplier,
          if (unit.isNotEmpty) unit,
        ].join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        stockLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.error,
        ),
      ),
    );
  }
}
