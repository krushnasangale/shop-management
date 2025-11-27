import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nkt/pages/billing/bill_success_page.dart';

class ReviewBillingDetails extends StatefulWidget {
  final String billDate;
  final String customerName;
  final String customerMobile;
  final String? customerVehicle;
  final String customerId;
  final List<BillProductItem> products;
  final int totalAmount;
  final bool totalAmountPaid;
  final int? amountPaid;
  final int? amountRemaining;
  final String paymentMethod;

  const ReviewBillingDetails({
    required this.billDate,
    required this.customerName,
    required this.customerMobile,
    this.customerVehicle,
    required this.customerId,
    required this.products,
    required this.totalAmount,
    required this.totalAmountPaid,
    this.amountPaid,
    this.amountRemaining,
    required this.paymentMethod,
    super.key,
  });

  @override
  State<ReviewBillingDetails> createState() => _ReviewBillingDetailsState();
}

class _ReviewBillingDetailsState extends State<ReviewBillingDetails> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: const Text('Review Bill'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Info Card
              _buildCustomerInfoCard(
                context,
                cardColor,
                primaryTextColor,
                secondaryTextColor,
              ),
              const SizedBox(height: 12),

              // Products Card
              _buildProductsCard(
                context,
                cardColor,
                primaryTextColor,
                secondaryTextColor,
              ),
              const SizedBox(height: 12),

              // Financial Summary Card
              _buildSummaryCard(
                context,
                cardColor,
                primaryTextColor,
                secondaryTextColor,
              ),

              const SizedBox(height: 12),

              // Bottom Buttons
              _buildBottomButtons(context, isDarkMode),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard(
    BuildContext context,
    Color? cardColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill Date and Payment Method in one row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'Bill Date',
                    widget.billDate,
                    Icons.calendar_month,
                    primaryTextColor,
                    secondaryTextColor,
                  ),
                ),
                // Only show payment method if amount paid is greater than 0
                if ((widget.amountPaid ?? 0) > 0)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.paymentMethod == 'cash'
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.paymentMethod == 'cash'
                              ? Colors.blue
                              : Colors.green,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Method',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.paymentMethod == 'cash' ? Icons.money : Icons.credit_card,
                                color: widget.paymentMethod == 'cash' ? Colors.blue : Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.paymentMethod == 'cash' ? 'Cash' : 'Online',
                                style: TextStyle(
                                  color: widget.paymentMethod == 'cash' ? Colors.blue : Colors.green,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Divider(color: secondaryTextColor?.withOpacity(0.3), height: 20),

            // Customer Name
            Text(
              'Customer Name',
              style: TextStyle(color: secondaryTextColor, fontSize: 14),
            ),
            Text(
              widget.customerName,
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),

            // Customer Mobile Number
            Text(
              'Customer Mobile Number',
              style: TextStyle(color: secondaryTextColor, fontSize: 14),
            ),
            Text(
              widget.customerMobile,
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            if (widget.customerVehicle != null && widget.customerVehicle!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Vehicle Number',
                    style: TextStyle(color: secondaryTextColor, fontSize: 14),
                  ),
                  Text(
                    widget.customerVehicle!,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsCard(
    BuildContext context,
    Color? cardColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Products',
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.products.length,
              separatorBuilder: (context, index) =>
                  Divider(color: secondaryTextColor?.withOpacity(0.3)),
              itemBuilder: (context, index) {
                final product = widget.products[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.productName,
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Supplier: ${product.supplierName}',
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Qty: ${product.quantity.toStringAsFixed(0)} ${product.unit}',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '₹${product.price} each',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '₹${product.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    Color? cardColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: TextStyle(
                color: primaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(color: secondaryTextColor, fontSize: 14),
                ),
                Text(
                  '₹${widget.totalAmount}',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount Paid',
                        style: TextStyle(color: secondaryTextColor, fontSize: 14),
                      ),
                      Text(
                        '₹${widget.amountPaid ?? 0}',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: secondaryTextColor?.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount Due',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₹${widget.amountRemaining ?? 0}',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: secondaryTextColor?.withOpacity(0.3)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment Status',
                    style: TextStyle(color: secondaryTextColor, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: ((widget.amountRemaining ?? 0) == 0)
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ((widget.amountRemaining ?? 0) == 0) ? 'Paid' : 'Unpaid',
                      style: TextStyle(
                        color: ((widget.amountRemaining ?? 0) == 0)
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context, bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 45,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Edit Bill',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () => _showConfirmDialog(context),
              child: const Text('Confirm Bill', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }

  void _showConfirmDialog(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Bill', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
          content: const Text(
            'Are you sure you want to create this bill?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _showLoadingAndCreateBill();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLoadingAndCreateBill() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: Dialog(
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
                      'Creating bill...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      await _saveBillToDatabase();
      if (mounted) {
        Navigator.pop(context); // Close loader
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BillSuccessPage(
              customerName: widget.customerName,
              customerMobile: widget.customerMobile,
              customerVehicle: widget.customerVehicle ?? '',
              totalAmount: widget.totalAmount,
              amountPaid: widget.totalAmountPaid ? widget.totalAmount : (widget.amountPaid ?? 0),
              amountRemaining: widget.totalAmountPaid ? 0 : (widget.amountRemaining ?? 0),
              products: widget.products,
              paymentMethod: widget.paymentMethod,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveBillToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final database = FirebaseDatabase.instance;
    final userId = user.uid;
    final billId = database.ref('bills/$userId').push().key;

    if (billId == null) throw Exception('Failed to generate bill ID');

    // Prepare bill data
    final actualAmountPaid = widget.totalAmountPaid ? widget.totalAmount : (widget.amountPaid ?? 0);
    final actualAmountRemaining = widget.totalAmountPaid ? 0 : (widget.amountRemaining ?? 0);
    
    final billData = {
      'billId': billId,
      'customerId': widget.customerId, // Add customerId for efficient customer history fetching
      'billDate': widget.billDate,
      'customerName': widget.customerName,
      'customerMobile': widget.customerMobile,
      'customerVehicle': widget.customerVehicle ?? '',
      'totalAmount': widget.totalAmount,
      'totalAmountPaid': widget.totalAmountPaid,
      'amountPaid': actualAmountPaid,
      'amountRemaining': actualAmountRemaining,
      'paymentMethod': widget.paymentMethod,
      'timestamp': DateTime.now().toIso8601String(),
      'products': {
        for (int i = 0; i < widget.products.length; i++)
          'product_$i': {
            'productName': widget.products[i].productName,
            'supplierName': widget.products[i].supplierName,
            'unit': widget.products[i].unit,
            'quantity': widget.products[i].quantity,
            'price': widget.products[i].price,
            'boughtPrice': widget.products[i].boughtPrice,
            'total': widget.products[i].total,
          }
      },
      'payments': [
        {
          'amount': actualAmountPaid,
          'date': widget.billDate,
          'method': widget.paymentMethod,
        }
      ],
    };

    // Save bill to bills table only (with customerId for efficient querying)
    await database.ref('bills/$userId/$billId').set(billData);

    // Update product quantities in purchased-products
    for (final product in widget.products) {
      final productsRef = database.ref('purchased-products/$userId');
      final snapshot = await productsRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        for (final entry in data.entries) {
          final productData = entry.value as Map<dynamic, dynamic>;
          final productName = productData['productName'] as String?;
          final supplierName = productData['supplierName'] as String?;

          // Match by both product name and supplier name
          if (productName == product.productName && supplierName == product.supplierName) {
            final productId = entry.key as String;
            final currentQty = productData['quantity'] as int? ?? 0;
            final newQty = (currentQty - product.quantity.toInt()).toInt();
            
            // Update quantity or delete if quantity becomes 0 or negative
            if (newQty <= 0) {
              await database.ref('purchased-products/$userId/$productId').remove();
            } else {
              await database.ref('purchased-products/$userId/$productId/quantity').set(newQty);
            }
            break; // Found and updated, move to next product
          }
        }
      }
    }
  }
}
