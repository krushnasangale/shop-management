import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';

class Bills extends StatefulWidget {
  const Bills({super.key});

  @override
  State<Bills> createState() => _BillsState();
}

class _BillsState extends State<Bills> {
  PaymentFilter _selectedFilter = PaymentFilter.all;
  late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _billsSubscription;
  late String _userId;
  List<Bill> _allBills = [];
  List<Bill> _filteredBills = [];
  bool _isLoading = true;
  bool _showSearchBar = false;
  late TextEditingController _searchController;
  String _shopName = '--';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterBills);
    _loadBills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _billsSubscription.cancel();
    super.dispose();
  }

  void _loadBills() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _userId = user.uid;

    _loadShopName();
    _billsSubscription = FirebaseFirestore.instance
        .collection('bills')
        .doc(_userId)
        .collection('items')
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        try {
          final bills = <Bill>[];

          for (var billDoc in snapshot.docs) {
            final billData = billDoc.data();
            final totalAmount = (billData['totalAmount'] as num?)?.toInt() ?? 0;
            final totalAmountPaid = billData['totalAmountPaid'] as bool? ?? true;
            final amountRemaining = (billData['amountRemaining'] as num?)?.toInt() ?? 0;
            final amountPaid = (billData['amountPaid'] as num?)?.toInt() ?? 0;

            // Determine payment status
            PaymentFilter status;
            if (amountPaid == 0 && amountRemaining != 0) {
              status = PaymentFilter.unpaid;
            } else if (totalAmountPaid) {
              status = PaymentFilter.paid;
            } else if (amountRemaining == 0) {
              status = PaymentFilter.paid;
            } else {
              status = PaymentFilter.partial;
            }

            final productsMap = billData['products'] as Map<String, dynamic>?;
            final productsList = <Map<String, dynamic>>[];
            if (productsMap != null) {
              productsList.addAll(productsMap.values.cast<Map<String, dynamic>>());
            }

            bills.add(
              Bill(
                billDoc.id,
                billData['billDate'] ?? '',
                billData['customerName'] ?? 'Unknown',
                billData['customerMobile'] ?? '',
                billData['customerVehicle'],
                '₹${totalAmount}',
                status,
                billData['timestamp'] ?? '',
                totalAmount,
                totalAmountPaid,
                amountPaid,
                amountRemaining,
                productsList,
                billData['nextPaymentDate'],
              ),
            );
          }

          // Sort bills by timestamp (newest first)
          bills.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (mounted) {
            setState(() {
              _allBills = bills;
              _filterBills();
              _isLoading = false;
            });
          }
        } catch (e) {
          print('Error loading bills: $e');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      },
      onError: (error) {
        print('Firebase error: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  // Filter bills based on search query and payment status
  void _filterBills() {
    final query = _searchController.text.toLowerCase();

    List<Bill> filtered = _allBills;

    // Apply payment filter
    if (_selectedFilter != PaymentFilter.all) {
      filtered = filtered
          .where((bill) => bill.status == _selectedFilter)
          .toList();
    }

    // Apply search filter
    if (query.isNotEmpty) {
      filtered = filtered.where((bill) {
        return bill.customerName.toLowerCase().contains(query) ||
            bill.customerMobile.toLowerCase().contains(query);
      }).toList();
    }

    if (mounted) {
      setState(() {
        _filteredBills = filtered;
      });
    }
  }

  // Helper to convert Enum to display string
  String _getStatusText(PaymentFilter filter) {
    switch (filter) {
      case PaymentFilter.all:
        return 'All';
      case PaymentFilter.paid:
        return 'Paid';
      case PaymentFilter.partial:
        return 'Partial Payment';
      case PaymentFilter.unpaid:
        return 'Unpaid';
    }
  }

  Future<void> _loadShopName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('shop-profile')
            .doc(user.uid)
            .get();
        if (snapshot.exists) {
          if (mounted) {
            setState(() {
              _shopName = (snapshot.data()?['shopName'] as String?) ?? '--';
            });
          }
        }
      }
    } catch (e) {
      print('Error loading shop name: $e');
    }
  }

  void _showReportOptionsDialog(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Generate Report',
            style: TextStyle(color: primaryTextColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select format to export bills data:'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export as PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _generateAndSharePDF();
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Export as CSV (Excel)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _generateAndShareCSV();
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _generateAndSharePDF() async {
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
                      'Generating PDF...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      final pdfFile = await _generateBillsPDF();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          text: 'Bills Report from $_shopName',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateAndShareCSV() async {
    try {
      final csvFile = await _generateBillsCSV();

      if (mounted) {
        await Share.shareXFiles(
          [XFile(csvFile.path)],
          text: 'Bills Report (CSV) from $_shopName',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<File> _generateBillsPDF() async {
    final pdf = pw.Document();
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final dateTimeString =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/bills_report_$dateTimeString.pdf');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text(
                '$_shopName - Bills Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated on: ${now.toString().split('.')[0]} | Filter: ${_getStatusText(_selectedFilter)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 20),

              // Bills Table
              pw.Table(
                border: pw.TableBorder.all(width: 1),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      'S.No.',
                      'Customer',
                      'Mobile',
                      'Date',
                      'Amount',
                      'Status',
                    ]
                        .map((header) => pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                header,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ))
                        .toList(),
                  ),
                  // Data rows
                  ..._filteredBills.asMap().entries.map((entry) {
                    final bill = entry.value;
                    final index = entry.key + 1;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            index.toString(),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            bill.customerName,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            bill.customerMobile,
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            bill.date,
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'Rs.${bill.totalAmount}',
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            _getStatusText(bill.status),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total Bills: ${_filteredBills.length}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> _generateBillsCSV() async {
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final dateTimeString =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/bills_report_$dateTimeString.csv');

    // Create CSV header
    final csv = StringBuffer();
    csv.writeln(
        'S.No.,Customer Name,Mobile Number,Bill Date,Total Amount,Amount Paid,Amount Remaining,Status,Filter Applied: ${_getStatusText(_selectedFilter)}');

    // Add bill rows
    for (var i = 0; i < _filteredBills.length; i++) {
      final bill = _filteredBills[i];
      csv.writeln(
          '${i + 1},"${bill.customerName}","${bill.customerMobile}","${bill.date}",Rs.${bill.totalAmount},Rs.${bill.amountPaid},Rs.${bill.amountRemaining},"${_getStatusText(bill.status)}"');
    }

    await file.writeAsString(csv.toString());
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Bills'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(_showSearchBar ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _showSearchBar = !_showSearchBar;
                  if (!_showSearchBar) {
                    _searchController.clear();
                  }
                });
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showReportOptionsDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
            : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. Search Bar (Toggle Visibility) ---
                if (_showSearchBar)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12.0,
                      right: 12.0,
                      top: 0,
                      bottom: 8.0,
                    ),
                    child: Card(
                      elevation: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by customer name',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          filled: false,
                          fillColor: Theme.of(
                            context,
                          ).inputDecorationTheme.fillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),

                // --- 2. Filter Chips Row ---
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12.0,
                    right: 12.0,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.0,
                      vertical: 2.0,
                    ),
                    child: Row(
                      children: [
                        _buildFilterChip(PaymentFilter.all),
                        const SizedBox(width: 8),
                        _buildFilterChip(PaymentFilter.paid),
                        const SizedBox(width: 8),
                        _buildFilterChip(PaymentFilter.partial),
                        const SizedBox(width: 8),
                        _buildFilterChip(PaymentFilter.unpaid),
                      ],
                    ),
                  ),
                ),                // --- 3. Filtered Bills List ---
                Expanded(
                  child: _filteredBills.isEmpty
                      ? Center(
                          child: Text(
                            'No bills found',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredBills.length,
                          itemBuilder: (context, index) {
                            return _buildBillCard(_filteredBills[index]);
                          },
                        ),
                ),

                const SizedBox(height: 16),
              ],
            ),
    );
  }

  // Helper to build the status badge
  Widget _buildStatusBadge(PaymentFilter status) {
    Color color;
    String text;

    switch (status) {
      case PaymentFilter.paid:
        color = Colors.green;
        text = 'Paid';
        break;
      case PaymentFilter.partial:
        color = Colors.orange;
        text = 'Partial Payment';
        break;
      case PaymentFilter.unpaid:
        color = Colors.red;
        text = 'Unpaid';
        break;
      default:
        return const SizedBox.shrink(); // Hide 'All' filter on card
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build a single filter chip
  Widget _buildFilterChip(PaymentFilter filter) {
    final isSelected = _selectedFilter == filter;
    final cardColor = Theme.of(context).cardTheme.color;

    return FilterChip(
      label: Text(_getStatusText(filter)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
          _filterBills();
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: cardColor,
      selectedColor: Colors.blue.withOpacity(0.3),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.5),
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // Helper to build a single bill card
  Widget _buildBillCard(Bill bill) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      elevation: 1,
      child: InkWell(
        onTap: () {
          AppNavigator.push(
            context,
            ViewBillDetailsScreen(
              billId: bill.billId,
              billDate: bill.date,
              customerName: bill.customerName,
              customerMobile: bill.customerMobile,
              customerVehicle: bill.customerVehicle,
              totalAmount: bill.totalAmount,
              totalAmountPaid: bill.totalAmountPaid,
              amountPaid: bill.amountPaid,
              amountRemaining: bill.amountRemaining,
              products: bill.products,
              nextPaymentDate: bill.nextPaymentDate,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bottom Row: Customer Name and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bill.customerName,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  _buildStatusBadge(bill.status),
                ],
              ),
              // Top Row: Date and Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill Date: ${bill.date}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 14),
                  ),
                  Text(
                    bill.amount,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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

// --- Data Model for Bill Status ---
enum PaymentFilter { all, paid, partial, unpaid }

// --- Product Data Structure (Simplified) ---
class Bill {
  final String billId;
  final String date;
  final String customerName;
  final String customerMobile;
  final String? customerVehicle;
  final String amount;
  final PaymentFilter status;
  final String timestamp;
  final int totalAmount;
  final bool totalAmountPaid;
  final int amountPaid;
  final int amountRemaining;
  final List<Map<String, dynamic>>? products;
  final String? nextPaymentDate;

  Bill(
    this.billId,
    this.date,
    this.customerName,
    this.customerMobile,
    this.customerVehicle,
    this.amount,
    this.status,
    this.timestamp,
    this.totalAmount,
    this.totalAmountPaid,
    this.amountPaid,
    this.amountRemaining,
    this.products,
    this.nextPaymentDate,
  );
}
