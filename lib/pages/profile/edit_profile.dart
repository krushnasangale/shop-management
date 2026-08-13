import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signature/signature.dart';

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

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _profileService.initialize(user.uid);
    }
  }

  void _populateFormFields(Map<String, dynamic> profileData) {
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
            duration: const Duration(seconds: 2),
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
            backgroundColor: Theme.of(context).colorScheme.error,
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

  Future<void> _showSignaturePicker() async {
    final loc = AppLocalizations.of(context);
    final options = [
      _SignatureOptionData(
        icon: Adaptive.isCupertino
            ? CupertinoIcons.pencil_outline
            : Icons.draw_outlined,
        title: loc?.drawSignature ?? 'Draw Signature',
        subtitle: 'Sign with your finger or stylus',
        onSelect: _showSignaturePad,
      ),
      _SignatureOptionData(
        icon: Adaptive.isCupertino
            ? CupertinoIcons.photo
            : Icons.image_outlined,
        title: loc?.upload ?? 'Upload',
        subtitle: 'Choose an image from your gallery',
        onSelect: _pickSignatureFromGallery,
      ),
      _SignatureOptionData(
        icon: Adaptive.isCupertino
            ? CupertinoIcons.camera
            : Icons.camera_alt_outlined,
        title: loc?.camera ?? 'Camera',
        subtitle: 'Take a photo of your signature',
        onSelect: _captureSignatureWithCamera,
      ),
    ];

    await Adaptive.showSheet<void>(
      context: context,
      builder: (sheetContext) {
        return _SignaturePickerSheet(
          title: loc?.addUpdateSignature ?? 'Update Signature',
          subtitle:
              loc?.chooseSignatureMethod ?? 'Choose how to add your signature',
          cancelLabel: loc?.cancel ?? 'Cancel',
          options: options,
        );
      },
    );
  }

  void _showSignaturePad() {
    final localizations = AppLocalizations.of(context);
    final controller = SignatureController(
      penStrokeWidth: 5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

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
            final scheme = Theme.of(buildContext).colorScheme;
            return PopScope(
              onPopInvokedWithResult: (didPop, result) {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
              },
              child: SafeArea(
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(
                      localizations?.drawYourSignature ?? 'Draw Your Signature',
                    ),
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
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        child: Text(localizations?.clear ?? 'Clear'),
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      Expanded(
                        child: ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Signature(
                            controller: controller,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  SystemChrome.setPreferredOrientations([
                                    DeviceOrientation.portraitUp,
                                    DeviceOrientation.portraitDown,
                                  ]);
                                  Navigator.pop(buildContext);
                                },
                                style: Adaptive.compactOutlined,
                                child: Text(
                                  AppLocalizations.of(buildContext)?.cancel ??
                                      'Cancel',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
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
                                          SystemChrome.setPreferredOrientations(
                                            [
                                              DeviceOrientation.portraitUp,
                                              DeviceOrientation.portraitDown,
                                            ],
                                          );
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
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  } else if (buildContext.mounted) {
                                    ScaffoldMessenger.of(
                                      buildContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          localizations?.pleaseDrawSignature ??
                                              'Please draw your signature',
                                        ),
                                        backgroundColor: scheme.error,
                                      ),
                                    );
                                  }
                                },
                                style: Adaptive.compactFilled,
                                child: Text(
                                  localizations?.saveSignature ??
                                      'Save Signature',
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
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);

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
              duration: const Duration(seconds: 2),
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _captureSignatureWithCamera() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);

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
              duration: const Duration(seconds: 2),
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc?.editProfile ?? 'Profile';

    if (Adaptive.isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(title),
          trailing: _appBarAction(loc),
        ),
        child: SafeArea(child: _buildBody(loc)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [_appBarAction(loc)]),
      body: _buildBody(loc),
    );
  }

  Widget _appBarAction(AppLocalizations? loc) {
    if (!_isEditMode) {
      if (Adaptive.isCupertino) {
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _isEditMode = true),
          child: const Icon(CupertinoIcons.pencil),
        );
      }
      return IconButton(
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => setState(() => _isEditMode = true),
      );
    }

    if (Adaptive.isCupertino) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => setState(() => _isEditMode = false),
        child: Text(loc?.cancel ?? 'Cancel'),
      );
    }

    return TextButton(
      onPressed: () => setState(() => _isEditMode = false),
      child: Text(loc?.cancel ?? 'Cancel'),
    );
  }

  Widget _buildBody(AppLocalizations? loc) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _profileService.profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _populateFormFields(snapshot.data!);
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(child: Adaptive.progress());
        }

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _sectionLabel('Basic Information'),
              _InfoGroup(
                editing: _isEditMode,
                children: [
                  _InfoRow(
                    controller: _shopNameController,
                    label: loc?.shopName ?? 'Shop Name',
                    hint: loc?.enterShopName ?? 'Enter your shop name',
                    icon: Icons.storefront_outlined,
                    editable: _isEditMode,
                    validator: (value) {
                      if (_isEditMode && (value == null || value.isEmpty)) {
                        return loc?.pleaseEnterShopName ??
                            'Please enter shop name';
                      }
                      return null;
                    },
                  ),
                  _InfoRow(
                    controller: _ownerNameController,
                    label: loc?.ownerName ?? 'Owner Name',
                    hint: loc?.enterOwnerName ?? 'Enter owner name',
                    icon: Icons.person_outline,
                    editable: _isEditMode,
                    validator: (value) {
                      if (_isEditMode && (value == null || value.isEmpty)) {
                        return loc?.pleaseEnterOwnerName ??
                            'Please enter owner name';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionLabel('Contact Information'),
              _InfoGroup(
                editing: _isEditMode,
                children: [
                  _InfoRow(
                    controller: _shopAddressController,
                    label: loc?.shopAddress ?? 'Shop Address',
                    hint:
                        loc?.enterCompleteShopAddress ??
                        'Enter complete shop address',
                    icon: Icons.location_on_outlined,
                    editable: _isEditMode,
                    maxLines: 3,
                    validator: (value) {
                      if (_isEditMode && (value == null || value.isEmpty)) {
                        return loc?.pleaseEnterShopAddress ??
                            'Please enter shop address';
                      }
                      return null;
                    },
                  ),
                  _InfoRow(
                    controller: _shopPhoneController,
                    label: 'Mobile Number',
                    hint: 'Enter mobile number',
                    icon: Icons.phone_outlined,
                    editable: _isEditMode,
                    keyboardType: TextInputType.phone,
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
                  _InfoRow(
                    controller: _ownerPhoneController,
                    label: 'Optional Mobile Number',
                    hint: 'Enter mobile number (optional)',
                    icon: Icons.phone_outlined,
                    editable: _isEditMode,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (_isEditMode &&
                          value != null &&
                          value.isNotEmpty &&
                          value.length < 10) {
                        return 'Please enter valid mobile number';
                      }
                      return null;
                    },
                  ),
                  _InfoRow(
                    controller: _shopEmailController,
                    label: loc?.shopEmail ?? 'Shop Email',
                    hint: loc?.enterEmailAddress ?? 'Enter email address',
                    icon: Icons.email_outlined,
                    editable: _isEditMode,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (_isEditMode &&
                          value != null &&
                          value.isNotEmpty &&
                          !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return loc?.pleaseEnterValidEmail ??
                            'Please enter valid email';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionLabel('Additional Information'),
              _InfoGroup(
                editing: _isEditMode,
                children: [
                  _SignatureRow(
                    label: loc?.ownerSignature ?? 'Owner Signature',
                    hasSignature: _hasSignature,
                    signatureBase64: _ownerSignatureBase64,
                    isEditMode: _isEditMode,
                    emptyLabel: loc?.noSignatureAdded ?? 'No signature added',
                    actionLabel: _hasSignature
                        ? (loc?.updateSignature ?? 'Update Signature')
                        : (loc?.addSignature ?? 'Add Signature'),
                    onEdit: _showSignaturePicker,
                  ),
                  _InfoRow(
                    controller: _subscriptionExpiryController,
                    label: loc?.subscriptionExpiry ?? 'Subscription Expiry',
                    hint: loc?.notSet ?? 'Not set',
                    icon: Icons.calendar_today_outlined,
                    editable: false,
                  ),
                ],
              ),
              if (_isEditMode) ...[
                const SizedBox(height: 28),
                _SaveButton(
                  loading: _isSaving,
                  label: loc?.saveChanges ?? 'Save Changes',
                  onPressed: _isSaving ? null : _saveShopDetails,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SignatureOptionData {
  const _SignatureOptionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelect,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onSelect;
}

class _SignaturePickerSheet extends StatelessWidget {
  const _SignaturePickerSheet({
    required this.title,
    required this.subtitle,
    required this.cancelLabel,
    required this.options,
  });

  final String title;
  final String subtitle;
  final String cancelLabel;
  final List<_SignatureOptionData> options;

  void _select(BuildContext context, _SignatureOptionData option) {
    Navigator.pop(context);
    option.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    if (Adaptive.isCupertino) {
      return Container(
        height: 420,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: CupertinoPageScaffold(
          backgroundColor: Colors.transparent,
          navigationBar: CupertinoNavigationBar(
            automaticallyImplyLeading: false,
            middle: Text(title),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: Text(cancelLabel),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.only(top: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  children: [
                    for (final option in options)
                      CupertinoListTile(
                        leading: Icon(option.icon),
                        title: Text(option.title),
                        subtitle: Text(option.subtitle),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => _select(context, option),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < options.length; i++) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: Icon(options[i].icon, size: 22),
                      ),
                      title: Text(options[i].title),
                      subtitle: Text(options[i].subtitle),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: scheme.onSurfaceVariant,
                      ),
                      onTap: () => _select(context, options[i]),
                    ),
                    if (i != options.length - 1)
                      const Divider(height: 1, indent: 72),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(cancelLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.children, this.editing = false});

  final List<Widget> children;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    if (Adaptive.isCupertino) {
      if (editing) {
        return CupertinoFormSection.insetGrouped(
          margin: EdgeInsets.zero,
          children: children,
        );
      }
      return CupertinoListSection.insetGrouped(
        margin: EdgeInsets.zero,
        children: children,
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.editable,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool editable;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leading = Icon(icon, color: scheme.primary, size: 22);

    if (!editable) {
      if (Adaptive.isCupertino) {
        return CupertinoListTile(
          leading: leading,
          title: Text(label),
          additionalInfo: Text(
            controller.text.trim().isEmpty ? '—' : controller.text,
          ),
        );
      }

      return ListTile(
        leading: leading,
        title: Text(label),
        subtitle: maxLines > 1
            ? Text(
                controller.text.trim().isEmpty ? '—' : controller.text,
                maxLines: maxLines,
              )
            : null,
        trailing: maxLines > 1
            ? null
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  controller.text.trim().isEmpty ? '—' : controller.text,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
      );
    }

    if (Adaptive.isCupertino) {
      return CupertinoTextFormFieldRow(
        controller: controller,
        prefix: Text(label),
        placeholder: hint,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        padding: const EdgeInsets.symmetric(vertical: 12),
      );
    }

    return ListTile(
      leading: leading,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
      subtitle: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.only(top: 4, bottom: 6),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class _SignatureRow extends StatelessWidget {
  const _SignatureRow({
    required this.label,
    required this.hasSignature,
    required this.signatureBase64,
    required this.isEditMode,
    required this.emptyLabel,
    required this.actionLabel,
    required this.onEdit,
  });

  final String label;
  final bool hasSignature;
  final String? signatureBase64;
  final bool isEditMode;
  final String emptyLabel;
  final String actionLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leading = Icon(Icons.draw_outlined, color: scheme.primary, size: 22);
    final image = hasSignature && signatureBase64 != null
        ? SizedBox(
            height: 56,
            child: Image.memory(
              base64Decode(signatureBase64!),
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          )
        : null;

    if (Adaptive.isCupertino) {
      return CupertinoListTile(
        leading: leading,
        title: Text(label),
        subtitle: image ?? Text(emptyLabel),
        trailing: isEditMode ? const CupertinoListTileChevron() : null,
        onTap: isEditMode ? onEdit : null,
      );
    }

    return ListTile(
      leading: leading,
      title: Text(label),
      subtitle: image ?? (hasSignature ? null : Text(emptyLabel)),
      trailing: isEditMode
          ? TextButton(onPressed: onEdit, child: Text(actionLabel))
          : null,
      onTap: isEditMode ? onEdit : null,
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(width: 18, height: 18, child: Adaptive.progress())
        : Text(label);

    if (Adaptive.isCupertino) {
      return CupertinoButton.filled(onPressed: onPressed, child: child);
    }

    return FilledButton(
      onPressed: onPressed,
      style: Adaptive.compactFilled,
      child: child,
    );
  }
}
