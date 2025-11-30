import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flashbill/pages/profile/supplier/supplier_history.dart';

// --- Supplier Data Model ---
class Supplier {
  final String id;
  final String name;
  final String contact;
  final String location;

  Supplier({
    required this.id,
    required this.name,
    required this.contact,
    required this.location,
  });

  // Convert Supplier to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contact': contact,
      'location': location,
    };
  }

  // Create Supplier from Map
  factory Supplier.fromMap(String id, Map<dynamic, dynamic> data) {
    return Supplier(
      id: id,
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      location: data['location'] ?? '',
    );
  }
}

class Suppliers extends StatefulWidget {
  const Suppliers({super.key});

  @override
  State<Suppliers> createState() => _SuppliersState();
}

class _SuppliersState extends State<Suppliers> {
  late String _userId;
  late List<Supplier> _suppliers;
  late List<Supplier> _filteredSuppliers;
  bool _isLoading = true;
  String _searchQuery = '';
  late TextEditingController _searchController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _suppliersSubscription;

  // --- Random Color Generator for Avatar Initials ---
  final Random _random = Random();
  Color _generateRandomColor() {
    return Color.fromARGB(
      255,
      _random.nextInt(200) + 50, // Avoid very dark colors that hide text
      _random.nextInt(200) + 50,
      _random.nextInt(200) + 50,
    );
  }

  // --- Helper to get initials ---
  String _getInitials(String name) {
    List<String> parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterSuppliers);
    _getUserAndLoadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _suppliersSubscription?.cancel();
    super.dispose();
  }

  void _filterSuppliers() {
    _searchQuery = _searchController.text.toLowerCase();
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredSuppliers = _suppliers;
      } else {
        _filteredSuppliers = _suppliers
            .where((supplier) =>
                supplier.name.toLowerCase().contains(_searchQuery) ||
                supplier.contact.toLowerCase().contains(_searchQuery) ||
                supplier.location.toLowerCase().contains(_searchQuery))
            .toList();
      }
    });
  }

  void _getUserAndLoadSuppliers() {
    // Get current logged-in user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      _loadSuppliersFromDatabase();
    } else {
      setState(() {
        _isLoading = false;
        _suppliers = [];
      });
    }
  }

  void _loadSuppliersFromDatabase() {
    _suppliersSubscription = FirebaseFirestore.instance
        .collection('suppliers')
        .doc(_userId)
        .collection('items')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      if (!mounted) return;
      
      final loadedSuppliers = snapshot.docs
          .map((doc) => Supplier.fromMap(doc.id, doc.data()))
          .toList();
      if (mounted) {
        setState(() {
          _suppliers = loadedSuppliers;
          _filterSuppliers();
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Suppliers'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // --- Search Bar ---
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      bottom: 8.0,
                    ),
                    child: Card(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search Suppliers...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
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
                        ),
                      ),
                    ),
                  ),

                  // --- Suppliers List ---
                  Expanded(
                    child: _filteredSuppliers.isEmpty
                        ? Center(
                            child: Text(_searchQuery.isEmpty
                                ? 'No suppliers yet. Add one to get started!'
                                : 'No suppliers found for "$_searchQuery"'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            itemCount: _filteredSuppliers.length,
                            itemBuilder: (context, index) {
                              final supplier = _filteredSuppliers[index];
                              final initials = _getInitials(supplier.name);
                              final avatarColor = _generateRandomColor();

                              return _buildSupplierCard(
                                context,
                                supplier,
                                initials,
                                avatarColor,
                              );
                            },
                          ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onPressed: () => addNewSupplier(),
          backgroundColor: const Color(0xFF2196F3),
          tooltip: 'Add Supplier',
          child: const Icon(Icons.add, color: Colors.white, size: 45),
        ),
      ),
    );
  }

  // Helper Widget for a single Supplier Card
  Widget _buildSupplierCard(
    BuildContext context,
    Supplier supplier,
    String initials,
    Color avatarColor,
  ) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(
          color: secondaryTextColor!.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          top: 10.0,
          bottom: 0.0,
          left: 20.0,
          right: 20.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Initials Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarColor,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Supplier Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            supplier.contact,
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            supplier.location,
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _showSupplierHistory(supplier),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _editSupplier(supplier),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showDeleteConfirmation(supplier),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void addNewSupplier() {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final locationController = TextEditingController();
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Supplier', style: TextStyle(color: primaryTextColor),),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildFormField('Supplier Name', 'Enter supplier name', nameController),
              buildFormField('Supplier Contact', 'Enter contact number', contactController, keyboardType: TextInputType.phone),
              buildFormField('Supplier Location', 'Enter location', locationController),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    contactController.text.isNotEmpty &&
                    locationController.text.isNotEmpty) {
                  final newSupplier = {
                    'name': nameController.text.trim(),
                    'contact': contactController.text,
                    'location': locationController.text.trim(),
                  };
                  await FirebaseFirestore.instance
                      .collection('suppliers')
                      .doc(_userId)
                      .collection('items')
                      .add(newSupplier);
                  if (mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget buildFormField(
    String label,
    String hint,
    TextEditingController controller, {
    IconData? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Function()? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8.0),
          Container(
            height: 53,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Builder(
              builder: (context) {
                final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                return TextFormField(
                  onTap: onTap,
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  textCapitalization: keyboardType == TextInputType.phone ? TextCapitalization.none : TextCapitalization.characters,
                  onChanged: (value) {
                    // Only apply uppercase conversion for name and location (not phone)
                    if (keyboardType != TextInputType.phone) {
                      if (value != value.toUpperCase()) {
                        controller.text = value.toUpperCase();
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: value.toUpperCase().length),
                        );
                      }
                    }
                  },
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey[500]!),
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: maxLines > 1 ? 16.0 : 16.0,
                      horizontal: 16.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: suffixIcon != null
                        ? Icon(suffixIcon, color: Colors.grey[700]!)
                        : null,
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  void _editSupplier(Supplier supplier) {
    final nameController = TextEditingController(text: supplier.name);
    final contactController = TextEditingController(text: supplier.contact);
    final locationController = TextEditingController(text: supplier.location);
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Supplier', style: TextStyle(color: primaryTextColor),),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildFormField('Supplier Name', 'Enter supplier name', nameController),
              buildFormField('Supplier Contact', 'Enter contact number', contactController, keyboardType: TextInputType.phone),
              buildFormField('Supplier Location', 'Enter location', locationController),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    contactController.text.isNotEmpty &&
                    locationController.text.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('suppliers')
                      .doc(_userId)
                      .collection('items')
                      .doc(supplier.id)
                      .update({
                    'name': nameController.text,
                    'contact': contactController.text,
                    'location': locationController.text,
                  });
                  if (mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showSupplierHistory(Supplier supplier) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SupplierHistoryScreen(
          supplierId: supplier.id,
          supplierName: supplier.name,
          userId: _userId,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Supplier supplier) {
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Supplier', style: TextStyle(color: primaryTextColor),),
          content: Text('Are you sure you want to delete ${supplier.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('suppliers')
                    .doc(_userId)
                    .collection('items')
                    .doc(supplier.id)
                    .delete();
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

