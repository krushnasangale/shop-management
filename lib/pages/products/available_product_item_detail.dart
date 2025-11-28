import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:flashbill/pages/products/available_products.dart';

class AvailableProductDetailScreen extends StatefulWidget {
  final BoughtProduct product;
  final String userId; // Pass userId for correct database path

  const AvailableProductDetailScreen({super.key, required this.product, required this.userId});

  @override
  State<AvailableProductDetailScreen> createState() => _AvailableProductDetailScreenState();
}

class _AvailableProductDetailScreenState extends State<AvailableProductDetailScreen> {
  // Local state for editable fields
  late TextEditingController _quantityController;
  late TextEditingController _sellingPriceController;
  late DatabaseReference _productRef;
  bool _isEditingQuantity = false;
  bool _isEditingPrice = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize Database Reference to the specific product item
    _productRef = FirebaseDatabase.instance.ref(
      'purchased-products/${widget.userId}/${widget.product.id}',
    );
    
    // Initialize controllers with current product values
    _quantityController = TextEditingController(text: widget.product.quantity.toString());
    _sellingPriceController = TextEditingController(text: widget.product.sellingPrice.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _sellingPriceController.dispose();
    super.dispose();
  }

  // --- DATABASE UPDATE FUNCTION ---
  Future<void> _updateProductField(String key, dynamic value) async {
    try {
      await _productRef.update({key: value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$key updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating $key: $e')),
        );
      }
    }
  }

  // --- SAVE FUNCTIONS ---
  Future<void> _saveQuantity() async {
    final newValue = _quantityController.text.trim();
    final quantity = int.tryParse(newValue);
    
    if (quantity != null && quantity > 0) {
      await _updateProductField('quantity', quantity);
      setState(() {
        _isEditingQuantity = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
    }
  }

  Future<void> _saveSellingPrice() async {
    final newValue = _sellingPriceController.text.trim();
    final price = double.tryParse(newValue);
    
    if (price != null && price > 0) {
      await _updateProductField('sellingPrice', price);
      setState(() {
        _isEditingPrice = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
    }
  }

  // --- FINANCIAL CALCULATIONS (Same as before) ---
  double get currentStockQty => double.tryParse(_quantityController.text) ?? 0.0;
  double get currentSellingPrice => double.tryParse(_sellingPriceController.text) ?? widget.product.sellingPrice;

  double get totalPotentialRevenue => currentStockQty * currentSellingPrice;
  double get totalPotentialProfit => currentStockQty * (currentSellingPrice - widget.product.buyingPrice);
  double get profitMargin {
    if (widget.product.buyingPrice <= 0) return 0.0;
    return ((currentSellingPrice - widget.product.buyingPrice) / widget.product.buyingPrice) * 100;
  }
  
  // --- UI BUILDERS (Same as before) ---
  Widget _buildDetailRow(BuildContext context, String title, String subtitle, {IconData? icon, Color? valueColor}) {
    // ... (implementation remains the same) ...
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: secondaryTextColor, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: secondaryTextColor, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: valueColor ?? primaryTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    BuildContext context,
    String label,
    TextEditingController controller,
    String unitOrPrefix,
    bool isEditing,
    VoidCallback onEdit,
    VoidCallback onSave,
    VoidCallback onCancel,
  ) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          if (!isEditing)
            GestureDetector(
              onTap: onEdit,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$unitOrPrefix ${controller.text}',
                    style: TextStyle(
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  Icon(Icons.edit, color: Colors.blue, size: 20),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: unitOrPrefix == '₹' 
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter $label',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: onCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          Divider(color: secondaryTextColor!.withOpacity(0.3)),
        ],
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;
    final unit = widget.product.unit;
    
    // Capitalize product name for display
    final displayedProductName = widget.product.productName[0].toUpperCase() + widget.product.productName.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(displayedProductName),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // Confirm deletion
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Delete Product', style: TextStyle(color: primaryTextColor),),
                  content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await _productRef.remove();
                          if (mounted) {
                            Navigator.of(context).pop(); // Close dialog
                            Navigator.of(context).pop(); // Go back after deletion
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Product deleted successfully.')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop(); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting product: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // --- 1. Editable Stock & Price Card ---
                  Card(
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventory Management',
                            style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          
                          // Editable Quantity Field
                          _buildEditableField(
                            context,
                            'Current Stock',
                            _quantityController,
                            unit,
                            _isEditingQuantity,
                            () => setState(() => _isEditingQuantity = true),
                            _saveQuantity,
                            () => setState(() {
                              _quantityController.text = widget.product.quantity.toString();
                              _isEditingQuantity = false;
                            }),
                          ),
                          
                          // Editable Selling Price Field
                          _buildEditableField(
                            context,
                            'Selling Price per $unit',
                            _sellingPriceController,
                            '₹',
                            _isEditingPrice,
                            () => setState(() => _isEditingPrice = true),
                            _saveSellingPrice,
                            () => setState(() {
                              _sellingPriceController.text = widget.product.sellingPrice.toStringAsFixed(2);
                              _isEditingPrice = false;
                            }),
                          ),
                          
                          // Non-editable Buying Price
                          _buildDetailRow(
                            context,
                            'Buying Price (Cost)',
                            '₹${widget.product.buyingPrice.toStringAsFixed(2)} / $unit',
                            icon: Icons.attach_money,
                            valueColor: Colors.red[400],
                          ),
                          
                          // Minimum Limit Display
                          _buildDetailRow(
                            context,
                            'Minimum Limit',
                            '${widget.product.minLimit} $unit',
                            icon: Icons.warning_outlined,
                            valueColor: Colors.orange[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // --- 2. Financial Summary Card ---
                  Card(
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Financial Metrics (Current Stock)',
                            style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          
                          _buildDetailRow(
                            context,
                            'Total Potential Revenue',
                            '₹${totalPotentialRevenue.toStringAsFixed(2)}',
                            icon: Icons.trending_up,
                            valueColor: Colors.green,
                          ),
                          Divider(),
                          
                          _buildDetailRow(
                            context,
                            'Total Potential Profit',
                            '₹${totalPotentialProfit.toStringAsFixed(2)}',
                            icon: Icons.paid_outlined,
                            valueColor: Colors.blue,
                          ),
                          Divider(),
                          
                          _buildDetailRow(
                            context,
                            'Profit Margin (per unit)',
                            '${profitMargin.toStringAsFixed(1)}%',
                            icon: Icons.percent,
                            valueColor: profitMargin >= 0 ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // --- 3. Purchase History & Source Card ---
                  Card(
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchase Source & History',
                            style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          
                          _buildDetailRow(
                            context,
                            'Initial Purchase Date',
                            widget.product.date,
                            icon: Icons.calendar_today,
                          ),
                          Divider(),
                          
                          _buildDetailRow(
                            context,
                            'Supplier Name',
                            widget.product.supplierName,
                            icon: Icons.factory_outlined,
                          ),
                          Divider(),
                          
                          _buildDetailRow(
                            context,
                            'Initial Quantity Bought',
                            '${widget.product.quantity} ${widget.product.unit}',
                            icon: Icons.storage,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
