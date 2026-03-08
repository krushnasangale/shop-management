import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/services/file_service.dart';
import 'package:flashbill/pages/billing/create_new_bill.dart';
import 'package:flashbill/l10n/app_localizations.dart';

class BillProductItem {
  final String productName;
  final String supplierName;
  final String unit;
  final double quantity;
  final double price;
  final int boughtPrice;
  final double total;
  final String batchId;
  final double profitMargin;
  final int initialQuantity;
  final int order; // Order field to maintain sequence

  BillProductItem({
    required this.productName,
    required this.supplierName,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.boughtPrice,
    required this.total,
    required this.batchId,
    required this.profitMargin,
    required this.initialQuantity,
    required this.order,
  });

  double get profitTotal => quantity * profitMargin;
}

class BillSuccessPage extends StatefulWidget {
  final String customerName;
  final String customerMobile;
  final String customerVehicle;
  final int totalAmount;
  final int amountPaid;
  final int amountRemaining;
  final List<BillProductItem> products;
  final String paymentMethod;
  final String nextPaymentDate;
  final int billNumber;
  final int deliveryCharges;
  final double previousDueAmount;
  final double previousPaidAmount;
  final String previousDueDescription;

  const BillSuccessPage({
    required this.customerName,
    required this.customerMobile,
    required this.customerVehicle,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountRemaining,
    required this.products,
    this.paymentMethod = 'cash',
    this.nextPaymentDate = '',
    required this.billNumber,
    this.deliveryCharges = 0,
    this.previousDueAmount = 0.0,
    this.previousPaidAmount = 0.0,
    this.previousDueDescription = '',
    super.key,
  });

  @override
  State<BillSuccessPage> createState() => _BillSuccessPageState();
}

class _BillSuccessPageState extends State<BillSuccessPage> {
  late String customerName;
  late String customerMobile;
  late String customerVehicle;
  late int totalAmount;
  late int amountPaid;
  late int amountRemaining;
  late List<BillProductItem> products;
  late String paymentMethod;
  late String nextPaymentDate;
  late int billNumber;
  late int deliveryCharges;
  late double previousDueAmount;
  late String previousDueDescription;
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    customerName = widget.customerName;
    customerMobile = widget.customerMobile;
    customerVehicle = widget.customerVehicle;
    totalAmount = widget.totalAmount;
    amountPaid = widget.amountPaid;
    amountRemaining = widget.amountRemaining;
    products = widget.products;
    paymentMethod = widget.paymentMethod;
    nextPaymentDate = widget.nextPaymentDate;
    billNumber = widget.billNumber;
    deliveryCharges = widget.deliveryCharges;
    previousDueAmount = widget.previousDueAmount;
    previousDueDescription = widget.previousDueDescription;

    // Initialize ProfileService with current user ID
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _profileService.initialize(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final cardColor = context.cardColor;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(localizations.billCreated),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Success Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 24),

                // Success Message
                Text(
                  localizations.billCreatedSuccessfully,
                  textAlign: TextAlign.center,
                  style: context.headingLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.billSavedToSystem,
                  textAlign: TextAlign.center,
                  style: context.subtitleMedium,
                ),
                const SizedBox(height: 40),

                // Bill Status Card
                Card(
                  color: cardColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color:
                          context.secondaryTextColor?.withOpacity(0.1) ??
                          Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.billStatus,
                          style: context.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow(
                          localizations.status,
                          localizations.completed,
                          Colors.green,
                          context,
                        ),
                        const SizedBox(height: 12),
                        _buildStatusRow(
                          localizations.payment,
                          amountRemaining > 0
                              ? localizations.partial
                              : localizations.full,
                          Colors.blue,
                          context,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          child: Text(
                            localizations.goToDashboard,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 45,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          onPressed: () {
                            // Share bill functionality
                            _shareBill(context, localizations);
                          },
                          icon: const Icon(Icons.share, color: Colors.blue),
                          label: Text(
                            localizations.shareBill,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(
                        color: Colors.green,
                        width: 2,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const CreateNewBill(),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                    label: Text(
                      localizations.createNewBill,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _shareBill(BuildContext context, AppLocalizations localizations) async {
    try {
      // Show loading dialog
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
                      localizations.generatingPdf,
                      style: context.bodyLargeText,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // Fetch profile data for PDF generation
      String? ownerSignatureBase64;
      String shopName = '--';
      String ownerName = '--';
      String shopAddress = '--';
      String shopPhone = '--';
      String ownerPhone = '';

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profileData = await _profileService.getCurrentUserProfile();
        if (profileData != null) {
          ownerSignatureBase64 = profileData['ownerSignature'];
          shopName = profileData['shopName'] ?? '--';
          ownerName = profileData['ownerName'] ?? '--';
          shopAddress = profileData['shopAddress'] ?? '--';
          shopPhone = profileData['shopPhone'] ?? '--';
          ownerPhone = profileData['ownerPhone'] ?? '';
        }
      }

      // Convert products to format expected by FileService
      final productsList = products
          .map(
            (product) => {
              'name': product.productName,
              'qty': '${product.quantity} ${product.unit}',
              'price': 'Rs. ${product.price}',
              'total': 'Rs. ${product.total.toStringAsFixed(0)}',
            },
          )
          .toList();

      // Generate PDF using FileService
      final pdfBytes = await FileService.generateBillPDF(
        billNumber: billNumber,
        billId: 'BILL-$billNumber',
        customerName: customerName,
        customerMobile: customerMobile,
        customerVehicle: customerVehicle.isNotEmpty ? customerVehicle : null,
        products: productsList,
        totalAmount: totalAmount.toString(),
        amountPaid: amountPaid.toString(),
        amountRemaining: amountRemaining.toString(),
        discount: 0,
        deliveryCharges: deliveryCharges,
        nextPaymentDate: nextPaymentDate.isNotEmpty ? nextPaymentDate : null,
        previousDueAmount: previousDueAmount,
        previousPaidAmount: widget.previousPaidAmount,
        previousDueDescription: previousDueDescription,
        ownerSignatureBase64: ownerSignatureBase64,
        shopName: shopName,
        ownerName: ownerName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        ownerPhone: ownerPhone,
      );

      // Generate filename and share using FileService
      final fileName = FileService.generateTimestampedFileName(
        customerName,
        'pdf',
      );
      final result = await FileService.shareFile(
        fileBytes: pdfBytes,
        fileName: fileName,
        shareText: 'Bill from $shopName',
        subFolder: 'Bills',
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (!result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${localizations.errorGeneratingBill}: ${result.errorMessage}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.errorGeneratingBill}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusRow(
    String label,
    String value,
    Color valueColor,
    BuildContext context,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.subtitleMedium),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: context.titleMedium?.copyWith(color: valueColor),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _profileService.dispose();
    super.dispose();
  }
}
