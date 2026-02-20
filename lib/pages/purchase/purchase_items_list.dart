import 'dart:async';
import 'dart:io';
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
import 'package:flashbill/services/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/utils/search_utils.dart';
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
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _filteredEntries = _boughtEntries;
        _displayedItemCount = 50;
        _displayedEntries = _filteredEntries.take(_displayedItemCount).toList();
      });
    } else {
      setState(() {
        _filteredEntries = _boughtEntries.where((entry) {
          final supplierName = (entry['supplierName'] ?? '').toString();
          final totalAmount = (entry['totalAmount'] ?? '').toString();
          return SearchUtils.matchesSubsequence(supplierName, query) ||
              SearchUtils.matchesSubsequence(totalAmount, query);
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
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          width: 1,
                          color: Colors.black.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 0,
                            offset: const Offset(0, 0),
                            spreadRadius: 1,
                          ),
                        ],
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.95),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
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
                                      borderRadius: BorderRadius.circular(6),
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
                                crossAxisAlignment: CrossAxisAlignment.center,
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
                                      borderRadius: BorderRadius.circular(6),
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    width: 1,
                    color: Colors.black.withOpacity(0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 0,
                      offset: const Offset(0, 0),
                      spreadRadius: 1,
                    ),
                  ],
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.white.withOpacity(0.95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
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
                      vertical: 8,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                '₹ ${totalAmount == totalAmount.toInt() ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                      fontSize: 14,
                    ),
                    constraints: const BoxConstraints(
                      minHeight: 40.0,
                      minWidth: 160.0,
                    ),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time, size: 20),
                          const SizedBox(width: 8),
                          Text(localizations?.recent ?? 'Recent'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business, size: 20),
                          const SizedBox(width: 8),
                          Text(localizations?.bySupplier ?? 'By Supplier'),
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
                const SizedBox(height: 20),
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
              // Only show camera option on mobile devices
              if (Platform.isAndroid || Platform.isIOS) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.blue),
                  ),
                  title: Text(localizations?.takePhoto ?? 'Take Photo'),
                  subtitle: Text(
                    localizations?.captureInvoiceWithCamera ??
                        'Capture invoice with camera',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _scanFromCamera();
                  },
                ),
                const Divider(),
              ],
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: Text(
                  localizations?.chooseFromGallery ?? 'Choose from Gallery',
                ),
                subtitle: Text(
                  localizations?.selectInvoiceFromPhotos ??
                      'Select invoice from photos',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _scanFromGallery();
                },
              ),
              const Divider(),
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.choosePDFInvoice ?? 'Choose PDF invoice',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations?.pdfScanLimitInfo ??
                          'Supports up to 5 pages • Best for table-based invoices',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
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
    final loc = AppLocalizations.of(context);
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
                  loc?.couldNotAccessPDFFile ?? 'Could not access PDF file',
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
              '${loc?.errorSelectingPDF ?? 'Error selecting PDF'}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processPDF(String pdfPath) async {
    final loc = AppLocalizations.of(context);

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
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
                      loc?.processingInvoice ?? 'Processing Invoice',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Powered by Gemini AI',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
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
      // Extract text from PDF
      final File file = File(pdfPath);
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      String extractedText = '';
      final PdfTextExtractor extractor = PdfTextExtractor(document);

      // Limit to first 5 pages to support multi-page invoices
      // while avoiding token limits and rate limiting
      final int maxPages = document.pages.count > 5 ? 5 : document.pages.count;

      for (int i = 0; i < maxPages; i++) {
        final String pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        extractedText += '$pageText\n';

        // Stop if we have enough text (15000 chars handles most multi-page invoices)
        if (extractedText.length > 15000) {
          extractedText = extractedText.substring(0, 15000);
          break;
        }
      }
      document.dispose();

      // Use Gemini to extract invoice data
      final geminiService = GeminiService();
      final invoiceData = await geminiService.extractInvoiceData(
        pdfText: extractedText,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Check if meaningful data was extracted
        final products = invoiceData['products'] as List<dynamic>? ?? [];
        if (products.isEmpty && extractedText.length < 500) {
          _showLimitedDataDialog(extractedText.length, invoiceData);
        } else {
          // Navigate to purchase entry form
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

        String errorMessage =
            '${loc?.errorProcessingPDF ?? 'Error processing PDF'}: $e';
        if (e.toString().contains('Too many requests')) {
          errorMessage =
              loc?.tooManyRequests ??
              'Too many requests. Please wait a moment and try again.';
        } else if (e.toString().contains('quota')) {
          errorMessage =
              loc?.quotaExceeded ??
              'Daily quota exceeded. Please try again tomorrow.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _processImage(String imagePath) async {
    final loc = AppLocalizations.of(context);

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
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
                      loc?.scanningInvoice ?? 'Scanning Invoice',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Powered by Gemini AI',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
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
      // Use Gemini to extract invoice data directly from image
      final geminiService = GeminiService();
      final invoiceData = await geminiService.extractInvoiceData(
        imagePath: imagePath,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Check if meaningful data was extracted
        final products = invoiceData['products'] as List<dynamic>? ?? [];
        if (products.isEmpty) {
          _showLimitedDataDialog(0, invoiceData);
        } else {
          // Navigate to purchase entry form
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

        String errorMessage =
            '${loc?.errorProcessingInvoice ?? 'Error processing invoice'}: $e';
        if (e.toString().contains('Too many requests')) {
          errorMessage =
              loc?.tooManyRequests ??
              'Too many requests. Please wait a moment and try again.';
        } else if (e.toString().contains('quota')) {
          errorMessage =
              loc?.quotaExceeded ??
              'Daily quota exceeded. Please try again tomorrow.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
