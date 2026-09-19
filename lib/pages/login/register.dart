import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/main.dart';
import 'package:flashbill/providers/language_provider.dart';
import 'package:flashbill/services/notification_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/device_utils.dart';
import 'package:flashbill/widgets/app_loader.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _shopEmailController = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _submitted = false;
  String? _ownerSignatureBase64;

  bool get _hasSignature =>
      _ownerSignatureBase64 != null && _ownerSignatureBase64!.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _shopEmailController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _phone(String? value, String requiredMessage, String invalidMessage) {
    final requiredError = _required(value, requiredMessage);
    if (requiredError != null) return requiredError;
    final digits = value!.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return invalidMessage;
    return null;
  }

  String? _email(String? value, String requiredMessage, String invalidMessage) {
    final requiredError = _required(value, requiredMessage);
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!.trim())) {
      return invalidMessage;
    }
    return null;
  }

  Future<void> _register() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    if (!_hasSignature) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc?.pleaseAddSignature ?? 'Please add owner signature'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    AppLoader.show(
      message: AppLocalizations.of(context)?.createAccount ?? 'Create Account',
    );

    User? createdUser;
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      createdUser = credential.user;
      if (createdUser == null) {
        throw Exception('Failed to create user');
      }

      await FirebaseFirestore.instance
          .collection('shop-profile')
          .doc(createdUser.uid)
          .set({
            'email': email,
            'shopName': _shopNameController.text.trim(),
            'ownerName': _ownerNameController.text.trim(),
            'ownerPhone': _ownerPhoneController.text.trim(),
            'shopAddress': _shopAddressController.text.trim(),
            'shopPhone': _shopPhoneController.text.trim(),
            'shopEmail': _shopEmailController.text.trim(),
            'ownerSignature': _ownerSignatureBase64 ?? '',
            'userType': 'user',
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': DateTime.now().toIso8601String(),
          });

      await _trackDevice(createdUser.uid);
      if (!Platform.isWindows) {
        await NotificationService().saveTokenToFirestore();
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MyHomePage(title: '# NK Nagarwala'),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      final loc = AppLocalizations.of(context);
      String message = loc?.registrationFailed ??
          'Registration failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = loc?.emailAlreadyInUse ?? 'This email is already registered';
      } else if (e.code == 'weak-password') {
        message = loc?.weakPassword ?? 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        message = loc?.invalidEmail ?? 'The email address is invalid.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
      }
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${loc?.registrationFailed ?? 'Registration failed'}: $e',
            ),
          ),
        );
      }
    } finally {
      AppLoader.hide();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trackDevice(String userId) async {
    try {
      final deviceInfo = await DeviceUtils.getDeviceInfo();
      final deviceDoc = FirebaseFirestore.instance
          .collection('user-devices')
          .doc(userId)
          .collection('devices')
          .doc(deviceInfo['deviceId']);

      await deviceDoc.set({
        'deviceId': deviceInfo['deviceId'],
        'deviceName': deviceInfo['deviceName'],
        'deviceModel': deviceInfo['deviceModel'],
        'platform': deviceInfo['platform'],
        'osVersion': deviceInfo['osVersion'],
        'lastLoginAt': FieldValue.serverTimestamp(),
        'firstLoginAt': FieldValue.serverTimestamp(),
        'revokedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error tracking device: $e');
    }
  }

  void _showLanguageSelector() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final scheme = Theme.of(context).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.language_rounded, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        loc?.selectLanguage ?? 'Select Language',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...languageProvider.supportedLanguages.map((language) {
                  final isSelected =
                      languageProvider.currentLocale.languageCode ==
                      language['code'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected
                          ? scheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        onTap: () async {
                          await languageProvider.changeLanguage(
                            language['code'] ?? 'en',
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        selected: isSelected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(language['nativeName'] ?? ''),
                        subtitle: Text(language['name'] ?? ''),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: scheme.primary)
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSignaturePicker() async {
    final loc = AppLocalizations.of(context);
    await Adaptive.showSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc?.addUpdateSignature ?? 'Add Signature',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.draw_outlined),
                  title: Text(loc?.drawSignature ?? 'Draw Signature'),
                  subtitle: Text(loc?.signWithFinger ?? 'Sign with your finger'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showSignaturePad();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(loc?.upload ?? 'Upload'),
                  subtitle: Text(
                    loc?.chooseFromGallery ?? 'Choose from Gallery',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickSignature(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(loc?.camera ?? 'Camera'),
                  subtitle: Text(
                    loc?.takePhotoOfSignature ?? 'Take a photo of your signature',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickSignature(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSignaturePad() {
    final loc = AppLocalizations.of(context);
    final controller = SignatureController(
      penStrokeWidth: 5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          loc?.drawYourSignature ?? 'Draw Your Signature',
                          style: Theme.of(dialogContext).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: controller.clear,
                        child: Text(loc?.clear ?? 'Clear'),
                      ),
                    ],
                  ),
                ),
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
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(loc?.cancel ?? 'Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            if (controller.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc?.pleaseDrawSignature ??
                                        'Please draw your signature',
                                  ),
                                ),
                              );
                              return;
                            }
                            final image = await controller.toImage();
                            if (image == null) return;
                            final bytes = await image.toByteData(
                              format: ui.ImageByteFormat.png,
                            );
                            if (bytes == null || !mounted) return;
                            setState(() {
                              _ownerSignatureBase64 = base64Encode(
                                bytes.buffer.asUint8List(),
                              );
                            });
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                          child: Text(loc?.saveSignature ?? 'Save Signature'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _pickSignature(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _ownerSignatureBase64 = base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc?.error ?? 'Error'}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.92),
              scheme.primary,
              scheme.primaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: _showLanguageSelector,
                      tooltip: loc?.selectLanguage ?? 'Select Language',
                      icon: const Icon(Icons.language_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: size.width > 600 ? 520 : double.infinity,
                      ),
                      child: Column(
                        children: [
                          _buildHeader(scheme, loc),
                          const SizedBox(height: 28),
                          _buildFormCard(scheme, loc),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme, AppLocalizations? loc) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.storefront_rounded, size: 40, color: scheme.primary),
        ),
        const SizedBox(height: 20),
        Text(
          loc?.createAccount ?? 'Create Account',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: scheme.onPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          loc?.fillAllRequiredFields ?? 'Fill all required fields to get started',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: scheme.onPrimary.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(ColorScheme scheme, AppLocalizations? loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionLabel(loc?.accountDetails ?? 'Account Details'),
              _buildTextField(
                controller: _emailController,
                label: loc?.email ?? 'Email',
                hint: loc?.enterEmailOrUsername ?? 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => _email(
                  v,
                  loc?.pleaseEnterEmailOrUsername ?? 'Please enter email',
                  loc?.pleaseEnterValidEmail ?? 'Please enter valid email',
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: loc?.password ?? 'Password',
                hint: loc?.enterPassword ?? 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: !_showPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return loc?.pleaseEnterPassword ?? 'Please enter password';
                  }
                  if (v.length < 6) {
                    return loc?.passwordMinLength ??
                        'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _confirmPasswordController,
                label: loc?.confirmPassword ?? 'Confirm Password',
                hint: loc?.confirmPassword ?? 'Confirm Password',
                icon: Icons.lock_outline_rounded,
                obscureText: !_showConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () =>
                      setState(() => _showConfirmPassword = !_showConfirmPassword),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return loc?.confirmPasswordRequired ??
                        'Please confirm your password';
                  }
                  if (v != _passwordController.text) {
                    return loc?.passwordsDoNotMatch ?? 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _sectionLabel(loc?.basicInformation ?? 'Basic Information'),
              _buildTextField(
                controller: _shopNameController,
                label: loc?.shopName ?? 'Shop Name',
                hint: loc?.enterShopName ?? 'Enter your shop name',
                icon: Icons.storefront_outlined,
                validator: (v) => _required(
                  v,
                  loc?.pleaseEnterShopName ?? 'Please enter shop name',
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _ownerNameController,
                label: loc?.ownerName ?? 'Owner Name',
                hint: loc?.enterOwnerName ?? 'Enter owner name',
                icon: Icons.person_outline,
                validator: (v) => _required(
                  v,
                  loc?.pleaseEnterOwnerName ?? 'Please enter owner name',
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel(loc?.contactInformation ?? 'Contact Information'),
              _buildTextField(
                controller: _shopAddressController,
                label: loc?.shopAddress ?? 'Shop Address',
                hint:
                    loc?.enterCompleteShopAddress ??
                    'Enter complete shop address',
                icon: Icons.location_on_outlined,
                maxLines: 3,
                validator: (v) => _required(
                  v,
                  loc?.pleaseEnterShopAddress ?? 'Please enter shop address',
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _shopPhoneController,
                label: loc?.shopPhone ?? 'Shop Phone',
                hint: loc?.enterMobileNumber ?? 'Enter mobile number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => _phone(
                  v,
                  loc?.pleaseEnterPhoneNumber ?? 'Please enter phone number',
                  loc?.pleaseEnterValidPhoneNumber ??
                      'Please enter valid phone number',
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _ownerPhoneController,
                label: loc?.ownerPhone ?? 'Owner Phone',
                hint: loc?.enterOwnerPhone ?? 'Enter owner phone',
                icon: Icons.phone_android_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => _phone(
                  v,
                  loc?.pleaseEnterOwnerPhone ?? 'Please enter owner phone',
                  loc?.pleaseEnterValidPhoneNumber ??
                      'Please enter valid phone number',
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _shopEmailController,
                label: loc?.shopEmail ?? 'Shop Email',
                hint: loc?.enterEmailAddress ?? 'Enter email address',
                icon: Icons.alternate_email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => _email(
                  v,
                  loc?.pleaseEnterShopEmail ?? 'Please enter shop email',
                  loc?.pleaseEnterValidEmail ?? 'Please enter valid email',
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel(loc?.additionalInformation ?? 'Additional Information'),
              _buildSignatureField(scheme, loc),
              const SizedBox(height: 28),
              _buildSubmitButton(loc),
              const SizedBox(height: 16),
              _buildSignInRow(loc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

  Widget _buildSignatureField(ColorScheme scheme, AppLocalizations? loc) {
    final showError = _submitted && !_hasSignature;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _loading ? null : _showSignaturePicker,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: showError ? scheme.error : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: _hasSignature
                    ? Image.memory(
                        base64Decode(_ownerSignatureBase64!),
                        fit: BoxFit.contain,
                      )
                    : Icon(Icons.draw_outlined, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${loc?.ownerSignature ?? 'Owner Signature'} *',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showError
                          ? (loc?.pleaseAddSignature ??
                                'Please add owner signature')
                          : _hasSignature
                          ? (loc?.updateSignature ?? 'Update Signature')
                          : (loc?.addSignature ?? 'Add Signature'),
                      style: TextStyle(
                        color: showError
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    int maxLines = 1,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final requiredLabel = label.endsWith('*') ? label : '$label *';

    if (Adaptive.isCupertino) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(requiredLabel, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          CupertinoTextFormFieldRow(
            controller: controller,
            placeholder: hint,
            keyboardType: keyboardType,
            obscureText: obscureText,
            maxLines: obscureText ? 1 : maxLines,
            prefix: Icon(icon, size: 20),
            validator: validator,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ],
      );
    }

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: requiredLabel,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations? loc) {
    final child = _loading
        ? SizedBox(height: 22, width: 22, child: Adaptive.progress())
        : Text(loc?.createAccount ?? 'Create Account');

    if (Adaptive.isCupertino) {
      return CupertinoButton.filled(
        onPressed: _loading ? null : _register,
        child: child,
      );
    }

    return FilledButton(onPressed: _loading ? null : _register, child: child);
  }

  Widget _buildSignInRow(AppLocalizations? loc) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(loc?.alreadyHaveAccount ?? 'Already have an account?'),
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(loc?.signIn ?? 'Sign In'),
        ),
      ],
    );
  }
}
