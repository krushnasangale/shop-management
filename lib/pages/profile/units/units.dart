import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/services.dart';

// --- Data Model ---
class UnitOfMeasure {
  final String id;
  final String name;

  UnitOfMeasure({required this.id, required this.name});

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {'name': name};
  }

  // Create from Map
  factory UnitOfMeasure.fromMap(String id, Map<dynamic, dynamic> data) {
    return UnitOfMeasure(id: id, name: data['name'] ?? '');
  }
}

class MeasurementUnitsScreen extends StatefulWidget {
  const MeasurementUnitsScreen({super.key});

  @override
  State<MeasurementUnitsScreen> createState() => _MeasurementUnitsScreenState();
}

class _MeasurementUnitsScreenState extends State<MeasurementUnitsScreen> {
  late String _userId;
  late List<UnitOfMeasure> _units;
  late List<UnitOfMeasure> _filteredUnits;
  bool _isLoading = true;
  String _searchQuery = '';
  late TextEditingController _searchController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _unitsSubscription;
  bool _showSearchBar = false;
  final TextEditingController _unitNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterUnits);
    _getUserAndLoadUnits();
  }

  @override
  void dispose() {
    _unitNameController.dispose();
    _searchController.dispose();
    _unitsSubscription?.cancel();
    super.dispose();
  }

  void _getUserAndLoadUnits() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      _loadUnitsFromDatabase();
    } else {
      setState(() {
        _isLoading = false;
        _units = [];
        _filteredUnits = [];
      });
    }
  }

  void _loadUnitsFromDatabase() {
    _unitsSubscription = FirebaseFirestore.instance
        .collection('units')
        .doc(_userId)
        .collection('items')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
          // Early return if widget is disposed
          if (!mounted) return;

          final loadedUnits = snapshot.docs
              .map((doc) => UnitOfMeasure.fromMap(doc.id, doc.data()))
              .toList();

          // Single setState call with all updates
          if (mounted) {
            setState(() {
              _units = loadedUnits;
              _isLoading = false;
            });
            _filterUnits();
          }
        });
  }

  void _filterUnits() {
    _searchQuery = _searchController.text.toLowerCase();
    if (!mounted) return;
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredUnits = _units;
      } else {
        _filteredUnits = _units
            .where((unit) => unit.name.toLowerCase().contains(_searchQuery))
            .toList();
      }
    });
  }

  // --- POPUP FUNCTION: Add New Unit ---
  void _showAddUnitPopup() {
    // Clear controllers before showing
    _unitNameController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Theme colors for the dialog
        final cardColor = context.cardColor;

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text('Add New Unit', style: context.bodyLargeText),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _unitNameController,
                  style: context.bodyLargeText,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    if (value != value.toUpperCase()) {
                      _unitNameController.text = value.toUpperCase();
                      _unitNameController.selection =
                          TextSelection.fromPosition(
                            TextPosition(offset: value.toUpperCase().length),
                          );
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Unit Name (e.g., METER, PIECE)',
                    labelStyle: TextStyle(
                      color: context.primaryTextColor!.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                if (_unitNameController.text.isNotEmpty) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('units')
                        .doc(_userId)
                        .collection('items')
                        .add({'name': _unitNameController.text.trim()});
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding unit: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- Helper Widget for the Unit List Item (Card) ---
  Widget _buildUnitCard(BuildContext context, UnitOfMeasure unit, int index) {
    final cardColor = context.cardColor;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(
          color: context.secondaryTextColor!.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            Row(
              children: [
                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.name,
                        style: context.titleLarge?.copyWith(fontSize: 18),
                      ),
                      const SizedBox(
                        height: 4,
                      ), // Added small space for separation
                    ],
                  ),
                ),

                // Action Buttons
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditUnitPopup(unit),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(unit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Measurement Units'),
        centerTitle: false,
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
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- Search Bar ---
                if (_showSearchBar)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Card(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search units...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: false,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                    ),
                  ),
                // --- Units List ---
                Expanded(
                  child: _filteredUnits.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No units yet. Add one to get started!'
                                : 'No units found for "$_searchQuery"',
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: !_showSearchBar ? 8.0 : 0.0,
                          ),
                          itemCount: _filteredUnits.length,
                          itemBuilder: (context, index) {
                            final unit = _filteredUnits[index];
                            return _buildUnitCard(context, unit, index);
                          },
                        ),
                ),
              ],
            ),
      // --- Floating Action Button with Popup ---
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_unit_fab',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF2196F3),
        onPressed: _showAddUnitPopup,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showEditUnitPopup(UnitOfMeasure unit) {
    // Controllers for editing
    final nameController = TextEditingController(text: unit.name);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Edit Unit',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildFormField('Unit Name', 'Enter unit name', nameController),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('units')
                      .doc(_userId)
                      .collection('items')
                      .doc(unit.id)
                      .update({'name': nameController.text});
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating unit: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
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
            child: TextFormField(
              onTap: onTap,
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                if (value != value.toUpperCase()) {
                  controller.text = value.toUpperCase();
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: value.toUpperCase().length),
                  );
                }
              },
              decoration: InputDecoration(
                fillColor: Colors.white,
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[700]!),
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
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(UnitOfMeasure unit) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Unit',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to remove ${unit.name}?',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('units')
                      .doc(_userId)
                      .collection('items')
                      .doc(unit.id)
                      .delete();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting unit: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
