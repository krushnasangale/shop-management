import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;

  // Text controllers
  late TextEditingController _shopNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _shopAddressController;
  late TextEditingController _shopPhoneController;
  late TextEditingController _shopEmailController;
  late TextEditingController _licenseNumberController;

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _shopAddressController = TextEditingController();
    _shopPhoneController = TextEditingController();
    _shopEmailController = TextEditingController();
    _licenseNumberController = TextEditingController();
    _loadShopDetails();
  }

  Future<void> _loadShopDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('shop-profile/${user.uid}').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _shopNameController.text = data['shopName'] ?? '';
          _ownerNameController.text = data['ownerName'] ?? '';
          _shopAddressController.text = data['shopAddress'] ?? '';
          _shopPhoneController.text = data['shopPhone'] ?? '';
          _shopEmailController.text = data['shopEmail'] ?? '';
          _licenseNumberController.text = data['licenseNumber'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading shop details: $e');
    }
  }

  Future<void> _saveShopDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final database = FirebaseDatabase.instance;
      final shopData = {
        'shopName': _shopNameController.text,
        'ownerName': _ownerNameController.text,
        'shopAddress': _shopAddressController.text,
        'shopPhone': _shopPhoneController.text,
        'shopEmail': _shopEmailController.text,
        'licenseNumber': _licenseNumberController.text,
        'lastUpdated': DateTime.now().toString(),
      };

      await database.ref('shop-profile/${user.uid}').set(shopData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _shopEmailController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            if (!_isEditMode)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  setState(() => _isEditMode = true);
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextButton(
                  onPressed: () {
                    setState(() => _isEditMode = false);
                  },
                  child: const Text('Cancel'),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture Section
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(
                          0xFF2196F3,
                        ).withOpacity(0.2),
                        child: const Icon(
                          Icons.person,
                          size: 60,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Add image picker functionality
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Shop Name Field
                const Text(
                  'Shop Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Card(
                  child: TextFormField(
                    controller: _shopNameController,
                    enabled: _isEditMode,
                    decoration: InputDecoration(
                      hintText: 'Enter your shop name',
                      prefixIcon: const Icon(Icons.store),
                      filled: false,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (_isEditMode && (value == null || value.isEmpty)) {
                        return 'Please enter shop name';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 6),

                // Owner Name Field
                const Text(
                  'Owner Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Card(
                  child: TextFormField(
                    controller: _ownerNameController,
                    enabled: _isEditMode,
                    decoration: InputDecoration(
                      hintText: 'Enter owner name',
                      prefixIcon: const Icon(Icons.person),
                      filled: false,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (_isEditMode && (value == null || value.isEmpty)) {
                        return 'Please enter owner name';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 6),

                // Shop Address Field
                const Text(
                  'Shop Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Card(
                  child: TextFormField(
                    controller: _shopAddressController,
                    enabled: _isEditMode,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter complete shop address',
                      prefixIcon: const Icon(Icons.location_on),
                      filled: false,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (_isEditMode && (value == null || value.isEmpty)) {
                        return 'Please enter shop address';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 6),

                // Shop Phone Field
                const Text(
                  'Shop Phone Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Card(
                  child: TextFormField(
                    controller: _shopPhoneController,
                    enabled: _isEditMode,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Enter phone number',
                      prefixIcon: const Icon(Icons.phone),
                      filled: false,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (_isEditMode) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (value.length < 10) {
                          return 'Please enter valid phone number';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 6),

                // Shop Email Field
                const Text(
                  'Shop Email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Card(
                  child: TextFormField(
                    controller: _shopEmailController,
                    enabled: _isEditMode,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter email address',
                      prefixIcon: const Icon(Icons.email),
                      filled: false,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (_isEditMode && value != null && value.isNotEmpty) {
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter valid email';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 6),

                // License/Registration Number Field
                const Text(
                  'License/Registration Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Card(
                  child: TextFormField(
                    controller: _licenseNumberController,
                    enabled: _isEditMode,
                    decoration: InputDecoration(
                      hintText: 'GST Number or License ID',
                      prefixIcon: const Icon(Icons.assignment),
                      filled: false,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (_isEditMode && (value == null || value.isEmpty)) {
                        return 'Please enter license/registration number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Save Button - Only show in edit mode
                if (_isEditMode)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveShopDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
