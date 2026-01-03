import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:signature/signature.dart';
import 'package:flutter/services.dart';

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
  late TextEditingController _ownerSignatureController;

  String? _ownerSignatureBase64;
  bool _hasSignature = false;

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _shopAddressController = TextEditingController();
    _shopPhoneController = TextEditingController();
    _shopEmailController = TextEditingController();
    _licenseNumberController = TextEditingController();
    _ownerSignatureController = TextEditingController();
    _loadShopDetails();
  }

  Future<void> _loadShopDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('shop-profile')
          .doc(user.uid)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};
        setState(() {
          _shopNameController.text = data['shopName'] ?? '';
          _ownerNameController.text = data['ownerName'] ?? '';
          _shopAddressController.text = data['shopAddress'] ?? '';
          _shopPhoneController.text = data['shopPhone'] ?? '';
          _shopEmailController.text = data['shopEmail'] ?? '';
          _licenseNumberController.text = data['licenseNumber'] ?? '';
          _ownerSignatureBase64 = data['ownerSignature'];
          _hasSignature =
              _ownerSignatureBase64 != null &&
              _ownerSignatureBase64!.isNotEmpty;
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

      final shopData = {
        'shopName': _shopNameController.text,
        'ownerName': _ownerNameController.text,
        'shopAddress': _shopAddressController.text,
        'shopPhone': _shopPhoneController.text,
        'shopEmail': _shopEmailController.text,
        'licenseNumber': _licenseNumberController.text,
        'ownerSignature': _ownerSignatureBase64 ?? '',
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('shop-profile')
          .doc(user.uid)
          .set(shopData);

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
    _ownerSignatureController.dispose();
    super.dispose();
  }

  void _showSignatureDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add/Update Signature', style: context.titleLarge),
          content: const Text(
            'Choose how to add your signature:',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showSignaturePad(context);
              },
              icon: const Icon(Icons.draw),
              label: const Text('Draw Signature'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _pickSignatureFromGallery();
              },
              icon: const Icon(Icons.image),
              label: const Text('Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _captureSignatureWithCamera();
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSignaturePad(BuildContext context) {
    final SignatureController controller = SignatureController(
      penStrokeWidth: 5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder:
          (
            BuildContext buildContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return WillPopScope(
              onWillPop: () async {
                // Reset to portrait when closing
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
                return true;
              },
              child: SafeArea(
                child: Scaffold(
                  backgroundColor: Colors.white,
                  appBar: AppBar(
                    title: const Text('Draw Your Signature'),
                    elevation: 0,
                    actions: [
                      TextButton(
                        onPressed: () {
                          controller.clear();
                          if (buildContext.mounted) {
                            ScaffoldMessenger.of(buildContext).showSnackBar(
                              const SnackBar(
                                content: Text('Signature cleared'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      Expanded(
                        child: Container(
                          color: Colors.grey[100],
                          child: Signature(
                            controller: controller,
                            backgroundColor: Colors.grey[100]!,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey[300]!, width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Reset to portrait when closing
                                  SystemChrome.setPreferredOrientations([
                                    DeviceOrientation.portraitUp,
                                    DeviceOrientation.portraitDown,
                                  ]);
                                  Navigator.pop(buildContext);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[400],
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (controller.isNotEmpty) {
                                    final signature = await controller
                                        .toImage();
                                    if (signature != null) {
                                      final bytes = await signature.toByteData(
                                        format: ui.ImageByteFormat.png,
                                      );
                                      if (bytes != null && mounted) {
                                        setState(() {
                                          _ownerSignatureBase64 = base64Encode(
                                            bytes.buffer.asUint8List(),
                                          );
                                          _hasSignature = true;
                                        });
                                        if (buildContext.mounted) {
                                          // Reset to portrait when closing
                                          SystemChrome.setPreferredOrientations(
                                            [
                                              DeviceOrientation.portraitUp,
                                              DeviceOrientation.portraitDown,
                                            ],
                                          );
                                          // Use rootNavigator to pop the dialog
                                          Navigator.of(
                                            buildContext,
                                            rootNavigator: true,
                                          ).pop();
                                          ScaffoldMessenger.of(
                                            buildContext,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Signature saved successfully',
                                              ),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  } else {
                                    if (buildContext.mounted) {
                                      ScaffoldMessenger.of(
                                        buildContext,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please draw your signature',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                child: const Text(
                                  'Save Signature',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
    );
  }

  Future<void> _pickSignatureFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _ownerSignatureBase64 = base64Encode(bytes);
          _hasSignature = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signature uploaded successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _captureSignatureWithCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _ownerSignatureBase64 = base64Encode(bytes);
          _hasSignature = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signature captured successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      backgroundColor: const Color(0xFF2196F3).withOpacity(0.2),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

              // Owner Signature Field
              const Text(
                'Owner Signature',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (_hasSignature && _ownerSignatureBase64 != null)
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.memory(
                            base64Decode(_ownerSignatureBase64!),
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.draw,
                                size: 32,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No signature added',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_isEditMode)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showSignatureDialog(context),
                            icon: const Icon(Icons.edit),
                            label: Text(
                              _hasSignature
                                  ? 'Update Signature'
                                  : 'Add Signature',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // License/Registration Number Field
              const Text(
                'License/Registration Number',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
    );
  }
}
