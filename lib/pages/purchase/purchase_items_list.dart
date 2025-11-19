import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:nkt/pages/purchase/purchase_entry_details.dart';

class PurchaseItemsList extends StatefulWidget {
  const PurchaseItemsList({super.key});

  @override
  State<PurchaseItemsList> createState() => _PurchaseItemsListState();
}

class _PurchaseItemsListState extends State<PurchaseItemsList> {
  late DatabaseReference _boughtRef;
  List<Map<String, dynamic>> _boughtEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  bool _isLoading = true;
  StreamSubscription<DatabaseEvent>? _streamSubscription;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterEntries);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _boughtRef = FirebaseDatabase.instance.ref('purchases/${user.uid}');
      _loadBoughtEntriesRealtime();
    }
  }

  void _loadBoughtEntriesRealtime() {
    _streamSubscription = _boughtRef.onValue.listen(
      (event) {
        if (mounted) {
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            final entries = data.entries.map((e) {
              final entryData = Map<String, dynamic>.from(e.value as Map);
              entryData['id'] = e.key;
              return entryData;
            }).toList();

            // Sort by date (newest first)
            entries.sort((a, b) {
              final dateA =
                  DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
              final dateB =
                  DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
              return dateB.compareTo(dateA);
            });

            setState(() {
              _boughtEntries = entries;
              _filteredEntries = entries;
              _isLoading = false;
            });
          } else {
            setState(() {
              _boughtEntries = [];
              _filteredEntries = [];
              _isLoading = false;
            });
          }
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
      });
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildTotalQuantityBadge(Map<String, dynamic> entry) {
    // Get total quantity from entry
    final totalQuantity = entry['totalUnits'] as int? ?? 0;

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

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Scaffold(
      appBar: AppBar(title: const Text('Purchased Entries'), centerTitle: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _boughtEntries.isEmpty
          ? const Center(child: Text('No purchased entries yet'))
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12.0,
                    right: 12.0,
                    top: 0,
                    bottom: 0,
                  ),
                  child: Card(
                    elevation: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by supplier or amount',
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
                // List
                Expanded(
                  child: _filteredEntries.isEmpty
                      ? const Center(child: Text('No matching entries found'))
                      : ListView.builder(
                          itemCount: _filteredEntries.length,
                          padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                          itemBuilder: (context, index) {
                            final entry = _filteredEntries[index];
                            final date = entry['date'] ?? 'N/A';
                            final supplierName =
                                entry['supplierName'] ?? 'Unknown';
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
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: primaryTextColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.calendar_today,
                                                          size: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          date,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
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
                                                    '$totalProducts Products',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Purchased',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.blue[400],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // display total quantity bought
                                              _buildTotalQuantityBadge(entry),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.check_circle,
                                                      size: 14,
                                                      color: Colors.green,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Text(
                                                      'Received',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
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
            ),
    );
  }
}
