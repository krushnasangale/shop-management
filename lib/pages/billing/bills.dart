import 'package:flashbill/pages/helpers/utils.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/services/bills_data_service.dart';

class Bills extends StatefulWidget {
  const Bills({super.key});

  @override
  State<Bills> createState() => _BillsState();
}

class _BillsState extends State<Bills> {
  PaymentFilter _selectedFilter = PaymentFilter.all;
  SortOption _selectedSort = SortOption.dateNewest;
  late String _userId;
  List<Bill> _allBills = [];
  List<Bill> _filteredBills = [];
  bool _isLoading = true;
  bool _showSearchBar = false;
  late TextEditingController _searchController;
  String _shopName = '--';
  DateTime? _reportStartDate;
  DateTime? _reportEndDate;
  final ScrollController _scrollController = ScrollController();
  final int _itemsPerPage = 100;
  int _currentlyLoadedItems = 100;
  bool _isLoadingMore = false;
  final ProfileService _profileService = ProfileService();
  final BillsDataService _billsDataService = BillsDataService();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterBills);
    _scrollController.addListener(_onScroll);
    _loadBills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _billsDataService.dispose();
    _profileService.dispose();
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
    if (_isLoadingMore || _currentlyLoadedItems >= _filteredBills.length) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    // Simulate loading delay for smooth UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _currentlyLoadedItems = (_currentlyLoadedItems + _itemsPerPage).clamp(
            0,
            _filteredBills.length,
          );
          _isLoadingMore = false;
        });
      }
    });
  }

  void _loadBills() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _userId = user.uid;

    _loadShopName();

    // Initialize BillsDataService
    _billsDataService.initialize(_userId);

    // Listen to bills stream
    _billsDataService.billsStream.listen(
      (billsData) {
        try {
          final bills = <Bill>[];

          for (var billData in billsData) {
            bills.add(_convertBillDataToBill(billData));
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
          print('Error processing bills data: $e');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      },
      onError: (error) {
        print('Bills stream error: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  // Helper method to convert raw bill data to Bill object
  Bill _convertBillDataToBill(Map<String, dynamic> billData) {
    final billId = billData['id'] as String;
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

    return Bill(
      billId,
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
      (billData['previousDueAmount'] as num?)?.toDouble() ?? 0.0,
      (billData['previousPaidAmount'] as num?)?.toDouble() ?? 0.0,
      billData['previousDueDescription'] ?? '',
    );
  }

  // Filter bills based on search query and payment status
  void _filterBills() {
    final query = _searchController.text.toLowerCase();

    List<Bill> filtered = _allBills;

    // Apply payment filter
    if (_selectedFilter != PaymentFilter.all) {
      if (_selectedFilter == PaymentFilter.previousDue) {
        filtered = filtered
            .where((bill) => bill.previousDueAmount > 0)
            .toList();
      } else {
        filtered = filtered
            .where((bill) => bill.status == _selectedFilter)
            .toList();
      }
    }

    // Apply search filter
    if (query.isNotEmpty) {
      filtered = filtered.where((bill) {
        return bill.customerName.toLowerCase().contains(query) ||
            bill.customerMobile.toLowerCase().contains(query);
      }).toList();
    }

    // Apply sorting
    _sortBills(filtered);

    if (mounted) {
      setState(() {
        _filteredBills = filtered;
        _currentlyLoadedItems = _itemsPerPage.clamp(0, filtered.length);
      });
    }
  }

  void _sortBills(List<Bill> bills) {
    switch (_selectedSort) {
      case SortOption.dateNewest:
        bills.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortOption.dateOldest:
        bills.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case SortOption.amountHighest:
        bills.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case SortOption.amountLowest:
        bills.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
        break;
      case SortOption.customerAZ:
        bills.sort((a, b) => a.customerName.compareTo(b.customerName));
        break;
      case SortOption.customerZA:
        bills.sort((a, b) => b.customerName.compareTo(a.customerName));
        break;
    }
  }

  Future<void> _showFilterSortBottomSheet(
    AppLocalizations localizations,
  ) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations.translate('filter_sort_options'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sort Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations.translate('sort_by'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (_selectedSort != SortOption.dateNewest)
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                setState(() {
                                  _selectedSort = SortOption.dateNewest;
                                  _filterBills();
                                });
                              });
                            },
                            icon: const Icon(Icons.clear, size: 16),
                            label: Text(localizations.translate('reset')),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...SortOption.values.map((option) {
                      final isSelected = _selectedSort == option;
                      return RadioListTile<SortOption>(
                        title: Text(
                          _getSortText(option, localizations),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        value: option,
                        groupValue: _selectedSort,
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() {
                              Navigator.pop(context);
                              setState(() {
                                _selectedSort = value;
                                _filterBills();
                              });
                            });
                          }
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getSortText(SortOption option, AppLocalizations localizations) {
    switch (option) {
      case SortOption.dateNewest:
        return localizations.translate('date_newest_first');
      case SortOption.dateOldest:
        return localizations.translate('date_oldest_first');
      case SortOption.amountHighest:
        return localizations.translate('amount_highest_first');
      case SortOption.amountLowest:
        return localizations.translate('amount_lowest_first');
      case SortOption.customerAZ:
        return localizations.translate('customer_az');
      case SortOption.customerZA:
        return localizations.translate('customer_za');
    }
  }

  // Helper to convert Enum to display string
  String _getStatusText(PaymentFilter filter, AppLocalizations localizations) {
    switch (filter) {
      case PaymentFilter.all:
        return localizations.translate('all');
      case PaymentFilter.paid:
        return localizations.translate('paid');
      case PaymentFilter.partial:
        return localizations.translate('partial_payment');
      case PaymentFilter.unpaid:
        return localizations.translate('unpaid');
      case PaymentFilter.previousDue:
        return 'Previous Due';
    }
  }

  // Static status text for PDF (always English)
  String _getPDFStatusText(PaymentFilter filter) {
    switch (filter) {
      case PaymentFilter.all:
        return 'All';
      case PaymentFilter.paid:
        return 'Paid';
      case PaymentFilter.partial:
        return 'Partial Payment';
      case PaymentFilter.unpaid:
        return 'Unpaid';
      case PaymentFilter.previousDue:
        return 'Previous Due';
    }
  }

  Future<void> _loadShopName() async {
    try {
      final profileData = await _profileService.getCurrentUserProfile();
      if (profileData != null && mounted) {
        setState(() {
          _shopName = (profileData['shopName'] as String?) ?? '--';
        });
      }
    } catch (e) {
      print('Error loading shop name: $e');
    }
  }

  void _showReportOptionsDialog(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                localizations.translate('generate_report'),
                style: context.bodyLargeText,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.translate('select_date_range')),
                    const SizedBox(height: 12),
                    // Start Date
                    OutlinedButton.icon(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _reportStartDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _reportStartDate = pickedDate;
                            if (_reportEndDate != null &&
                                _reportEndDate!.isBefore(_reportStartDate!)) {
                              _reportEndDate = null;
                            }
                          });
                          this.setState(() {});
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _reportStartDate == null
                            ? localizations.translate('start_date_optional')
                            : 'From: ${DateFormat('dd MMM yyyy').format(_reportStartDate!)}',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // End Date
                    OutlinedButton.icon(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _reportEndDate ?? DateTime.now(),
                          firstDate: _reportStartDate ?? DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _reportEndDate = pickedDate;
                          });
                          this.setState(() {});
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _reportEndDate == null
                            ? localizations.translate('end_date_optional')
                            : 'To: ${DateFormat('dd MMM yyyy').format(_reportEndDate!)}',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                    if (_reportStartDate != null || _reportEndDate != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _reportStartDate = null;
                            _reportEndDate = null;
                          });
                          this.setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                        label: Text(localizations.translate('clear_dates')),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(localizations.translate('select_format_to_export')),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.maxFinite,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(localizations.translate('export_as_pdf')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _generateAndSharePDF(localizations);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.maxFinite,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.table_chart),
                        label: Text(localizations.translate('export_as_csv')),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations.translate('cancel')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Bill> _getReportBills() {
    if (_reportStartDate == null && _reportEndDate == null) {
      return _filteredBills;
    }

    return _filteredBills.where((bill) {
      try {
        final billDate = DateFormat('dd MMM yyyy').parse(bill.date);

        if (_reportStartDate != null && _reportEndDate != null) {
          // Both dates selected - check if bill is within range
          return billDate.isAfter(
                _reportStartDate!.subtract(const Duration(days: 1)),
              ) &&
              billDate.isBefore(_reportEndDate!.add(const Duration(days: 1)));
        } else if (_reportStartDate != null) {
          // Only start date - bills from start date onwards
          return billDate.isAfter(
            _reportStartDate!.subtract(const Duration(days: 1)),
          );
        } else if (_reportEndDate != null) {
          // Only end date - bills up to end date
          return billDate.isBefore(
            _reportEndDate!.add(const Duration(days: 1)),
          );
        }
      } catch (e) {
        print('Error parsing date: ${bill.date}, error: $e');
      }
      return true;
    }).toList();
  }

  String _getDateRangeText() {
    if (_reportStartDate == null && _reportEndDate == null) {
      return 'All Dates';
    } else if (_reportStartDate != null && _reportEndDate != null) {
      return '${DateFormat('dd MMM yyyy').format(_reportStartDate!)} - ${DateFormat('dd MMM yyyy').format(_reportEndDate!)}';
    } else if (_reportStartDate != null) {
      return 'From ${DateFormat('dd MMM yyyy').format(_reportStartDate!)}';
    } else {
      return 'Up to ${DateFormat('dd MMM yyyy').format(_reportEndDate!)}';
    }
  }

  void _generateAndSharePDF(AppLocalizations localizations) async {
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
                      localizations.translate('generating_pdf'),
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

        await Share.shareXFiles([
          XFile(pdfFile.path),
        ], text: '${localizations.translate('bills_report_from')} $_shopName');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.translate('error_generating_pdf')}: $e',
            ),
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
        await Share.shareXFiles([
          XFile(csvFile.path),
        ], text: 'Bills Report (CSV) from $_shopName');
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
    final reportBills = _getReportBills();

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
                'Generated on: ${now.toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Filter: ${_getPDFStatusText(_selectedFilter)} | Date Range: ${_getDateRangeText()}',
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
                    children:
                        [
                              'S.No.',
                              'Customer',
                              'Mobile',
                              'Date',
                              'Amount',
                              'Status',
                            ]
                            .map(
                              (header) => pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(
                                  header,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  // Data rows
                  ...reportBills.asMap().entries.map((entry) {
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
                            _getPDFStatusText(bill.status),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total Bills: ${reportBills.length}',
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
    final reportBills = _getReportBills();

    // Create CSV header
    final csv = StringBuffer();
    csv.writeln(
      'S.No.,Customer Name,Mobile Number,Bill Date,Total Amount,Amount Paid,Amount Remaining,Status,Filter Applied: ${_getPDFStatusText(_selectedFilter)},Date Range: ${_getDateRangeText()}',
    );

    // Add bill rows
    for (var i = 0; i < reportBills.length; i++) {
      final bill = reportBills[i];
      csv.writeln(
        '${i + 1},"${bill.customerName}","${bill.customerMobile}","${bill.date}",Rs.${bill.totalAmount},Rs.${bill.amountPaid},Rs.${bill.amountRemaining},"${_getPDFStatusText(bill.status)}"',
      );
    }

    await file.writeAsString(csv.toString());
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('recent_bills')),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
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
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showReportOptionsDialog(context, localizations),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.grey.withOpacity(0.2),
            ),
            height: 40,
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.account_circle, size: 35),
              onPressed: () async {
                AppNavigator.push(context, const MyProfile());
              },
              tooltip: localizations.translate('my_profile'),
            ),
          ),
          const SizedBox(width: 14),
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
                      top: 5,
                      bottom: 8.0,
                    ),
                    child: Card(
                      elevation: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: localizations.translate(
                            'search_by_customer_name',
                          ),
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
                if (!_showSearchBar) const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, right: 12.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      children: [
                        // Combined Filter & Sort Button
                        FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune,
                                size: 14,
                                color: (_selectedSort != SortOption.dateNewest)
                                    ? Colors.blue[700]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(localizations.translate('filter_sort')),
                            ],
                          ),
                          selected: _selectedSort != SortOption.dateNewest,
                          onSelected: (selected) async {
                            await _showFilterSortBottomSheet(localizations);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Theme.of(context).cardTheme.color,
                          selectedColor: Colors.blue.withOpacity(0.2),
                          side: BorderSide(
                            color: (_selectedSort != SortOption.dateNewest)
                                ? Colors.blue
                                : Colors.grey.withOpacity(0.5),
                            width: 0.8,
                          ),
                          labelStyle: TextStyle(
                            color: (_selectedSort != SortOption.dateNewest)
                                ? Colors.blue
                                : null,
                            fontWeight:
                                (_selectedFilter != PaymentFilter.all ||
                                    _selectedSort != SortOption.dateNewest)
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: -1,
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -4,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(PaymentFilter.all, localizations),
                        const SizedBox(width: 8),
                        _buildFilterChip(PaymentFilter.paid, localizations),
                        const SizedBox(width: 8),
                        _buildFilterChip(PaymentFilter.partial, localizations),
                        const SizedBox(width: 8),
                        _buildFilterChip(PaymentFilter.unpaid, localizations),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          PaymentFilter.previousDue,
                          localizations,
                        ),
                      ],
                    ),
                  ),
                ), // --- 3. Filtered Bills List ---
                Expanded(
                  child: _filteredBills.isEmpty
                      ? Center(
                          child: Text(
                            localizations.translate('no_bills_found'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount:
                              _currentlyLoadedItems + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _currentlyLoadedItems) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildBillCard(
                              _filteredBills[index],
                              localizations,
                            );
                          },
                        ),
                ),

                const SizedBox(height: 16),
              ],
            ),
    );
  }

  // Helper to build the status badge
  Widget _buildStatusBadge(
    PaymentFilter status,
    AppLocalizations localizations,
  ) {
    Color color;
    String text;

    switch (status) {
      case PaymentFilter.paid:
        color = Colors.green;
        text = localizations.translate('paid');
        break;
      case PaymentFilter.partial:
        color = Colors.orange;
        text = localizations.translate('partial_payment');
        break;
      case PaymentFilter.unpaid:
        color = Colors.red;
        text = localizations.translate('unpaid');
        break;
      case PaymentFilter.previousDue:
        color = Colors.blue;
        text = 'Previous Due';
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
  Widget _buildFilterChip(
    PaymentFilter filter,
    AppLocalizations localizations,
  ) {
    final isSelected = _selectedFilter == filter;
    final cardColor = Theme.of(context).cardTheme.color;

    return FilterChip(
      label: Text(_getStatusText(filter, localizations)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
          _filterBills();
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: cardColor,
      selectedColor: Colors.blue.withOpacity(0.2),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.5),
        width: 0.8,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : null,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: -1),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // Helper to build a single bill card
  Widget _buildBillCard(Bill bill, AppLocalizations localizations) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.grey.withOpacity(0.2)
              : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
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
                previousDueAmount: bill.previousDueAmount,
                previousPaidAmount: bill.previousPaidAmount,
                previousDueDescription: bill.previousDueDescription,
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Customer Name and Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        bill.customerName,
                        style: context.titleLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildStatusBadge(bill.status, localizations),
                  ],
                ),

                const SizedBox(height: 4),

                // Bottom Row: Date and Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date Section
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          bill.date,
                          style: context.subtitleMedium?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),

                    // Amount Section
                    Text(
                      bill.amount,
                      style: context.titleLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),

                if (bill.previousDueAmount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: getOtherDueAmountColor(
                        bill.previousDueAmount,
                        bill.previousPaidAmount,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: bill.status == PaymentFilter.paid
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Other Due: ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '₹${bill.previousDueAmount}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              children: [
                                Text(
                                  'Paid: ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '₹${bill.previousPaidAmount}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Data Model for Bill Status ---
enum PaymentFilter { all, paid, partial, unpaid, previousDue }

// --- Sort Options ---
enum SortOption {
  dateNewest,
  dateOldest,
  amountHighest,
  amountLowest,
  customerAZ,
  customerZA,
}

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
  final double previousDueAmount;
  final double previousPaidAmount;
  final String previousDueDescription;

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
    this.previousDueAmount,
    this.previousPaidAmount,
    this.previousDueDescription,
  );
}
