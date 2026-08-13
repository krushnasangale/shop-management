import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:signature/signature.dart';
import 'package:flutter/services.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/services/profile_service.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEditMode = false;

  late final ProfileService _profileService;

  // Text controllers
  late TextEditingController _shopNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _ownerPhoneController;
  late TextEditingController _shopAddressController;
  late TextEditingController _shopPhoneController;
  late TextEditingController _shopEmailController;
  late TextEditingController _licenseNumberController;
  late TextEditingController _ownerSignatureController;
  late TextEditingController _subscriptionExpiryController;

  String? _ownerSignatureBase64;
  bool _hasSignature = false;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
    _shopNameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _ownerPhoneController = TextEditingController();
    _shopAddressController = TextEditingController();
    _shopPhoneController = TextEditingController();
    _shopEmailController = TextEditingController();
    _licenseNumberController = TextEditingController();
    _ownerSignatureController = TextEditingController();
    _subscriptionExpiryController = TextEditingController();

    // Initialize the profile service
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _profileService.initialize(user.uid);
    }
  }

  void _populateFormFields(Map<String, dynamic> profileData) {
    // Only populate if controllers are not already populated (to avoid overwriting user edits)
    if (_shopNameController.text.isEmpty) {
      _shopNameController.text = profileData['shopName'] ?? '';
      _ownerNameController.text = profileData['ownerName'] ?? '';
      _ownerPhoneController.text = profileData['ownerPhone'] ?? '';
      _shopAddressController.text = profileData['shopAddress'] ?? '';
      _shopPhoneController.text = profileData['shopPhone'] ?? '';
      _shopEmailController.text = profileData['shopEmail'] ?? '';
      _licenseNumberController.text = profileData['licenseNumber'] ?? '';
      _ownerSignatureBase64 = profileData['ownerSignature'];
      _hasSignature =
          _ownerSignatureBase64 != null && _ownerSignatureBase64!.isNotEmpty;

      // Load subscription expiry date
      if (profileData['subscriptionExpiry'] != null) {
        try {
          DateTime expiryDate;
          if (profileData['subscriptionExpiry'] is Timestamp) {
            expiryDate = (profileData['subscriptionExpiry'] as Timestamp)
                .toDate();
          } else if (profileData['subscriptionExpiry'] is String) {
            expiryDate = DateTime.parse(profileData['subscriptionExpiry']);
          } else {
            throw Exception('Invalid subscription expiry format');
          }

          _subscriptionExpiryController.text =
              '${expiryDate.day.toString().padLeft(2, '0')}/${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.year}';
        } catch (e) {
          _subscriptionExpiryController.text = 'Not set';
        }
      } else {
        _subscriptionExpiryController.text = 'Not set';
      }
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
        'ownerPhone': _ownerPhoneController.text,
        'shopAddress': _shopAddressController.text,
        'shopPhone': _shopPhoneController.text,
        'shopEmail': _shopEmailController.text,
        'licenseNumber': _licenseNumberController.text,
        'ownerSignature': _ownerSignatureBase64 ?? '',
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await _profileService.updateProfileData(shopData);

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.profileSavedSuccessfully ??
                  'Profile saved successfully',
            ),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations?.errorSavingProfile ?? 'Error saving profile'}: $e',
            ),
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
    _profileService.dispose();
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _shopEmailController.dispose();
    _licenseNumberController.dispose();
    _ownerSignatureController.dispose();
    _subscriptionExpiryController.dispose();
    super.dispose();
  }

  void _showSignatureDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(
            localizations?.addUpdateSignature ?? 'Add/Update Signature',
            style: context.titleLarge,
          ),
          content: Text(
            localizations?.chooseSignatureMethod ??
                'Choose how to add your signature:',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations?.cancel ?? 'Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showSignaturePad(context);
              },
              icon: const Icon(Icons.draw),
              label: Text(localizations?.drawSignature ?? 'Draw Signature'),
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
              label: Text(localizations?.upload ?? 'Upload'),
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
              label: Text(localizations?.camera ?? 'Camera'),
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
    final localizations = AppLocalizations.of(context);
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
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder:
          (
            BuildContext buildContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return PopScope(
              onPopInvokedWithResult: (didPop, result) {
                // Reset to portrait when closing
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
              },
              child: SafeArea(
                child: Scaffold(
                  backgroundColor: Colors.white,
                  appBar: AppBar(
                    title: Text(
                      localizations?.drawYourSignature ?? 'Draw Your Signature',
                    ),
                    elevation: 0,
                    actions: [
                      TextButton(
                        onPressed: () {
                          controller.clear();
                          if (buildContext.mounted) {
                            ScaffoldMessenger.of(buildContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  localizations?.signatureCleared ??
                                      'Signature cleared',
                                ),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        child: Text(
                          localizations?.clear ?? 'Clear',
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
                                child: Text(
                                  AppLocalizations.of(buildContext)?.cancel ??
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
                                            SnackBar(
                                              content: Text(
                                                localizations?.signatureSaved ??
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
                                        SnackBar(
                                          content: Text(
                                            localizations
                                                    ?.pleaseDrawSignature ??
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
                                child: Text(
                                  localizations?.saveSignature ??
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
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.signatureUploadedSuccessfully ??
                    'Signature uploaded successfully',
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.error ?? 'Error'}: $e'),
            backgroundColor: Colors.red,
          ),
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
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.signatureCapturedSuccessfully ??
                    'Signature captured successfully',
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations?.error ?? 'Error'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.editProfile ?? 'Profile'),
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
                child: Text(localizations?.cancel ?? 'Cancel'),
              ),
            ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _profileService.profileStream,
        builder: (context, snapshot) {
          // Populate form fields when data is available
          if (snapshot.hasData && snapshot.data != null) {
            final profileData = snapshot.data!;
            _populateFormFields(profileData);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture Section
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(
                                    0xFF2196F3,
                                  ).withValues(alpha: 0.1),
                                  const Color(
                                    0xFF2196F3,
                                  ).withValues(alpha: 0.3),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.transparent,
                              child: const Icon(
                                Icons.person,
                                size: 50,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {},
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Basic Information Section
                  Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic Information',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2196F3),
                                ),
                          ),
                          const SizedBox(height: 12),

                          // Shop Name Field
                          Text(
                            localizations?.shopName ?? 'Shop Name',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _shopNameController,
                            enabled: _isEditMode,
                            decoration: InputDecoration(
                              hintText:
                                  localizations?.enterShopName ??
                                  'Enter your shop name',
                              prefixIcon: const Icon(
                                Icons.store,
                                color: Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: _isEditMode
                                  ? Colors.grey[50]
                                  : Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 1,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (_isEditMode &&
                                  (value == null || value.isEmpty)) {
                                return localizations?.pleaseEnterShopName ??
                                    'Please enter shop name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Owner Name Field
                          Text(
                            localizations?.ownerName ?? 'Owner Name',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _ownerNameController,
                            enabled: _isEditMode,
                            decoration: InputDecoration(
                              hintText:
                                  localizations?.enterOwnerName ??
                                  'Enter owner name',
                              prefixIcon: const Icon(
                                Icons.person,
                                color: Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: _isEditMode
                                  ? Colors.grey[50]
                                  : Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 1,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (_isEditMode &&
                                  (value == null || value.isEmpty)) {
                                return localizations?.pleaseEnterOwnerName ??
                                    'Please enter owner name';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Contact Information Section
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Information',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2196F3),
                                ),
                          ),
                          const SizedBox(height: 12),

                          // Shop Address Field
                          Text(
                            localizations?.shopAddress ?? 'Shop Address',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _shopAddressController,
                            enabled: _isEditMode,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  localizations?.enterCompleteShopAddress ??
                                  'Enter complete shop address',
                              prefixIcon: const Icon(
                                Icons.location_on,
                                color: Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: _isEditMode
                                  ? Colors.grey[50]
                                  : Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 1,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (_isEditMode &&
                                  (value == null || value.isEmpty)) {
                                return localizations?.pleaseEnterShopAddress ??
                                    'Please enter shop address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Mobile Number Field (Required)
                          Text(
                            'Mobile Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _shopPhoneController,
                            enabled: _isEditMode,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'Enter mobile number',
                              prefixIcon: const Icon(
                                Icons.phone,
                                color: Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: _isEditMode
                                  ? Colors.grey[50]
                                  : Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 1,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (_isEditMode) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter mobile number';
                                }
                                if (value.length < 10) {
                                  return 'Please enter valid mobile number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Optional Mobile Number Field
                          Text(
                            'Optional Mobile Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _ownerPhoneController,
                            enabled: _isEditMode,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'Enter mobile number (optional)',
                              prefixIcon: const Icon(
                                Icons.phone,
                                color: Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: _isEditMode
                                  ? Colors.grey[50]
                                  : Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 1,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (_isEditMode &&
                                  value != null &&
                                  value.isNotEmpty) {
                                if (value.length < 10) {
                                  return 'Please enter valid mobile number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Shop Email Field
                          Text(
                            localizations?.shopEmail ?? 'Shop Email',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _shopEmailController,
                            enabled: _isEditMode,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText:
                                  localizations?.enterEmailAddress ??
                                  'Enter email address',
                              prefixIcon: const Icon(
                                Icons.email,
                                color: Color(0xFF2196F3),
                              ),
                              filled: true,
                              fillColor: _isEditMode
                                  ? Colors.grey[50]
                                  : Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2196F3),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 1,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (_isEditMode &&
                                  value != null &&
                                  value.isNotEmpty) {
                                if (!RegExp(
                                  r'^[^@]+@[^@]+\.[^@]+',
                                ).hasMatch(value)) {
                                  return localizations?.pleaseEnterValidEmail ??
                                      'Please enter valid email';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Additional Information Section
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Additional Information',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2196F3),
                                ),
                          ),
                          const SizedBox(height: 12),

                          // Owner Signature Field
                          Text(
                            localizations?.ownerSignature ?? 'Owner Signature',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            child: Column(
                              children: [
                                if (_hasSignature &&
                                    _ownerSignatureBase64 != null)
                                  Container(
                                    height: 120,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
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
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.draw,
                                            size: 32,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            localizations?.noSignatureAdded ??
                                                'No signature added',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
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
                                        onPressed: () =>
                                            _showSignatureDialog(context),
                                        icon: const Icon(Icons.edit),
                                        label: Text(
                                          _hasSignature
                                              ? (localizations
                                                        ?.updateSignature ??
                                                    'Update Signature')
                                              : (localizations?.addSignature ??
                                                    'Add Signature'),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF2196F3,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Subscription Expiry Date Field (Non-editable)
                          Text(
                            localizations?.subscriptionExpiry ??
                                'Subscription Expiry',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _subscriptionExpiryController,
                            enabled: false,
                            decoration: InputDecoration(
                              hintText: localizations?.notSet ?? 'Not set',
                              prefixIcon: const Icon(
                                Icons.calendar_today,
                                color: Colors.grey,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                            : Text(
                                localizations?.saveChanges ?? 'Save Changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
