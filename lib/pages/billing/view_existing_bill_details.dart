import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/services/bills_data_service.dart';
import 'package:flashbill/services/file_service.dart';
import 'package:flashbill/pages/billing/create_new_bill.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:printing/printing.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flashbill/services/subscription_guard.dart';

// --- Payment Record Model ---
class PaymentRecord {
  final int amount;
  final String date;
  final String paymentMethod;

  PaymentRecord({
    required this.amount,
    required this.date,
    required this.paymentMethod,
  });

  factory PaymentRecord.fromMap(Map<dynamic, dynamic> map) {
    return PaymentRecord(
      amount: map['amount'] ?? 0,
      date: map['date'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'cash',
    );
  }

  Map<String, dynamic> toMap() {
    return {'amount': amount, 'date': date, 'paymentMethod': paymentMethod};
  }
}

// PDF Preview Page
class BillPdfPreviewPage extends StatefulWidget {
  final File pdfFile;
  final String customerName;

  const BillPdfPreviewPage({
    super.key,
    required this.pdfFile,
    required this.customerName,
  });

  @override
  State<BillPdfPreviewPage> createState() => _BillPdfPreviewPageState();
}

// Helper function for sharing with loading dialog
Future<void> _shareWithLoadingDialog({
  required BuildContext context,
  required Future<FileResult> Function() shareFunction,
  String loadingMessage = 'Generating PDF...',
  String errorPrefix = 'Error sharing file',
}) async {
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
                    loadingMessage,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Execute share function
    final result = await shareFunction();

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog

      // Show error if sharing failed
      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.failedToShare ?? 'Failed to share'}: ${result.errorMessage}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$errorPrefix: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _BillPdfPreviewPageState extends State<BillPdfPreviewPage> {
  late pdfx.PdfController _pdfController;
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _pdfController = pdfx.PdfController(
      document: pdfx.PdfDocument.openFile(widget.pdfFile.path),
    );

    // Initialize ProfileService
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _profileService.initialize(user.uid);
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    _profileService.dispose();
    super.dispose();
  }

  Future<void> _shareBill(BuildContext context) async {
    await _shareWithLoadingDialog(
      context: context,
      loadingMessage:
          AppLocalizations.of(context)?.sharingPdf ?? 'Sharing PDF...',
      shareFunction: () async {
        // Fetch shop name from profile
        String shopName = 'Shop';
        try {
          final profileData = await _profileService.getCurrentUserProfile();
          if (profileData != null) {
            shopName = profileData['shopName'] ?? 'Shop';
          }
        } catch (e) {
          appLog('Error fetching shop name: $e');
        }

        return await FileService.shareExistingFile(
          file: widget.pdfFile,
          shareText: 'Bill from $shopName',
          subFolder: 'Bills',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${AppLocalizations.of(context)?.billPreview ?? 'Bill Preview'} - ${widget.customerName}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareBill(context),
          ),
        ],
      ),
      body: pdfx.PdfView(controller: _pdfController),
    );
  }
}

// Assuming this is a mock implementation for demonstration
class ViewBillDetailsScreen extends StatefulWidget {
  final String billId;
  final String billDate;
  final String customerName;
  final String customerMobile;
  final String? customerVehicle;
  final int totalAmount;
  final bool totalAmountPaid;
  final int amountPaid;
  final int amountRemaining;
  final List<Map<String, dynamic>>? products;
  final String paymentMethod;
  final String? nextPaymentDate;
  final double previousDueAmount;
  final double previousPaidAmount;
  final String previousDueDescription;

  const ViewBillDetailsScreen({
    required this.billId,
    required this.billDate,
    required this.customerName,
    required this.customerMobile,
    this.customerVehicle,
    required this.totalAmount,
    required this.totalAmountPaid,
    required this.amountPaid,
    required this.amountRemaining,
    this.products,
    this.paymentMethod = 'cash',
    this.nextPaymentDate,
    this.previousDueAmount = 0.0,
    this.previousPaidAmount = 0.0,
    this.previousDueDescription = '',
    super.key,
  });

  @override
  State<ViewBillDetailsScreen> createState() => _ViewBillDetailsScreenState();
}

class _ViewBillDetailsScreenState extends State<ViewBillDetailsScreen> {
  late String billId;
  int billNumber = 0; // Sequential bill number
  late String billDate;
  late String customerName;
  late String customerMobile;
  String? customerVehicle;
  List<Map<String, String>> products = const [];
  String totalItems = '0';
  late String totalAmount;
  late String amountPaid;
  late String amountRemaining;
  String paymentStatus = '';
  bool isTotalAmountPaid = false;
  List<PaymentRecord> paymentRecords = [];
  double totalProfit = 0;
  int discount = 0;
  int deliveryCharges = 0;
  late String paymentMethod;
  String? nextPaymentDate;
  late double previousDueAmount;
  late double previousPaidAmount;
  late String previousDueDescription;
  late TextEditingController _nextPaymentDateController;
  late AppLocalizations localizations;
  bool _vehicleNumberEnabled = false; // App setting for vehicle number field
  bool _deliveryChargesEnabled =
      false; // App setting for delivery charges field
  bool _isDeleting = false; // Loading state for bill deletion
  final ProfileService _profileService = ProfileService();
  final BillsDataService _billsDataService = BillsDataService();
  StreamSubscription<Map<String, dynamic>>? _appSettingsSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize from widget parameters
    billId = widget.billId;
    billDate = widget.billDate;
    customerName = widget.customerName;
    customerMobile = widget.customerMobile;
    customerVehicle = widget.customerVehicle;
    paymentMethod = widget.paymentMethod;
    nextPaymentDate = widget.nextPaymentDate;
    previousDueAmount = widget.previousDueAmount;
    previousPaidAmount = widget.previousPaidAmount;
    previousDueDescription = widget.previousDueDescription;
    _nextPaymentDateController = TextEditingController(
      text: nextPaymentDate ?? '',
    );
    totalAmount = '₹ ${widget.totalAmount.toString()}';
    isTotalAmountPaid = widget.totalAmountPaid;
    amountPaid = '₹ ${widget.amountPaid.toString()}';
    amountRemaining = '₹ ${widget.amountRemaining.toString()}';

    // Load app settings
    _loadAppSettings();

    // Convert products if provided
    if (widget.products != null && widget.products!.isNotEmpty) {
      products = widget.products!
          .map(
            (p) => {
              'name': (p['productName'] ?? 'Unknown').toString(),
              'qty': (p['quantity'] ?? 0).toString(),
              'price': '₹ ${(p['price'] ?? 0).toString()}',
              'boughtPrice': '₹ ${(p['boughtPrice'] ?? 0).toString()}',
              'batchId': (p['batchId'] as String?) ?? '',
              'profitTotal':
                  (p['profitTotal'] as num?)?.toStringAsFixed(2) ?? '0.00',
            },
          )
          .toList();
      totalItems = widget.products!.length.toString();

      // Calculate total profit using batch profit data if available
      // Discount will be subtracted after loading from Firebase
      totalProfit = _calculateBaseProfit();
    } else {
      products = [];
      totalItems = '0';
      totalProfit = 0;
    }

    // Load discount and payment records from Firebase
    _loadPaymentRecords();
    _loadDiscount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocalizations = AppLocalizations.of(context);
    if (newLocalizations != null) {
      localizations = newLocalizations;
    }

    // Set payment status (moved here because context is available)
    if (isTotalAmountPaid) {
      paymentStatus = localizations.paid;
    } else if (widget.amountRemaining == 0) {
      paymentStatus = localizations.paid;
    } else {
      paymentStatus = localizations.partiallyPaid;
    }
  }

  @override
  void dispose() {
    _nextPaymentDateController.dispose();
    _appSettingsSubscription?.cancel();
    _profileService.dispose();
    _billsDataService.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentRecords() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get bill data from cached bills
      final billsData = _billsDataService.getCachedBills();
      final billData = billsData.firstWhere(
        (bill) => bill['id'] == billId,
        orElse: () => <String, dynamic>{},
      );

      if (billData.isNotEmpty) {
        final payments = billData['payments'] as List<dynamic>? ?? [];
        if (payments.isNotEmpty) {
          setState(() {
            paymentRecords = payments
                .map(
                  (p) => PaymentRecord.fromMap(
                    Map<dynamic, dynamic>.from(p as Map),
                  ),
                )
                .toList();
          });
        }
      }
    } catch (e) {
      appLog('Error loading payment records from cache: $e');
    }
  }

  Future<void> _loadDiscount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get bill data from cached bills
      final billsData = _billsDataService.getCachedBills();
      final billData = billsData.firstWhere(
        (bill) => bill['id'] == billId,
        orElse: () => <String, dynamic>{},
      );

      if (billData.isNotEmpty) {
        final loadedDiscount = (billData['discount'] as num?)?.toInt() ?? 0;
        final loadedDeliveryCharges =
            (billData['deliveryCharges'] as num?)?.toInt() ?? 0;
        int loadedBillNumber = (billData['billNumber'] as num?)?.toInt() ?? 0;

        setState(() {
          discount = loadedDiscount;
          deliveryCharges = loadedDeliveryCharges;
          billNumber = loadedBillNumber;
          // IMPORTANT: Discount ALWAYS reduces profit, never increases it
          // Formula: Profit = Base Profit - Discount
          // Ensure discount is positive (negative discount would incorrectly add to profit)
          final validDiscount = loadedDiscount > 0 ? loadedDiscount : 0;
          totalProfit = _calculateBaseProfit() - validDiscount;
        });
      }
    } catch (e) {
      appLog('Error loading discount from cache: $e');
    }
  }

  Future<void> _loadAppSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Initialize ProfileService if not already initialized
      _profileService.initialize(user.uid);

      // Initialize BillsDataService for bill data
      _billsDataService.initialize(user.uid);

      // Listen to bills data stream for real-time updates
      _billsDataService.billsStream.listen((billsData) {
        if (mounted) {
          // Update payment records and discount data when bills data changes
          _updateBillDataFromCache(billsData);
        }
      });

      // Load initial bill data from cache
      final initialBillsData = _billsDataService.getCachedBills();
      if (initialBillsData.isNotEmpty) {
        _updateBillDataFromCache(initialBillsData);
      }

      // Listen to app settings stream for real-time updates
      _appSettingsSubscription = _profileService.appSettingsStream.listen((
        appSettings,
      ) {
        if (mounted) {
          setState(() {
            _vehicleNumberEnabled =
                appSettings['vehicleNumberEnabled'] ?? false;
            _deliveryChargesEnabled =
                appSettings['deliveryChargesEnabled'] ?? false;
          });
        }
      });

      // Also try to get current settings immediately in case stream hasn't emitted yet
      final profileData = await _profileService.getCurrentUserProfile();
      if (profileData != null && mounted) {
        final appSettings =
            profileData['appSettings'] as Map<String, dynamic>? ?? {};
        setState(() {
          _vehicleNumberEnabled = appSettings['vehicleNumberEnabled'] ?? false;
          _deliveryChargesEnabled =
              appSettings['deliveryChargesEnabled'] ?? false;
        });
      }
    } catch (e) {
      appLog('Error loading app settings: $e');
      // Default to true if error
      if (mounted) {
        setState(() {
          _vehicleNumberEnabled = true;
          _deliveryChargesEnabled = true;
        });
      }
    }
  }

  // Update bill data from cached bills data
  void _updateBillDataFromCache(List<Map<String, dynamic>> billsData) {
    try {
      final billData = billsData.firstWhere(
        (bill) => bill['id'] == billId,
        orElse: () => <String, dynamic>{},
      );

      if (billData.isNotEmpty && mounted) {
        // Update payment records
        final payments = billData['payments'] as List<dynamic>? ?? [];
        final updatedPaymentRecords = payments.isNotEmpty
            ? payments
                  .map(
                    (p) => PaymentRecord.fromMap(
                      Map<dynamic, dynamic>.from(p as Map),
                    ),
                  )
                  .toList()
            : <PaymentRecord>[];

        // Update discount and delivery data
        final loadedDiscount = (billData['discount'] as num?)?.toInt() ?? 0;
        final loadedDeliveryCharges =
            (billData['deliveryCharges'] as num?)?.toInt() ?? 0;
        int loadedBillNumber = (billData['billNumber'] as num?)?.toInt() ?? 0;

        setState(() {
          paymentRecords = updatedPaymentRecords;
          discount = loadedDiscount;
          deliveryCharges = loadedDeliveryCharges;
          billNumber = loadedBillNumber;
          // Recalculate profit with new discount
          final validDiscount = loadedDiscount > 0 ? loadedDiscount : 0;
          totalProfit = _calculateBaseProfit() - validDiscount;
        });
      }
    } catch (e) {
      appLog('Error updating bill data from cache: $e');
    }
  }

  // Helper method to calculate base profit from products
  double _calculateBaseProfit() {
    double baseProfit = 0;
    if (widget.products != null && widget.products!.isNotEmpty) {
      for (var product in widget.products!) {
        final quantity = (product['quantity'] ?? 0).toDouble();
        final sellingPrice = (product['price'] ?? 0).toDouble();
        final boughtPrice = (product['boughtPrice'] ?? 0).toDouble();

        // Always calculate profit from prices (not from stored profitTotal)
        final profit = (sellingPrice - boughtPrice) * quantity;
        baseProfit += profit;
      }
    }
    return baseProfit;
  }

  void _previewBill() async {
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
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // Generate PDF
      final pdfBytes = await _generateBillPDF();

      // Create file from bytes
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateTimeString =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final sanitizedCustomerName = customerName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final fileName = '${sanitizedCustomerName}_$dateTimeString.pdf';
      final pdfFile = File('${dir.path}/$fileName');
      await pdfFile.writeAsBytes(pdfBytes);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Navigate to PDF preview page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BillPdfPreviewPage(
              pdfFile: pdfFile,
              customerName: widget.customerName,
            ),
          ),
        );
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

  void _shareBill(BuildContext context) async {
    await _shareWithLoadingDialog(
      context: context,
      loadingMessage: localizations.generatingPdf,
      errorPrefix: localizations.errorGeneratingBill,
      shareFunction: () async {
        // Fetch profile data once for both share text and PDF generation
        String? ownerSignatureBase64;
        String shopName = 'Shop';
        String ownerName = '--';
        String shopAddress = '--';
        String shopPhone = '--';
        String ownerPhone = '';

        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final profileData = await _profileService.getCurrentUserProfile();
            if (profileData != null) {
              ownerSignatureBase64 = profileData['ownerSignature'];
              shopName = profileData['shopName'] ?? 'Shop';
              ownerName = profileData['ownerName'] ?? '--';
              shopAddress = profileData['shopAddress'] ?? '--';
              shopPhone = profileData['shopPhone'] ?? '--';
              ownerPhone = profileData['ownerPhone'] ?? '';
            }
          }
        } catch (e) {
          appLog('Error fetching profile data: $e');
        }

        // Generate PDF with already-fetched profile data
        final pdfBytes = await _generateBillPDF(
          ownerSignatureBase64: ownerSignatureBase64,
          shopName: shopName,
          ownerName: ownerName,
          shopAddress: shopAddress,
          shopPhone: shopPhone,
          ownerPhone: ownerPhone,
        );

        // Generate file name using FileService
        final fileName = FileService.generateTimestampedFileName(
          customerName,
          'pdf',
        );

        // Share file using FileService
        return await FileService.shareFile(
          fileBytes: pdfBytes,
          fileName: fileName,
          shareText: 'Bill from $shopName',
          subFolder: 'Bills',
        );
      },
    );
  }

  void _deleteBill() async {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            localizations.deleteBill,
            style: TextStyle(color: Colors.red),
          ),
          content: Text(localizations.confirmDeleteBill),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(localizations.delete),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() {
        _isDeleting = true;
      });

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text(localizations.deletingBill),
              ],
            ),
          );
        },
      );

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not authenticated');

        final firestore = FirebaseFirestore.instance;
        final userId = user.uid;

        // Get the bill data before deleting to restore stock quantities
        final billDoc = await firestore
            .collection('bills')
            .doc(userId)
            .collection('items')
            .doc(billId)
            .get();

        if (billDoc.exists) {
          final billData = billDoc.data()!;
          final products = billData['products'] as Map<String, dynamic>?;

          if (products != null) {
            // Restore product quantities
            for (final productEntry in products.entries) {
              final product = productEntry.value as Map<String, dynamic>;
              final productName = product['productName'] as String?;
              final supplierName = product['supplierName'] as String?;
              final quantity = (product['quantity'] as num?)?.toInt() ?? 0;
              final batchId = product['batchId'] as String?;

              if (productName != null &&
                  supplierName != null &&
                  batchId != null) {
                // Find the matching product by batchId and restore quantity
                final productsSnapshot = await firestore
                    .collection('purchased-products')
                    .doc(userId)
                    .collection('items')
                    .get();

                for (final productDoc in productsSnapshot.docs) {
                  final productData = productDoc.data();
                  final docBatchId = productData['batchId'] as String?;

                  if (docBatchId == batchId) {
                    final currentQty =
                        (productData['quantity'] as num?)?.toInt() ?? 0;
                    final newQty = currentQty + quantity;

                    // Update quantity
                    await firestore
                        .collection('purchased-products')
                        .doc(userId)
                        .collection('items')
                        .doc(productDoc.id)
                        .update({'quantity': newQty});
                    break; // Found and updated, move to next product
                  }
                }
              }
            }
          }
        }

        // Delete the bill from Firestore
        await firestore
            .collection('bills')
            .doc(userId)
            .collection('items')
            .doc(billId)
            .delete();

        // Dismiss loading dialog
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
        }

        if (mounted) {
          setState(() {
            _isDeleting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.billDeletedSuccessfully)),
          );
          // Navigate back to bills list
          Navigator.of(
            context,
          ).pop(true); // Return true to indicate bill was deleted
        }
      } catch (e) {
        // Dismiss loading dialog
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
        }

        if (mounted) {
          setState(() {
            _isDeleting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${localizations.errorDeletingBill}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editBill() {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    // Prepare the bill data for editing
    final billData = {
      'billId': billId,
      'billDate': billDate,
      'customerName': customerName,
      'customerMobile': customerMobile,
      'customerVehicle': customerVehicle,
      'paymentMethod': paymentMethod,
      'nextPaymentDate': nextPaymentDate,
      'products': widget.products,
      'totalAmount': widget.totalAmount,
      'amountPaid': widget.amountPaid,
      'amountRemaining': widget.amountRemaining,
      'totalAmountPaid': isTotalAmountPaid,
      'previousDueAmount': previousDueAmount,
      'previousPaidAmount': previousPaidAmount,
      'previousDueDescription': previousDueDescription,
    };

    // Navigate to CreateNewBill with edit mode enabled
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateNewBill(
          isEditMode: true,
          billId: billId,
          existingBillData: billData,
        ),
      ),
    ).then((result) {
      // If bill was edited successfully, pop back to refresh the bills list
      if (result == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    });
  }

  Future<Uint8List> _generateBillPDF({
    String? ownerSignatureBase64,
    String? shopName,
    String? ownerName,
    String? shopAddress,
    String? shopPhone,
    String? ownerPhone,
  }) async {
    // Ensure billNumber is loaded before generating PDF
    if (billNumber == 0) {
      await _loadDiscount(); // This will load or generate billNumber
    }

    // Use provided profile data or fetch if not provided
    String? finalOwnerSignature = ownerSignatureBase64;
    String finalShopName = shopName ?? '--';
    String finalOwnerName = ownerName ?? '--';
    String finalShopAddress = shopAddress ?? '--';
    String finalShopPhone = shopPhone ?? '--';
    String finalOwnerPhone = ownerPhone ?? '';

    // Only fetch if profile data not provided
    if (ownerSignatureBase64 == null ||
        shopName == null ||
        ownerName == null ||
        shopAddress == null ||
        shopPhone == null ||
        ownerPhone == null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final profileData = await _profileService.getCurrentUserProfile();
          if (profileData != null) {
            final data = profileData;
            finalOwnerSignature = data['ownerSignature'];
            finalShopName = data['shopName'] ?? '--';
            finalOwnerName = data['ownerName'] ?? '--';
            finalShopAddress = data['shopAddress'] ?? '--';
            finalShopPhone = data['shopPhone'] ?? '--';
            finalOwnerPhone = data['ownerPhone'] ?? '';
          }
        }
      } catch (e) {
        appLog('Error fetching owner signature: $e');
      }
    }

    // Use FileService to generate the PDF
    return await FileService.generateBillPDF(
      billNumber: billNumber,
      billId: billId,
      customerName: customerName,
      customerMobile: customerMobile,
      customerVehicle: customerVehicle,
      products: products,
      totalAmount: totalAmount,
      amountPaid: amountPaid,
      amountRemaining: amountRemaining,
      discount: discount,
      deliveryCharges: deliveryCharges,
      nextPaymentDate: nextPaymentDate,
      previousDueAmount: previousDueAmount,
      previousPaidAmount: previousPaidAmount,
      previousDueDescription: previousDueDescription,
      ownerSignatureBase64: finalOwnerSignature,
      shopName: finalShopName,
      ownerName: finalOwnerName,
      shopAddress: finalShopAddress,
      shopPhone: finalShopPhone,
      ownerPhone: finalOwnerPhone,
    );
  }

  Future<void> _saveAmountPaid(
    String paymentAmountStr,
    String selectedPaymentMethod,
  ) async {
    try {
      final paymentAmount = int.parse(paymentAmountStr);

      // Validate payment amount
      if (paymentAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.paymentAmountMustBeGreaterThan0),
          ),
        );
        return;
      }

      final totalAmountInt = int.parse(totalAmount.replaceAll('₹ ', ''));
      final currentAmountPaid = int.parse(amountPaid.replaceAll('₹ ', ''));
      final newTotalAmountPaid = currentAmountPaid + paymentAmount;

      if (newTotalAmountPaid > totalAmountInt) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.totalPaymentCannotExceed.replaceAll(
                '%s',
                '₹$totalAmountInt',
              ),
            ),
          ),
        );
        return;
      }

      // Add new payment record with selected method
      await _addPaymentRecord(paymentAmount, selectedPaymentMethod);

      // Update bill totals
      final newRemaining = totalAmountInt - newTotalAmountPaid;
      final isFullyPaid = newTotalAmountPaid >= totalAmountInt;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId)
          .update({
            'amountPaid': newTotalAmountPaid,
            'amountRemaining': newRemaining,
            'totalAmountPaid': isFullyPaid,
            'paymentMethod': selectedPaymentMethod,
          });

      if (!mounted) return;
      // Update local state
      setState(() {
        amountPaid = '₹ $newTotalAmountPaid';
        amountRemaining = '₹ $newRemaining';
        isTotalAmountPaid = isFullyPaid;
        paymentStatus = isFullyPaid
            ? localizations.paid
            : localizations.partiallyPaid;
        paymentMethod = selectedPaymentMethod;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.paymentRecordedSuccessfully)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }

  Future<void> _addPaymentRecord(
    int amount,
    String selectedPaymentMethod,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final newPayment = PaymentRecord(
        amount: amount,
        date: DateFormat('dd MMM yyyy').format(DateTime.now()),
        paymentMethod: selectedPaymentMethod,
      );

      final billRef = FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId);

      // Append new payment to payments array
      await billRef.update({
        'payments': FieldValue.arrayUnion([newPayment.toMap()]),
      });

      // Update local state
      setState(() {
        paymentRecords.add(newPayment);
      });
    } catch (e) {
      appLog('Error adding payment record: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseAmount = int.tryParse(totalAmount.replaceAll('₹ ', '')) ?? 0;
    final paidAmount = int.tryParse(amountPaid.replaceAll('₹ ', '')) ?? 0;
    final remainingAmount =
        int.tryParse(amountRemaining.replaceAll('₹ ', '')) ?? 0;
    final finalAmount =
        baseAmount + (_deliveryChargesEnabled ? deliveryCharges : 0) - discount;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final showVehicle =
        _vehicleNumberEnabled ||
        (customerVehicle != null && customerVehicle!.isNotEmpty);
    final pendingPreviousDue = (previousDueAmount - previousPaidAmount).clamp(
      0.0,
      double.infinity,
    );
    final isProfitable = totalProfit >= 0;
    final profitColor = isProfitable ? scheme.primary : scheme.error;

    double totalCost = 0;
    if (widget.products != null) {
      for (final product in widget.products!) {
        final boughtPrice =
            double.tryParse(
              product['boughtPrice']?.toString().replaceAll('₹', '').trim() ??
                  '0',
            ) ??
            0;
        final quantity = (product['quantity'] ?? 0) as num;
        totalCost += boughtPrice * quantity;
      }
    }
    final profitPercentage = totalCost > 0
        ? (totalProfit / totalCost) * 100
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.billDetails),
        actions: [
          if (Platform.isWindows)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: () {
                _generateBillPDF()
                    .then((pdfBytes) {
                      Printing.layoutPdf(onLayout: (format) async => pdfBytes);
                    })
                    .catchError((e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${localizations.errorGeneratingBill}: $e',
                          ),
                          backgroundColor: scheme.error,
                        ),
                      );
                    });
              },
            ),
          AppContextMenu.iconButton(
            width: 180,
            items: () => [
              AppContextMenuItem(
                label: localizations.previewBill,
                icon: CupertinoIcons.eye,
                onPressed: () {
                  if (_isDeleting) return;
                  _previewBill();
                },
              ),
              AppContextMenuItem(
                label: localizations.editBill,
                icon: CupertinoIcons.pencil,
                onPressed: () {
                  if (_isDeleting) return;
                  _editBill();
                },
              ),
              AppContextMenuItem(
                label: _isDeleting
                    ? localizations.deletingBill
                    : localizations.deleteBill,
                icon: CupertinoIcons.delete,
                destructive: true,
                onPressed: () {
                  if (_isDeleting) return;
                  _deleteBill();
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareBill(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                _SummaryTile(
                  icon: Icons.receipt_long_outlined,
                  label: localizations.finalAmount,
                  value: '₹${_formatAmount(finalAmount)}',
                  valueColor: scheme.primary,
                ),
                    const SizedBox(width: 8),
                _SummaryTile(
                  icon: Icons.payments_outlined,
                  label: localizations.amountPaid,
                  value: '₹${_formatAmount(paidAmount)}',
                ),
                const SizedBox(width: 8),
                _SummaryTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: localizations.remaining,
                  value: '₹${_formatAmount(remainingAmount)}',
                  valueColor: remainingAmount > 0 ? scheme.error : null,
                ),
                  ],
                ),
              ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _sectionLabel(context, localizations.customer),
          ),
          Adaptive.fullWidthGroup(
            bordered: true,
            context: context,
                  children: [
              _infoTile(
                icon: Icons.calendar_today_outlined,
                label: localizations.billDate,
                value: billDate,
              ),
              _infoTile(
                icon: Icons.person_outline,
                label: localizations.customerName,
                value: customerName,
              ),
              _infoTile(
                icon: Icons.phone_outlined,
                label: localizations.customerMobileNumber,
                value: customerMobile,
                onTap: _showEditMobileDialog,
                trailing: isMobile
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.call_outlined, size: 20),
                            onPressed: () => _makePhoneCall(customerMobile),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.message_outlined, size: 20),
                            onPressed: () => _sendMessage(customerMobile),
                          ),
                        ],
                      )
                    : null,
              ),
              if (showVehicle)
                _infoTile(
                  icon: Icons.directions_car_outlined,
                  label: localizations.customerVehicleNumber,
                  value: (customerVehicle == null || customerVehicle!.isEmpty)
                      ? localizations.nA
                      : customerVehicle!,
                  onTap: _showEditVehicleDialog,
                ),
              if (paidAmount > 0)
                _infoTile(
                  icon: _paymentMethodIcon(paymentMethod),
                  label: localizations.paymentMethod,
                  value: _paymentMethodLabel(paymentMethod),
                ),
            ],
          ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionLabel(context, localizations.products),
            ),
            Adaptive.box(
              context: context,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    for (var i = 0; i < products.length; i++) ...[
                      _BillProductTile(
                        product: products[i],
                        localizations: localizations,
                      ),
                      if (i != products.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
                      ),
                    ),
                  ],
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _sectionLabel(context, localizations.summary),
          ),
          Adaptive.fullWidthGroup(
            bordered: true,
            context: context,
            children: [
              _infoTile(
                icon: Icons.shopping_bag_outlined,
                label: localizations.totalItems,
                value: totalItems,
              ),
              _infoTile(
                icon: Icons.local_offer_outlined,
                label: localizations.discount,
                value: '₹${_formatAmount(discount)}',
                onTap: _showEditDiscountDialog,
              ),
              if (_deliveryChargesEnabled || deliveryCharges > 0)
                _infoTile(
                  icon: Icons.local_shipping_outlined,
                  label: localizations.deliveryCharges,
                  value: '₹${_formatAmount(deliveryCharges)}',
                ),
              _infoTile(
                icon: Icons.receipt_long_outlined,
                label: localizations.finalAmount,
                value: '₹${_formatAmount(finalAmount)}',
                valueColor: scheme.primary,
              ),
              _infoTile(
                icon: Icons.payments_outlined,
                label: localizations.amountPaid,
                value: '₹${_formatAmount(paidAmount)}',
                onTap: _showEditAmountPaidDialog,
              ),
              _infoTile(
                icon: Icons.account_balance_wallet_outlined,
                label: localizations.amountRemaining,
                value: '₹${_formatAmount(remainingAmount)}',
                valueColor: remainingAmount > 0 ? scheme.error : null,
              ),
              _infoTile(
                icon: Icons.verified_outlined,
                label: localizations.paymentStatus,
                value: paymentStatus,
                valueColor: remainingAmount > 0 ? scheme.error : null,
              ),
              if (remainingAmount != 0 &&
                  nextPaymentDate != null &&
                  nextPaymentDate!.isNotEmpty)
                _infoTile(
                  icon: Icons.event_outlined,
                  label: localizations.nextPaymentDate,
                  value: nextPaymentDate!,
                  onTap: _showEditNextPaymentDateDialog,
              ),
            ],
          ),
          if (previousDueAmount > 0 || previousPaidAmount > 0) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _sectionLabel(context, localizations.previousDue),
            ),
            Adaptive.fullWidthGroup(
            bordered: true,
              context: context,
              children: [
                _infoTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: localizations.total,
                  value: '₹${_formatAmount(previousDueAmount)}',
                ),
                _infoTile(
                  icon: Icons.payments_outlined,
                  label: localizations.paid,
                  value: '₹${_formatAmount(previousPaidAmount)}',
                ),
                _infoTile(
                  icon: Icons.pending_actions_outlined,
                  label: localizations.remaining,
                  value: '₹${_formatAmount(pendingPreviousDue)}',
                  valueColor: pendingPreviousDue > 0 ? scheme.error : null,
                ),
                if (previousDueDescription.isNotEmpty)
                  _infoTile(
                    icon: Icons.notes_outlined,
                    label: localizations.description,
                    value: previousDueDescription,
          ),
        ],
      ),
          ],
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _sectionLabel(context, localizations.profitLoss),
          ),
          Adaptive.fullWidthGroup(
            bordered: true,
            context: context,
        children: [
              _infoTile(
                icon: isProfitable
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                label: isProfitable ? localizations.profit : localizations.loss,
                value: '₹${_formatAmount(totalProfit.abs())}',
                valueColor: profitColor,
              ),
              _infoTile(
                icon: Icons.percent_outlined,
                label: localizations.margin,
                value: '${profitPercentage.abs().toStringAsFixed(1)}%',
                valueColor: profitColor,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
                children: [
                Expanded(
                  child: Text(
                    localizations.paymentHistory.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (remainingAmount != 0)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () {
                      if (!SubscriptionGuard.ensureCanWrite(context)) return;
                      _showAddPaymentDialog();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(localizations.addPayment),
                  ),
                ],
              ),
            ),
          Adaptive.fullWidthGroup(
            bordered: true,
            context: context,
            children: [
              if (paymentRecords.isEmpty)
                _infoTile(
                  icon: Icons.history_outlined,
                  label: localizations.paymentHistory,
                  value: localizations.noPaymentsRecorded,
                )
              else
                for (final payment in paymentRecords)
                  _infoTile(
                    icon: _paymentMethodIcon(payment.paymentMethod),
                    label:
                        '${payment.date}  ·  ${_paymentMethodLabel(payment.paymentMethod)}',
                    value: '₹${_formatAmount(payment.amount)}',
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      minVerticalPadding: 4,
      onTap: onTap,
      leading: _squareIcon(icon, scheme),
      title: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: valueColor ?? scheme.onSurface,
        ),
      ),
      subtitle: Text(label),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                )),
    );
  }

  IconData _paymentMethodIcon(String method) {
    switch (method) {
      case 'online':
        return Icons.qr_code_outlined;
      case 'discount':
        return Icons.local_offer_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'online':
        return localizations.online;
      case 'discount':
        return localizations.discount;
      default:
        return localizations.cash;
    }
  }

  void _showAddPaymentDialog() {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final TextEditingController amountController = TextEditingController();
    final remainingAmount = int.parse(amountRemaining.replaceAll('₹ ', ''));
    String selectedPaymentMethod = 'cash';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                localizations.recordPayment,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            localizations.amountRemaining,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                          Text(
                            '₹ $remainingAmount',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.paymentAmount,
                        hintText: localizations.eg2000,
                        prefixText: '₹ ',
                        helperText: '${localizations.max}: ₹ $remainingAmount',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.paymentMethod,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RadioGroup<String>(
                                groupValue: selectedPaymentMethod,
                                onChanged: (value) {
                                  setState(() {
                                    selectedPaymentMethod = value ?? 'cash';
                                  });
                                },
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: Text(localizations.cash),
                                  value: 'cash',
                                  contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text(localizations.online),
                                value: 'online',
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validate payment amount
                    final paymentAmountStr = amountController.text.trim();
                    if (paymentAmountStr.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.pleaseEnterAValidNumber),
                        ),
                      );
                      return;
                    }

                    final paymentAmount = int.tryParse(paymentAmountStr);
                    if (paymentAmount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.pleaseEnterAValidNumber),
                        ),
                      );
                      return;
                    }

                    if (paymentAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizations.paymentAmountMustBeGreaterThan0,
                          ),
                        ),
                      );
                      return;
                    }

                    if (paymentAmount > remainingAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizations.totalPaymentCannotExceed.replaceAll(
                              '%s',
                              '₹ $remainingAmount',
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    _saveAmountPaid(paymentAmountStr, selectedPaymentMethod);
                  },
                  child: Text(localizations.recordPayment),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditNextPaymentDateDialog() {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            localizations.editNextPaymentDate,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: GestureDetector(
            onTap: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selectedDate != null) {
                final formattedDate = DateFormat(
                  'dd/MM/yyyy',
                ).format(selectedDate);
                _nextPaymentDateController.text = formattedDate;
              }
            },
            child: AbsorbPointer(
              child: TextField(
                controller: _nextPaymentDateController,
                decoration: InputDecoration(
                  labelText: localizations.nextPaymentDateLabel,
                  hintText: 'dd/MM/yyyy',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final newDate = _nextPaymentDateController.text.trim();
                if (newDate.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(localizations.pleaseSelectADate)),
                  );
                  return;
                }
                Navigator.of(context).pop();
                _updateNextPaymentDate(newDate);
              },
              child: Text(localizations.update),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateNextPaymentDate(String newDate) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId)
          .update({'nextPaymentDate': newDate});

      if (!mounted) return;
      setState(() {
        nextPaymentDate = newDate;
        _nextPaymentDateController.text = newDate;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.nextPaymentDateUpdatedSuccessfully),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }

  void _showEditMobileDialog() {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final TextEditingController mobileController = TextEditingController(
      text: customerMobile,
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                localizations.editMobileNumber,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              content: TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                onChanged: (value) {
                  setState(() {
                    errorText = null;
                  });
                },
                decoration: InputDecoration(
                  labelText: localizations.mobileNumber,
                  hintText: localizations.tenDigitMobileNumber,
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newMobile = mobileController.text.trim();
                    if (newMobile.isEmpty) {
                      setState(() {
                        errorText = localizations.mobileNumberIsRequired;
                      });
                      return;
                    }
                    if (!RegExp(r'^[0-9]{10}$').hasMatch(newMobile)) {
                      setState(() {
                        errorText = localizations.mobileNumberMustBe10Digits;
                      });
                      return;
                    }
                    Navigator.of(context).pop();
                    _updateMobileNumber(newMobile);
                  },
                  child: Text(localizations.update),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateMobileNumber(String newMobile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId)
          .update({'customerMobile': newMobile});

      if (!mounted) return;
      setState(() {
        customerMobile = newMobile;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.mobileNumberUpdatedSuccessfully)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }

  void _showEditVehicleDialog() {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final TextEditingController vehicleController = TextEditingController(
      text: customerVehicle ?? '',
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                localizations.editVehicleNumber,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              content: TextField(
                controller: vehicleController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  // Convert to uppercase and update controller
                  final upperValue = value.toUpperCase();
                  if (value != upperValue) {
                    vehicleController.value = vehicleController.value.copyWith(
                      text: upperValue,
                      selection: TextSelection.collapsed(
                        offset: upperValue.length,
                      ),
                    );
                  }
                  setState(() {
                    errorText = null;
                  });
                },
                decoration: InputDecoration(
                  labelText: localizations.vehicleNumber,
                  hintText: localizations.egKa01ab1234Optional,
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newVehicle = vehicleController.text
                        .trim()
                        .toUpperCase();
                    // Vehicle is optional, but if provided should match format
                    if (newVehicle.isNotEmpty &&
                        !RegExp(
                          r'^[A-Z]{2}[0-9]{2}[A-Z]{2}[0-9]{4}$',
                        ).hasMatch(newVehicle)) {
                      setState(() {
                        errorText = localizations.invalidFormatEgKa01ab1234;
                      });
                      return;
                    }
                    Navigator.of(context).pop();
                    _updateVehicleNumber(
                      newVehicle.isEmpty ? null : newVehicle,
                    );
                  },
                  child: Text(localizations.update),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateVehicleNumber(String? newVehicle) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId)
          .update({'customerVehicle': newVehicle ?? ''});

      if (!mounted) return;
      setState(() {
        customerVehicle = newVehicle;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.vehicleNumberUpdatedSuccessfully)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.couldNotLaunchPhoneDialer)),
        );
      }
    }
  }

  Future<void> _sendMessage(String phoneNumber) async {
    // Fetch shop name from Firebase
    String shopName = 'Our Shop';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profileData = await _profileService.getCurrentUserProfile();
        if (profileData != null) {
          shopName = profileData['shopName'] ?? 'Our Shop';
        }
      }
    } catch (e) {
      appLog('Error fetching shop name: $e');
    }

    // Prepare message based on payment status
    String message;
    final remainingAmount = int.parse(amountRemaining.replaceAll('₹ ', ''));

    if (remainingAmount > 0) {
      // Pending payment reminder message
      message =
          '$shopName\n\n'
          'Dear $customerName,\n\n'
          'Thank you for shopping with us!\n\n'
          'This is a friendly reminder that you have a pending payment of ₹$remainingAmount '
          'for your purchase on $billDate.\n\n'
          '${nextPaymentDate != null && nextPaymentDate!.isNotEmpty ? "Please arrange payment by $nextPaymentDate.\n\n" : ""}'
          'We appreciate your business!\n\n'
          'Best regards,\n$shopName';
    } else {
      // Thank you message for completed payment
      message =
          '$shopName\n\n'
          'Dear $customerName,\n\n'
          'Thank you for your purchase on $billDate!\n\n'
          'We truly appreciate your business and hope you are satisfied with your products.\n\n'
          'Looking forward to serving you again soon!\n\n'
          'Best regards,\n$shopName';
    }

    // URI encode the message
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );

    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.couldNotLaunchMessagingApp)),
        );
      }
    }
  }

  void _showEditDiscountDialog() {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final TextEditingController discountController = TextEditingController();
    String? errorText;
    final remainingAmountValue = int.parse(
      amountRemaining.replaceAll('₹ ', ''),
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                localizations.editDiscount,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations.remainingAmount,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        Text(
                          '₹ $remainingAmountValue',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        errorText = null;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: localizations.addDiscount,
                      hintText: localizations.eg100,
                      prefixText: '₹ ',
                      helperText:
                          '${localizations.max}: ₹ $remainingAmountValue',
                      prefixIcon: const Icon(Icons.discount),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newDiscount = int.tryParse(
                      discountController.text.trim(),
                    );
                    if (newDiscount == null) {
                      setState(() {
                        errorText = localizations.pleaseEnterAValidNumber;
                      });
                      return;
                    }
                    if (newDiscount < 0) {
                      setState(() {
                        errorText = localizations.discountCannotBeNegative;
                      });
                      return;
                    }
                    if (newDiscount > remainingAmountValue) {
                      setState(() {
                        errorText =
                            localizations.discountCannotExceedRemainingAmount;
                      });
                      return;
                    }
                    Navigator.of(context).pop();
                    _updateDiscount(newDiscount);
                  },
                  child: Text(localizations.update),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateDiscount(int additionalDiscount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final currentRemainingAmount = int.parse(
        amountRemaining.replaceAll('₹ ', ''),
      );
      final currentAmountPaid = int.parse(amountPaid.replaceAll('₹ ', ''));
      final totalAmountValue = int.parse(totalAmount.replaceAll('₹ ', ''));

      // Calculate new total discount (current + additional)
      final newTotalDiscount = discount + additionalDiscount;

      // Calculate new amounts with additional discount
      final newRemainingAmount = currentRemainingAmount - additionalDiscount;
      final newAmountPaid = currentAmountPaid + additionalDiscount;

      // Check if bill will be fully paid after discount
      final isFullyPaid = newRemainingAmount <= 0;

      final billRef = FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId);

      // Add new discount as a payment record
      await _addPaymentRecord(additionalDiscount, 'discount');

      // Update bill with new amounts and total discount
      await billRef.update({
        'discount': newTotalDiscount,
        'amountRemaining': isFullyPaid ? 0 : newRemainingAmount,
        'amountPaid': isFullyPaid ? totalAmountValue : newAmountPaid,
        'totalAmountPaid': isFullyPaid,
      });

      setState(() {
        discount = newTotalDiscount;
        amountRemaining = '₹ ${isFullyPaid ? 0 : newRemainingAmount}';
        amountPaid = '₹ ${isFullyPaid ? totalAmountValue : newAmountPaid}';
        isTotalAmountPaid = isFullyPaid;
        paymentStatus = isFullyPaid
            ? localizations.paid
            : localizations.partiallyPaid;
        // IMPORTANT: Discount ALWAYS reduces profit
        // Ensure discount is positive (negative would incorrectly increase profit)
        final validDiscount = newTotalDiscount > 0 ? newTotalDiscount : 0;
        totalProfit = _calculateBaseProfit() - validDiscount;
      });

      // Reload payment records to show the discount
      await _loadPaymentRecords();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFullyPaid
                ? localizations.discountAddedBillFullyPaid.replaceAll(
                    '%s',
                    '₹$additionalDiscount',
                  )
                : localizations.discountAddedSuccessfully.replaceAll(
                    '%s',
                    '₹$additionalDiscount',
                  ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }

  void _showEditAmountPaidDialog() {
    if (!SubscriptionGuard.ensureCanWrite(context)) return;
    final TextEditingController amountController = TextEditingController(
      text: amountPaid.replaceAll('₹ ', ''),
    );
    String? errorText;
    final totalAmountValue = int.parse(totalAmount.replaceAll('₹ ', ''));
    final finalAmountValue = totalAmountValue - discount;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                localizations.editAmountPaid,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations.finalAmount,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        Text(
                          '₹ $finalAmountValue',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _AmountInputFormatter(maxAmount: finalAmountValue),
                    ],
                    onChanged: (value) {
                      final enteredAmount = int.tryParse(value) ?? 0;
                      setState(() {
                        if (enteredAmount > finalAmountValue) {
                          errorText =
                              localizations.amountCannotExceedTotalAmount;
                        } else if (enteredAmount < 0) {
                          errorText = localizations.amountCannotBeNegative;
                        } else {
                          errorText = null;
                        }
                      });
                    },
                    decoration: InputDecoration(
                      labelText: localizations.amountPaid,
                      hintText: localizations.eg100,
                      prefixText: '₹ ',
                      helperText: '${localizations.max}: ₹ $finalAmountValue',
                      prefixIcon: const Icon(Icons.payment),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newAmount = int.tryParse(
                      amountController.text.trim(),
                    );
                    if (newAmount == null) {
                      setState(() {
                        errorText = localizations.pleaseEnterAValidNumber;
                      });
                      return;
                    }
                    if (errorText != null) {
                      // Don't proceed if there's already an error
                      return;
                    }
                    Navigator.of(context).pop();
                    _updateAmountPaid(newAmount);
                  },
                  child: Text(localizations.update),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateAmountPaid(int newAmountPaid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final totalAmountValue = int.parse(totalAmount.replaceAll('₹ ', ''));
      final finalAmountValue = totalAmountValue - discount;
      final newRemainingAmount = finalAmountValue - newAmountPaid;
      final isFullyPaid = newRemainingAmount <= 0;

      final billRef = FirebaseFirestore.instance
          .collection('bills')
          .doc(user.uid)
          .collection('items')
          .doc(billId);

      // Add new payment record for the adjustment
      await _addPaymentRecord(
        newAmountPaid - int.parse(amountPaid.replaceAll('₹ ', '')),
        'adjustment',
      );

      // Update bill with new amounts
      await billRef.update({
        'amountPaid': newAmountPaid,
        'amountRemaining': isFullyPaid ? 0 : newRemainingAmount,
        'totalAmountPaid': isFullyPaid,
      });

      setState(() {
        amountPaid = '₹ $newAmountPaid';
        amountRemaining = '₹ ${isFullyPaid ? 0 : newRemainingAmount}';
        isTotalAmountPaid = isFullyPaid;
        paymentStatus = isFullyPaid
            ? localizations.paid
            : (newAmountPaid > 0
                  ? localizations.partiallyPaid
                  : localizations.unpaid);
      });

      // Reload payment records to show the adjustment
      await _loadPaymentRecords();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.amountUpdatedSuccessfully)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${localizations.error}: $e')));
    }
  }
}

// Custom input formatter to prevent entering amounts greater than max amount
class _AmountInputFormatter extends TextInputFormatter {
  final int maxAmount;

  _AmountInputFormatter({required this.maxAmount});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty input
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Parse the new value
    final intValue = int.tryParse(newValue.text);
    if (intValue == null) {
      // If not a valid number, reject the change
      return oldValue;
    }

    // If the value exceeds max amount, reject the change
    if (intValue > maxAmount) {
      return oldValue;
    }

    // Allow the change
    return newValue;
  }
}

class _BillProductTile extends StatelessWidget {
  const _BillProductTile({required this.product, required this.localizations});

  final Map<String, String> product;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = product['name'] ?? '';
    final quantity = double.tryParse(product['qty'] ?? '0') ?? 0;
              final sellingPrice =
        double.tryParse(product['price']?.replaceAll('₹', '').trim() ?? '0') ??
                  0;
              final boughtPrice =
                  double.tryParse(
          product['boughtPrice']?.replaceAll('₹', '').trim() ?? '0',
                  ) ??
                  0;
    final batchId = product['batchId'] ?? '';
    final shortBatch = batchId.length > 8
        ? '${batchId.substring(0, 8)}…'
        : batchId;
    final batchLabel = batchId.isEmpty
        ? ''
        : '  ·  ${localizations.batch} $shortBatch';
              final profitPerUnit = sellingPrice - boughtPrice;
    final total = sellingPrice * quantity;
    final profit = profitPerUnit * quantity;

    return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: _squareIcon(Icons.inventory_2_outlined, scheme),
          title: Row(
                      children: [
                            Expanded(
                              child: Text(
                  name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
                            Text(
                '₹${_formatAmount(total)}',
                              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
          subtitle: Text(
            '${localizations.qty}: ${_formatAmount(quantity)}$batchLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    children: [
            Row(
                        children: [
                _Metric(
                  label: localizations.buyingPrice,
                  value: '₹${_formatAmount(boughtPrice)}',
                ),
                _Metric(
                  label: localizations.sellingPrice,
                  value: '₹${_formatAmount(sellingPrice)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                _Metric(
                  label: localizations.profitPerUnit,
                  value: '₹${_formatAmount(profitPerUnit)}',
                  valueColor: profitPerUnit >= 0
                      ? scheme.primary
                      : scheme.error,
                ),
                _Metric(
                  label: localizations.totalProfit,
                  value: '₹${_formatAmount(profit)}',
                  valueColor: profit >= 0 ? scheme.primary : scheme.error,
                          ),
                        ],
                      ),
                    ],
        ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

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
      child: Adaptive.box(
        context: context,
        margin: EdgeInsets.zero,
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

String _formatAmount(num amount) {
  if (amount == amount.roundToDouble()) return amount.toInt().toString();
  return amount.toStringAsFixed(2);
}
