import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';

class InvoiceReviewScreen extends StatefulWidget {
  final Map<String, dynamic> extractedData;

  const InvoiceReviewScreen({super.key, required this.extractedData});

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  late TextEditingController _supplierController;
  late TextEditingController _dateController;
  late TextEditingController _totalController;
  late List<Map<String, dynamic>> _products;
  late List<TextEditingController> _productNameControllers;
  late List<TextEditingController> _quantityControllers;
  late List<TextEditingController> _priceControllers;

  @override
  void initState() {
    super.initState();
    _supplierController = TextEditingController(
      text: widget.extractedData['supplierName'] ?? '',
    );
    _dateController = TextEditingController(
      text: widget.extractedData['date'] ?? '',
    );
    _totalController = TextEditingController(
      text: widget.extractedData['total']?.toString() ?? '',
    );

    _products = List<Map<String, dynamic>>.from(
      widget.extractedData['products'] ?? [],
    );

    _productNameControllers = _products
        .map((p) => TextEditingController(text: p['name'] ?? ''))
        .toList();
    _quantityControllers = _products
        .map(
          (p) => TextEditingController(text: p['quantity']?.toString() ?? ''),
        )
        .toList();
    _priceControllers = _products
        .map((p) => TextEditingController(text: p['price']?.toString() ?? ''))
        .toList();
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _dateController.dispose();
    _totalController.dispose();
    for (var controller in _productNameControllers) {
      controller.dispose();
    }
    for (var controller in _quantityControllers) {
      controller.dispose();
    }
    for (var controller in _priceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addProduct() {
    setState(() {
      _products.add({'name': '', 'quantity': 0, 'price': 0.0});
      _productNameControllers.add(TextEditingController());
      _quantityControllers.add(TextEditingController());
      _priceControllers.add(TextEditingController());
    });
  }

  void _removeProduct(int index) {
    setState(() {
      _productNameControllers[index].dispose();
      _quantityControllers[index].dispose();
      _priceControllers[index].dispose();

      _products.removeAt(index);
      _productNameControllers.removeAt(index);
      _quantityControllers.removeAt(index);
      _priceControllers.removeAt(index);
    });
  }

  Map<String, dynamic> _getConfirmedData() {
    return {
      'supplierName': _supplierController.text,
      'date': _dateController.text,
      'total': double.tryParse(_totalController.text) ?? 0.0,
      'products': List.generate(_products.length, (index) {
        return {
          'name': _productNameControllers[index].text,
          'quantity': int.tryParse(_quantityControllers[index].text) ?? 0,
          'price': double.tryParse(_priceControllers[index].text) ?? 0.0,
        };
      }),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Invoice Data'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Confirm', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context, _getConfirmedData());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Review and edit the extracted invoice data before confirming',
                      style: context.bodyMediumText?.copyWith(
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Supplier Name
            Text('Supplier Name', style: context.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _supplierController,
              decoration: InputDecoration(
                hintText: 'Enter supplier name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                prefixIcon: const Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),

            // Date
            Text('Date', style: context.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                hintText: 'DD/MM/YYYY',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                prefixIcon: const Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),

            // Total Amount
            Text('Total Amount', style: context.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _totalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter total amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                prefixIcon: const Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 24),

            // Products Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Products', style: context.headingMedium),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  onPressed: _addProduct,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Products List
            if (_products.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    'No products detected. Tap "Add" to add manually.',
                    style: context.bodyMediumText?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Product ${index + 1}',
                                style: context.bodyLargeText?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeProduct(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _productNameControllers[index],
                            decoration: InputDecoration(
                              labelText: 'Product Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _quantityControllers[index],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Quantity',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _priceControllers[index],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Price',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
