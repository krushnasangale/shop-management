import 'dart:async';
import 'dart:io' show Platform, File;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flashbill/pages/purchase/add_purchase_entry.dart';
import 'package:flashbill/pages/purchase/purchase_supplier_wise_list.dart';
import 'package:flashbill/pages/purchase/purchase_entry_details.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PurchaseItemsList extends StatefulWidget {
  const PurchaseItemsList({super.key});

  @override
  State<PurchaseItemsList> createState() => _PurchaseItemsListState();
}

class _PurchaseItemsListState extends State<PurchaseItemsList>
    with SingleTickerProviderStateMixin {
  late CollectionReference _boughtRef;
  List<Map<String, dynamic>> _boughtEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  List<Map<String, dynamic>> _displayedEntries = [];
  Map<String, List<Map<String, dynamic>>> _customerBills = {};
  List<Map<String, dynamic>> _customerSummaries = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  late TextEditingController _searchController;
  bool _showSearchBar = false;
  final ScrollController _scrollController = ScrollController();
  int _displayedItemCount = 50;
  bool _isLoadingMore = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController = TextEditingController();
    _searchController.addListener(_filterEntries);
    _scrollController.addListener(_onScroll);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _boughtRef = FirebaseFirestore.instance
          .collection('purchases')
          .doc(user.uid)
          .collection('items');
      _loadBoughtEntriesRealtime();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore || _displayedItemCount >= _filteredEntries.length) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _displayedItemCount = (_displayedItemCount + 50).clamp(
            0,
            _filteredEntries.length,
          );
          _displayedEntries = _filteredEntries
              .take(_displayedItemCount)
              .toList();
          _isLoadingMore = false;
        });
      }
    });
  }

  void _loadBoughtEntriesRealtime() {
    _streamSubscription = _boughtRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              final entries = snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();

              // Group entries by customer/supplier
              final customerBills = <String, List<Map<String, dynamic>>>{};
              for (final entry in entries) {
                final supplierName = entry['supplierName'] ?? 'Unknown';
                if (!customerBills.containsKey(supplierName)) {
                  customerBills[supplierName] = [];
                }
                customerBills[supplierName]!.add(entry);
              }

              // Create customer summaries
              final customerSummaries = customerBills.entries.map((entry) {
                final supplierName = entry.key;
                final bills = entry.value;
                final totalAmount = bills.fold<double>(
                  0,
                  (sum, bill) =>
                      sum + ((bill['totalAmount'] ?? 0) as num).toDouble(),
                );
                final totalBills = bills.length;
                final lastPurchaseDate = bills.isNotEmpty
                    ? bills[0]['date'] ?? ''
                    : '';

                return {
                  'supplierName': supplierName,
                  'totalAmount': totalAmount,
                  'totalBills': totalBills,
                  'lastPurchaseDate': lastPurchaseDate,
                  'bills': bills,
                };
              }).toList();

              // Sort customer summaries by total amount descending
              customerSummaries.sort(
                (a, b) => (b['totalAmount'] as double).compareTo(
                  a['totalAmount'] as double,
                ),
              );

              setState(() {
                _boughtEntries = entries;
                _customerBills = customerBills;
                _customerSummaries = customerSummaries;
                _filteredEntries = entries;
                _displayedItemCount = 50;
                _displayedEntries = entries.take(_displayedItemCount).toList();
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            print('Error loading bought entries: $error');
            setState(() {
              _isLoading = false;
            });
          },
        );
  }

  void _filterEntries() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredEntries = _boughtEntries;
        _displayedItemCount = 50;
        _displayedEntries = _filteredEntries.take(_displayedItemCount).toList();
      });
    } else {
      setState(() {
        _filteredEntries = _boughtEntries.where((entry) {
          final supplierName = (entry['supplierName'] ?? '')
              .toString()
              .toLowerCase();
          final totalAmount = (entry['totalAmount'] ?? '').toString();
          return supplierName.contains(query) || totalAmount.contains(query);
        }).toList();
        _displayedItemCount = 50;
        _displayedEntries = _filteredEntries.take(_displayedItemCount).toList();
      });
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTotalQuantityBadge(Map<String, dynamic> entry) {
    // Get total quantity from entry
    final totalQuantity = (entry['totalUnits'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.purple),
          const SizedBox(width: 4),
          Text(
            '$totalQuantity Qty',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBillsTab() {
    return Column(
      children: [
        // Search Bar
        if (_showSearchBar)
          Padding(
            padding: const EdgeInsets.only(
              left: 12.0,
              right: 12.0,
              top: 5,
              bottom: 0,
            ),
            child: Card(
              elevation: 2,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      AppLocalizations.of(context)?.searchBySupplierOrAmount ??
                      'Search by supplier or amount',
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
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        // List
        Expanded(
          child: _filteredEntries.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)?.noMatchingEntriesFound ??
                        'No matching entries found',
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount:
                      _displayedEntries.length + (_isLoadingMore ? 1 : 0),
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                  itemBuilder: (context, index) {
                    if (index == _displayedEntries.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final entry = _displayedEntries[index];
                    final date = entry['date'] ?? 'N/A';
                    final supplierName = entry['supplierName'] ?? 'Unknown';
                    final totalAmount = entry['totalAmount'] ?? 0;
                    final totalProducts = entry['totalProducts'] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Card(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PurchaseEntryDetails(entry: entry),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              supplierName,
                                              style: context.bodyLargeText
                                                  ?.copyWith(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  date,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '₹$totalAmount',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Divider
                                  Divider(
                                    height: 1,
                                    color: Colors.grey.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 8),
                                  // Bottom Section with Details
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$totalProducts ${AppLocalizations.of(context)?.products ?? 'Products'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            AppLocalizations.of(
                                                  context,
                                                )?.purchased ??
                                                'Purchased',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue[400],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // display total quantity bought
                                      _buildTotalQuantityBadge(entry),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              AppLocalizations.of(
                                                    context,
                                                  )?.received ??
                                                  'Received',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
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
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCustomerBillsTab() {
    return _customerSummaries.isEmpty
        ? Center(
            child: Text(
              AppLocalizations.of(context)?.noPurchasedEntriesYet ??
                  'No purchased entries yet',
            ),
          )
        : ListView.builder(
            itemCount: _customerSummaries.length,
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            itemBuilder: (context, index) {
              final summary = _customerSummaries[index];
              final supplierName = summary['supplierName'] ?? 'Unknown';
              final totalAmount = summary['totalAmount'] ?? 0.0;
              final totalBills = summary['totalBills'] ?? 0;
              final lastPurchaseDate = summary['lastPurchaseDate'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Card(
                    child: InkWell(
                      onTap: () {
                        // Navigate to customer-specific bill list
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerBillsPage(
                              supplierName: supplierName,
                              bills: summary['bills'] ?? [],
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        supplierName,
                                        style: context.bodyLargeText?.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 12,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Last: $lastPurchaseDate',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '₹${totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Stats Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.receipt,
                                        size: 14,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$totalBills Bills',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.business,
                                        size: 14,
                                        color: Colors.purple,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Supplier',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.purple,
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
                    ),
                  ),
                ),
              );
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.purchasedEntries ?? 'Purchased Entries'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          // Scan Invoice Button
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: localizations?.scanInvoice ?? 'Scan Invoice',
            onPressed: () {
              _showScanOptions(context);
            },
          ),
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
              tooltip: localizations?.myProfile ?? 'My Profile',
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _boughtEntries.isEmpty
          ? Center(
              child: Text(
                localizations?.noPurchasedEntriesYet ??
                    'No purchased entries yet',
              ),
            )
          : Column(
              children: [
                // Modern toggle buttons for tabs
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: ToggleButtons(
                    isSelected: [
                      _tabController.index == 0,
                      _tabController.index == 1,
                    ],
                    onPressed: (index) {
                      setState(() {
                        _tabController.animateTo(index);
                      });
                    },
                    borderRadius: BorderRadius.circular(10.0),
                    selectedColor: Colors.white,
                    fillColor: Theme.of(context).primaryColor,
                    color: Colors.grey[600],
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    constraints: const BoxConstraints(
                      minHeight: 40.0,
                      minWidth: 140.0,
                    ),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time, size: 20),
                          const SizedBox(width: 8),
                          Text('Recent'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business, size: 20),
                          const SizedBox(width: 8),
                          Text('By Supplier'),
                        ],
                      ),
                    ],
                  ),
                ),
                // Tab Bar View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecentBillsTab(),
                      _buildCustomerBillsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showScanOptions(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations?.scanInvoice ?? 'Scan Invoice',
                    style: context.headingMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ListTile(
              //   leading: Container(
              //     padding: const EdgeInsets.all(10),
              //     decoration: BoxDecoration(
              //       color: Colors.blue.withOpacity(0.1),
              //       borderRadius: BorderRadius.circular(10),
              //     ),
              //     child: const Icon(Icons.camera_alt, color: Colors.blue),
              //   ),
              //   title: const Text('Take Photo'),
              //   subtitle: const Text('Capture invoice with camera'),
              //   onTap: () {
              //     Navigator.pop(context);
              //     _scanFromCamera();
              //   },
              // ),
              // const Divider(),
              // ListTile(
              //   leading: Container(
              //     padding: const EdgeInsets.all(10),
              //     decoration: BoxDecoration(
              //       color: Colors.green.withOpacity(0.1),
              //       borderRadius: BorderRadius.circular(10),
              //     ),
              //     child: const Icon(Icons.photo_library, color: Colors.green),
              //   ),
              //   title: const Text('Choose from Gallery'),
              //   subtitle: const Text('Select invoice from photos'),
              //   onTap: () {
              //     Navigator.pop(context);
              //     _scanFromGallery();
              //   },
              // ),
              // const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                ),
                title: Text(localizations?.selectPDF ?? 'Select PDF'),
                subtitle: Text(
                  localizations?.choosePDFInvoice ?? 'Choose PDF invoice',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _scanFromPDF();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanFromCamera() async {
    final localizations = AppLocalizations.of(context);
    try {
      final ImagePicker picker = ImagePicker();
      print('Opening camera...');

      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        maxWidth: 3000, // Increase max resolution for better OCR
        maxHeight: 4000,
        preferredCameraDevice: CameraDevice.rear,
      );

      print('Photo captured: ${image?.path}');

      if (image != null && mounted) {
        await _processImage(image.path);
      } else {
        print('No photo captured or widget not mounted');
      }
    } catch (e, stackTrace) {
      print('Error in _scanFromCamera: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.error ?? 'Error'}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _scanFromGallery() async {
    final localizations = AppLocalizations.of(context);
    try {
      final ImagePicker picker = ImagePicker();
      print('Opening gallery picker...');

      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 3000, // Increase max resolution for better OCR
        maxHeight: 4000,
      );

      print('Image selected: ${image?.path}');

      if (image != null && mounted) {
        await _processImage(image.path);
      } else {
        print('No image selected or widget not mounted');
      }
    } catch (e, stackTrace) {
      print('Error in _scanFromGallery: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.error ?? 'Error'}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Helper method to show limited data detection dialog
  void _showLimitedDataDialog(
    int textLength,
    Map<String, dynamic> invoiceData,
  ) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                localizations?.limitedDataDetected ?? 'Limited Data Detected',
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations?.pdfNotGivingGoodResults ??
                    'This PDF is not giving us good results. Please try a different PDF.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                localizations?.tryDifferentPDF ?? 'For better results, try:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              _buildSuggestionRow(
                Icons.camera_alt,
                Colors.blue,
                localizations?.takeClearPhotoWithGoodLighting ??
                    'Take a clear photo with good lighting',
              ),
              SizedBox(height: 8),
              _buildSuggestionRow(
                Icons.picture_as_pdf,
                Colors.orange,
                localizations?.usePDFScanForBetterTableExtraction ??
                    'Use PDF scan for better table extraction',
              ),
              SizedBox(height: 8),
              _buildSuggestionRow(
                Icons.zoom_in,
                Colors.purple,
                localizations?.ensureTextIsLargeAndReadableInPhoto ??
                    'Ensure text is large and readable in photo',
              ),
              SizedBox(height: 8),
              _buildSuggestionRow(
                Icons.edit,
                Colors.green,
                localizations?.manuallyEnterPurchaseDetails ??
                    'Manually enter the purchase details',
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizations
                                ?.tipPDFScanningWorksBestForTableBasedInvoices ??
                            'Tip: PDF scanning works best for table-based invoices',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showScanOptions(context); // Open PDF selection popup again
            },
            child: Text(localizations?.retryScan ?? 'Retry Scan'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddPurchaseEntry(existingEntry: invoiceData),
                ),
              );
            },
            child: Text(localizations?.continueAnyway ?? 'Continue Anyway'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
      ],
    );
  }

  Future<void> _scanFromPDF() async {
    final localizations = AppLocalizations.of(context);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null && mounted) {
          await _processPDF(file.path!);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localizations?.couldNotAccessPDFFile ??
                      'Could not access PDF file',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations?.errorSelectingPDF ?? 'Error selecting PDF'}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processPDF(String pdfPath) async {
    // Show loading dialog with enhanced UI
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final localizations = AppLocalizations.of(context);
          return WillPopScope(
            onWillPop: () async => false,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      localizations?.processingInvoice ?? 'Processing Invoice',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations?.extractingTextFromPDF ??
                          'Extracting text from PDF...',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations?.loading ?? 'Please wait',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    try {
      // Load the PDF document
      final File file = File(pdfPath);
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      // Extract text from all pages
      String extractedText = '';
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      for (int i = 0; i < document.pages.count; i++) {
        final String pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        extractedText += '$pageText\n';
      }

      // Clean up
      document.dispose();

      // Parse invoice data
      final invoiceData = _parseInvoiceText(extractedText);
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Check if PDF extraction failed to get meaningful data
        if (invoiceData['products'].length == 0 && extractedText.length < 500) {
          // Show helpful dialog
          _showLimitedDataDialog(extractedText.length, invoiceData);
        } else {
          // Navigate directly to purchase entry form with parsed invoice data
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddPurchaseEntry(existingEntry: invoiceData),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _processImage(String imagePath) async {
    final localizations = AppLocalizations.of(context);
    // Show loading dialog with enhanced UI
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final localizations = AppLocalizations.of(context);
          return WillPopScope(
            onWillPop: () async => false,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      localizations?.scanningInvoice ?? 'Scanning Invoice',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations?.analyzingImageWithOCR ??
                          'Analyzing image with OCR...',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations?.loading ?? 'Please wait',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    try {
      String extractedText = '';

      // Check if running on mobile platforms (Android/iOS)
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        // Mobile: Use Google ML Kit
        final textRecognizer = TextRecognizer(
          script: TextRecognitionScript.latin,
        );

        final inputImage = InputImage.fromFilePath(imagePath);
        final RecognizedText recognizedText = await textRecognizer.processImage(
          inputImage,
        );
        // Method 1: Get simple text (original method)
        String simpleText = recognizedText.text;
        // Method 2: Extract line by line from all blocks (better for tables)
        StringBuffer detailedText = StringBuffer();
        int totalLines = 0;

        for (int i = 0; i < recognizedText.blocks.length; i++) {
          final block = recognizedText.blocks[i];
          // Process each line in the block
          for (int j = 0; j < block.lines.length; j++) {
            final line = block.lines[j];
            totalLines++;

            // Extract elements (words) from the line
            List<String> lineElements = [];
            for (var element in line.elements) {
              lineElements.add(element.text);
            }

            // Join elements with spaces for this line
            String lineText = lineElements.join(' ');
            if (lineText.isNotEmpty) {
              detailedText.writeln(lineText);
              if (totalLines <= 20) {
                // Log first 20 lines
                debugPrint('  Line $j: $lineText');
              }
            }
          }
        }
        // Use the method that extracted more text
        if (detailedText.length > simpleText.length) {
          extractedText = detailedText.toString();
        } else {
          extractedText = simpleText;
        }

        // Clean up
        await textRecognizer.close();
      } else {
        // Desktop/Web: OCR not supported
        throw Exception(
          localizations?.invoiceScanningOnlyAvailableOnMobile ??
              'Invoice scanning with OCR is only available on Android and iOS devices. '
                  'Please run this app on a mobile device to use the invoice scanning feature.',
        );
      }

      // Parse invoice data
      final invoiceData = _parseInvoiceText(extractedText);
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Check if OCR failed to extract meaningful data
        if (invoiceData['products'].length == 0 && extractedText.length < 500) {
          _showLimitedDataDialog(extractedText.length, invoiceData);
        } else {
          // Navigate directly to purchase entry form with parsed invoice data
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddPurchaseEntry(existingEntry: invoiceData),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations?.errorProcessingInvoice ?? 'Error processing invoice'}: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Map<String, dynamic> _parseInvoiceText(String text) {
    // Enhanced parser with better pattern matching
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    String? supplierName;
    String? date;
    double? total;
    List<Map<String, dynamic>> products = [];

    // Enhanced patterns for better detection
    final datePatterns = [
      RegExp(r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})'), // DD-MM-YYYY or DD/MM/YYYY
      RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})'), // YYYY-MM-DD
      RegExp(
        r'date[:\s]*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
        caseSensitive: false,
      ),
    ];

    final totalPatterns = [
      RegExp(
        r'invoice\s*amount[:\s]*₹?\$?\s*([0-9,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(r'total[:\s]*₹?\$?\s*([0-9,]+\.?\d*)', caseSensitive: false),
      RegExp(r'sub\s*total[:\s]*₹?\$?\s*([0-9,]+\.?\d*)', caseSensitive: false),
      RegExp(
        r'grand\s*total[:\s]*₹?\$?\s*([0-9,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(
        r'net\s*amount[:\s]*₹?\$?\s*([0-9,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(r'amount[:\s]*₹?\$?\s*([0-9,]+\.?\d*)', caseSensitive: false),
      RegExp(r'₹\s*([0-9,]+\.?\d*)\s*total', caseSensitive: false),
      RegExp(r'\$\s*([0-9,]+\.?\d*)\s*total', caseSensitive: false),
    ];
    // Multiple product line patterns to handle various formats
    final productPatterns = [
      // Format: "Product Name 2 pcs $100.00"
      RegExp(
        r'^(.+?)\s+(\d+)\s*(?:pcs?|pc|nos?|no|piece|units?|hrs?|hours?)\s*(?:at\s*)?[\$₹]?\s*([0-9,]+\.?\d*)',
        caseSensitive: false,
      ),
      // Format: "Product Name $100.00"
      RegExp(r'^(.+?)[\$₹]\s*([0-9,]+\.?\d*)$', caseSensitive: false),
      // Format: "Product: 5 hours at $75/hr"
      RegExp(
        r'^(.+?):\s*(\d+)\s*(?:hours?|hrs?)\s*at\s*[\$₹]?\s*([0-9,]+\.?\d*)',
        caseSensitive: false,
      ),
    ];

    // Extract supplier name - look for company/business names
    // Usually in first few lines, longer text without keywords
    for (int i = 0; i < lines.length && i < 10; i++) {
      final line = lines[i];
      // Skip common headers and keywords
      if (line.toLowerCase().contains('invoice') ||
          line.toLowerCase().contains('bill to') ||
          line.toLowerCase().contains('ship to') ||
          line.toLowerCase().contains('order') ||
          line.toLowerCase().contains('date') ||
          line.toLowerCase().contains('phone') ||
          line.toLowerCase().contains('address') ||
          line.toLowerCase().contains('city') ||
          line.toLowerCase().contains('description') ||
          line.contains('[') ||
          line.contains('(000)') ||
          line.length < 3 ||
          line.length > 100) {
        continue;
      }

      // Look for business name patterns
      if (supplierName == null) {
        final hasNumber = RegExp(r'\d').hasMatch(line);
        final hasSpecialChars = RegExp(r'[!@#%^&*()]').hasMatch(line);

        if (!hasNumber && !hasSpecialChars) {
          supplierName = line;
        }
      }
    }

    // Extract date
    for (var line in lines) {
      if (date != null) break;
      for (var pattern in datePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          date = match.group(1) ?? match.group(0);
          break;
        }
      }
    }

    // Extract total amount - scan more lines and check adjacent lines
    for (int i = lines.length - 1; i >= 0 && i >= lines.length - 30; i--) {
      final line = lines[i];
      if (total != null) break;
      // Check if line contains total-related keywords
      if (line.toLowerCase().contains('total') ||
          line.toLowerCase().contains('amount') ||
          line.toLowerCase().contains('payable')) {
        // Check current line and next 3 lines for amount
        for (int j = i; j < i + 4 && j < lines.length; j++) {
          final checkLine = lines[j];
          final amountMatch = RegExp(
            r'₹\s*([0-9,]+\.?\d*)',
          ).firstMatch(checkLine);
          if (amountMatch != null) {
            final totalStr = amountMatch.group(1)?.replaceAll(',', '') ?? '';
            final potentialTotal = double.tryParse(totalStr);
            if (potentialTotal != null && potentialTotal > 100) {
              total = potentialTotal;
              break;
            }
          }
        }
        if (total != null) break;
      }

      // Also try existing patterns
      for (var pattern in totalPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final totalStr = match.group(1)?.replaceAll(',', '') ?? '';
          total = double.tryParse(totalStr);
          if (total != null && total > 0) {
            break;
          }
        }
      }
    }

    if (total == null || total == 0.0) {
      // NEW: Try to find any large amount with ₹ symbol as potential total
      // Scan entire document for amounts > 1000
      List<double> largeAmounts = [];
      for (var line in lines) {
        final amountMatches = RegExp(r'₹\s*([0-9,]+\.?\d*)').allMatches(line);
        for (var match in amountMatches) {
          final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
          final amount = double.tryParse(amountStr);
          if (amount != null && amount > 500) {
            largeAmounts.add(amount);
          }
        }
      }

      // Use the largest amount as total if available
      if (largeAmounts.isNotEmpty) {
        total = largeAmounts.reduce((a, b) => a > b ? a : b);
      }
    }

    // Find where the product table section starts
    bool inProductSection = false;
    int productCount = 0;
    int productSectionStartLine = -1;

    // Find the table header with "Item name"
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.toLowerCase().contains('item name') ||
          line.toLowerCase().contains('description') ||
          (line.toLowerCase().contains('item') &&
              (line.toLowerCase().contains('quantity') ||
                  line.toLowerCase().contains('unit')))) {
        inProductSection = true;
        productSectionStartLine = i;
        break;
      }
    }

    if (inProductSection && productSectionStartLine >= 0) {
      // Use row number sequencing for accurate product extraction
      int expectedRowNumber = 1;

      for (int i = productSectionStartLine + 1; i < lines.length; i++) {
        final line = lines[i].trim();

        // Stop at footer section - look for "Total" with large quantity or amount
        if (line.toLowerCase() == 'total') {
          // Check if next few lines have large numbers (143 items, ₹10,000+)
          bool isFooterTotal = false;
          for (int j = i + 1; j < i + 3 && j < lines.length; j++) {
            final checkLine = lines[j].trim();
            // If we see a very large quantity (>100) or the total amount, it's footer
            final largeQty = RegExp(r'^(\d{3,})$').hasMatch(checkLine); // 100+
            final hasTotal = RegExp(
              r'₹\s*([0-9,]{4,})',
            ).hasMatch(checkLine); // ₹1000+
            if (largeQty || hasTotal) {
              isFooterTotal = true;
              break;
            }
          }
          if (isFooterTotal) {
            break;
          }
        }

        // Also stop at other footer markers
        if (line.toLowerCase().contains('sub total') ||
            line.toLowerCase().contains('subtotal') ||
            line.toLowerCase().contains('invoice amount') ||
            line.toLowerCase().contains('payment mode') ||
            line.toLowerCase().contains('description') ||
            line.toLowerCase().contains('terms and conditions')) {
          break;
        }

        // Check if this line is the next sequential row number
        final isRowNumber = RegExp(r'^\d{1,2}$').hasMatch(line);
        final lineNumber = int.tryParse(line) ?? -1;
        final isSequentialRowNumber =
            isRowNumber && lineNumber == expectedRowNumber;

        if (isSequentialRowNumber) {
          // Next line should be product name
          if (i + 1 >= lines.length) break;
          var productName = lines[i + 1].trim();
          // Validate product name - must not be a unit marker or empty
          final unitPattern = RegExp(
            r'^(pcs?|nos?|piece|unit|hrs?|hours?|box|boxes|kg|kgs|ltr|litre|rolls?|rol|set|sets|pair|pairs|mtr|meter|metres)$',
            caseSensitive: false,
          );

          if (productName.isEmpty ||
              productName.length < 2 ||
              unitPattern.hasMatch(productName)) {
            continue; // Don't increment expectedRowNumber
          }

          // Check if next line is a continuation of product name
          // (not a number, unit, or price - just more text)
          int nameEndOffset = 2; // Default: product name ends at i+1
          if (i + 2 < lines.length) {
            final nextLine = lines[i + 2].trim();
            final isNotNumber = !RegExp(r'^\d+(\.\d+)?$').hasMatch(nextLine);
            final isNotUnit = !unitPattern.hasMatch(nextLine);
            final isNotPrice = !nextLine.contains('₹');

            // If next line is 2-30 chars of text (not number/unit/price), it's a continuation
            if (isNotNumber &&
                isNotUnit &&
                isNotPrice &&
                nextLine.length >= 2 &&
                nextLine.length <= 30) {
              productName = '$productName $nextLine';
              nameEndOffset = 3; // Product name ends at i+2
            }
          }

          // Extract quantity, unit, and price from lines after product name
          int quantity = 1;
          double price = 0.0;
          String unitMarker = 'Pcs'; // Default to Pcs
          bool foundUnit = false;

          for (int j = i + nameEndOffset; j < i + 15 && j < lines.length; j++) {
            final checkLine = lines[j].trim();

            // Look for unit marker (Pcs, Nos, etc.)
            if (!foundUnit && unitPattern.hasMatch(checkLine)) {
              unitMarker = checkLine;
              foundUnit = true;
              // Quantity is 1-3 lines before unit (after product name)
              for (int k = j - 1; k >= i + nameEndOffset && k >= j - 3; k--) {
                final qtyLine = lines[k].trim();
                // Match standalone numbers 1-999
                if (RegExp(r'^\d{1,3}$').hasMatch(qtyLine)) {
                  quantity = int.tryParse(qtyLine) ?? 1;
                  if (quantity > 0 && quantity < 1000) {
                    break;
                  }
                }
              }

              // Price is 1-3 lines after unit (with ₹ symbol)
              for (int k = j + 1; k < j + 4 && k < lines.length; k++) {
                final priceLine = lines[k].trim();
                final priceMatch = RegExp(
                  r'₹\s*([0-9,]+\.?\d*)',
                ).firstMatch(priceLine);
                if (priceMatch != null && price == 0.0) {
                  final priceStr =
                      priceMatch.group(1)?.replaceAll(',', '') ?? '0';
                  price = double.tryParse(priceStr) ?? 0.0;
                  if (price > 0 && price < 100000) {
                    break;
                  }
                }
              }
              break; // Found unit, stop searching
            }
          }

          // Fallback: If no unit found, search for quantity and price directly
          if (!foundUnit) {
            // Search for quantity (first standalone number 1-999)
            for (
              int j = i + nameEndOffset;
              j < i + nameEndOffset + 5 && j < lines.length;
              j++
            ) {
              final qtyLine = lines[j].trim();
              if (RegExp(r'^\d{1,3}$').hasMatch(qtyLine)) {
                final qty = int.tryParse(qtyLine);
                if (qty != null && qty > 0 && qty < 1000) {
                  quantity = qty;
                  break;
                }
              }
            }

            // Search for price (line with ₹ symbol)
            for (
              int j = i + nameEndOffset;
              j < i + nameEndOffset + 8 && j < lines.length;
              j++
            ) {
              final priceLine = lines[j].trim();
              final priceMatch = RegExp(
                r'₹\s*([0-9,]+\.?\d*)',
              ).firstMatch(priceLine);
              if (priceMatch != null && price == 0.0) {
                final priceStr =
                    priceMatch.group(1)?.replaceAll(',', '') ?? '0';
                price = double.tryParse(priceStr) ?? 0.0;
                if (price > 0 && price < 100000) {
                  break;
                }
              }
            }
          }

          // Add product if valid
          if (productName.isNotEmpty && price > 0) {
            products.add({
              'name': productName,
              'quantity': quantity,
              'price': price,
              'unit': unitMarker,
            });
            productCount++;
            expectedRowNumber++; // Move to next row number
          }
        }
      }
    }

    // If no products found with table method, try inline patterns
    if (products.isEmpty) {
      inProductSection = false;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // Skip empty or very short lines
        if (line.length < 3) continue;

        // Detect start of product section
        if (line.toLowerCase().contains('description') ||
            line.toLowerCase().contains('item') ||
            line.toLowerCase().contains('product') ||
            line.toLowerCase().contains('service')) {
          inProductSection = true;
          continue;
        }

        // Detect end of product section
        if ((line.toLowerCase().contains('total') ||
                line.toLowerCase().contains('subtotal') ||
                line.toLowerCase().contains('tax') ||
                line.toLowerCase().contains('discount')) &&
            RegExp(r'[\$₹]\s*[0-9,]+\.?\d*').hasMatch(line)) {
          break;
        }

        // Skip header-like lines
        if (!inProductSection) continue;

        // Skip lines that are clearly not products
        if (line.toLowerCase().contains('phone') ||
            line.toLowerCase().contains('email') ||
            line.toLowerCase().contains('address') ||
            line.toLowerCase().contains('payment') ||
            line.contains('[') ||
            line.contains(']')) {
          continue;
        }

        // Try each product pattern
        bool matched = false;

        for (var pattern in productPatterns) {
          final match = pattern.firstMatch(line);
          if (match != null) {
            String productName = '';
            int quantity = 1;
            double price = 0.0;

            // Handle different pattern groups
            if (match.groupCount >= 3) {
              // Pattern with quantity: "Product 5 pcs $100"
              productName = match.group(1)?.trim() ?? '';
              quantity = int.tryParse(match.group(2) ?? '1') ?? 1;
              final priceStr = match.group(3)?.replaceAll(',', '') ?? '0';
              price = double.tryParse(priceStr) ?? 0.0;
            } else if (match.groupCount == 2) {
              // Pattern without quantity: "Product $100"
              productName = match.group(1)?.trim() ?? '';
              quantity = 1;
              final priceStr = match.group(2)?.replaceAll(',', '') ?? '0';
              price = double.tryParse(priceStr) ?? 0.0;
            }

            // Validate and add product
            if (productName.isNotEmpty &&
                price > 0 &&
                !productName.toLowerCase().contains('total') &&
                !productName.toLowerCase().contains('tax') &&
                productName.length > 2) {
              products.add({
                'name': productName,
                'quantity': quantity,
                'price': price,
                'unit': 'Pcs', // Default unit for inline products
              });
              productCount++;
              matched = true;
              break;
            }
          }
        }

        // If no pattern matched, try flexible extraction
        if (!matched && inProductSection) {
          // Look for any line with a price ($ or ₹ followed by number)
          final priceMatch = RegExp(
            r'[\$₹]\s*([0-9,]+\.?\d*)',
          ).firstMatch(line);

          if (priceMatch != null) {
            final priceStr = priceMatch.group(1)?.replaceAll(',', '') ?? '0';
            final price = double.tryParse(priceStr) ?? 0.0;

            if (price > 0) {
              // Extract product name by removing the price part
              String productName = line
                  .replaceAll(priceMatch.group(0) ?? '', '')
                  .trim();

              // Try to extract quantity if present
              int quantity = 1;
              final qtyMatch = RegExp(
                r'(\d+)\s*(?:pcs?|pc|nos?|no|piece|units?|hrs?|hours?)',
                caseSensitive: false,
              ).firstMatch(productName);

              if (qtyMatch != null) {
                quantity = int.tryParse(qtyMatch.group(1) ?? '1') ?? 1;
                // Remove quantity from product name
                productName = productName
                    .replaceAll(qtyMatch.group(0) ?? '', '')
                    .trim();
              }

              // Clean up product name
              productName = productName
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .replaceAll(RegExp(r'^[\d\s.,:;-]+'), '')
                  .replaceAll(RegExp(r'[\d\s.,:;-]+$'), '')
                  .trim();

              if (productName.isNotEmpty &&
                  productName.length > 2 &&
                  !productName.toLowerCase().contains('total') &&
                  !productName.toLowerCase().contains('tax') &&
                  !productName.toLowerCase().contains('subtotal')) {
                products.add({
                  'name': productName,
                  'quantity': quantity,
                  'price': price,
                  'unit': 'Pcs', // Default unit for flexible extraction
                });
                productCount++;
              }
            }
          }
        }
      }
    } // End of if (products.isEmpty) block

    // If no date found, use current date
    if (date == null || date.isEmpty) {
      final now = DateTime.now();
      date =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    }

    return {
      'supplierName': supplierName ?? 'Unknown Supplier',
      'date': date,
      'total': total ?? 0.0,
      'products': products,
      'rawText': text, // Store raw text for debugging
    };
  }
}
