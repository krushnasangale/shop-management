import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/pages/billing/create_new_bill.dart';
import 'package:flashbill/services/file_service.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:material_ui/material_ui.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final paymentLabel = amountRemaining > 0
        ? localizations.partial
        : localizations.full;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(localizations.billCreated),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: scheme.primaryContainer,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(
                      Icons.check_rounded,
                      size: 28,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    localizations.billCreatedSuccessfully,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizations.billSavedToSystem,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  _SummaryTile(
                    icon: Icons.person_outline,
                    label: localizations.customer,
                    value: customerName,
                  ),
                  const SizedBox(width: 8),
                  _SummaryTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: localizations.total,
                    value: '₹$totalAmount',
                    valueColor: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _SummaryTile(
                    icon: Icons.verified_outlined,
                    label: localizations.status,
                    value: localizations.completed,
                    valueColor: scheme.primary,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionLabel(context, localizations.billStatus),
            ),
            Adaptive.fullWidthGroup(
              bordered: true,
              context: context,
              children: [
                _infoTile(
                  icon: Icons.check_circle_outline,
                  label: localizations.status,
                  value: localizations.completed,
                  valueColor: scheme.primary,
                ),
                _infoTile(
                  icon: Icons.payments_outlined,
                  label: localizations.payment,
                  value: paymentLabel,
                ),
                _infoTile(
                  icon: Icons.person_outline,
                  label: localizations.customerName,
                  value: customerName,
                ),
                _infoTile(
                  icon: Icons.receipt_long_outlined,
                  label: localizations.totalAmount,
                  value: '₹$totalAmount',
                  valueColor: scheme.primary,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    style: Adaptive.compactFilled,
                    onPressed: () => _shareBill(context, localizations),
                    icon: const Icon(Icons.share_outlined, size: 20),
                    label: Text(localizations.shareBill),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: Adaptive.compactOutlined,
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const CreateNewBill(),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: Text(localizations.createNewBill),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: Adaptive.compactOutlined,
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst);
                    },
                    child: Text(localizations.goToDashboard),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareBill(BuildContext context, AppLocalizations localizations) async {
    final scheme = Theme.of(context).colorScheme;
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
              child: Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Adaptive.progress(color: scheme.primary),
                      const SizedBox(height: 16),
                      Text(localizations.generatingPdf),
                    ],
                  ),
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

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        if (!result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${localizations.errorGeneratingBill}: ${result.errorMessage}',
              ),
              backgroundColor: scheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.errorGeneratingBill}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      minVerticalPadding: 4,
      leading: _squareIcon(icon, scheme),
      title: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: valueColor ?? scheme.onSurface,
        ),
      ),
      subtitle: Text(label),
    );
  }

  @override
  void dispose() {
    _profileService.dispose();
    super.dispose();
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _squareIcon(icon, scheme),
              const SizedBox(height: 8),
              Text(
                label,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
