import 'package:flashbill/providers/language_provider.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flashbill/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flashbill/services/notification_service.dart';
import 'package:flashbill/utils/device_utils.dart';
import 'package:flashbill/theme/adaptive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // Track device after successful login
      if (userCredential.user != null) {
        await _trackDevice(userCredential.user!.uid);

        // Save FCM token to Firestore on login
        if (!Platform.isWindows) {
          await NotificationService().saveTokenToFirestore();
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MyHomePage(title: '# NK Nagarwala'),
        ),
      );
    } on FirebaseAuthException catch (e, st) {
      final loc = AppLocalizations.of(context);
      String message = loc?.loginFailed ?? 'Login failed. Please try again.';
      if (e.code == 'user-not-found') {
        message = loc?.userNotFound ?? 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = loc?.incorrectPassword ?? 'Incorrect password provided.';
      } else if (e.code == 'invalid-email') {
        message = loc?.invalidEmail ?? 'The email address is invalid.';
      }
      debugPrint('FirebaseAuthException during login: ${e.code} ${e.message}');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trackDevice(String userId) async {
    try {
      final deviceInfo = await DeviceUtils.getDeviceInfo();
      final deviceId = deviceInfo['deviceId']!;
      final deviceName = deviceInfo['deviceName']!;
      final deviceModel = deviceInfo['deviceModel']!;
      final osVersion = deviceInfo['osVersion']!;
      final platform = deviceInfo['platform']!;

      // Store device information in Firestore
      final deviceDoc = FirebaseFirestore.instance
          .collection('user-devices')
          .doc(userId)
          .collection('devices')
          .doc(deviceId);

      // Check if device was previously revoked
      final existingDoc = await deviceDoc.get();
      final wasRevoked =
          existingDoc.exists && existingDoc.data()?['revokedAt'] != null;

      await deviceDoc.set({
        'deviceId': deviceId,
        'deviceName': deviceName,
        'deviceModel': deviceModel,
        'platform': platform,
        'osVersion': osVersion,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'firstLoginAt': FieldValue.serverTimestamp(),
        'revokedAt': FieldValue.delete(), // Remove revocation on new login
      }, SetOptions(merge: true)); // Merge to keep firstLoginAt

      debugPrint(
        'Device tracked successfully: $deviceId${wasRevoked ? " (revocation cleared)" : ""}',
      );
    } catch (e) {
      debugPrint('Error tracking device: $e');
      // Don't block login if device tracking fails
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
                    child: ListTile(
                      onTap: () async {
                        await languageProvider.changeLanguage(
                          language['code'] ?? 'en',
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      selected: isSelected,
                      selectedTileColor: scheme.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(language['nativeName'] ?? ''),
                      subtitle: Text(language['name'] ?? ''),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: scheme.primary)
                          : null,
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

  @override
  Widget build(BuildContext context) {
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
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: _showLanguageSelector,
                  tooltip: loc?.selectLanguage ?? 'Select Language',
                  icon: const Icon(Icons.language_rounded),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: size.width > 600 ? 440 : double.infinity,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(scheme, loc),
                        const SizedBox(height: 36),
                        _buildLoginCard(scheme, loc),
                      ],
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
          loc?.welcomeBack ?? 'Welcome Back',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: scheme.onPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          loc?.signInToContinue ?? 'Sign in to continue',
          style: TextStyle(
            fontSize: 16,
            color: scheme.onPrimary.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(ColorScheme scheme, AppLocalizations? loc) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: _emailController,
                label: loc?.email ?? 'Email',
                hint: loc?.enterEmailOrUsername ?? 'Enter your email or username',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return loc?.pleaseEnterEmailOrUsername ??
                        'Please enter email or username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
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
                  onPressed: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return loc?.pleaseEnterPassword ?? 'Please enter password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              _buildLoginButton(loc),
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
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    if (Adaptive.isCupertino) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          CupertinoTextFormFieldRow(
            controller: controller,
            placeholder: hint,
            keyboardType: keyboardType,
            obscureText: obscureText,
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
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildLoginButton(AppLocalizations? loc) {
    final child = _loading
        ? SizedBox(height: 22, width: 22, child: Adaptive.progress())
        : Text(loc?.signIn ?? 'Sign In');

    if (Adaptive.isCupertino) {
      return CupertinoButton.filled(
        onPressed: _loading ? null : _login,
        child: child,
      );
    }

    return FilledButton(onPressed: _loading ? null : _login, child: child);
  }
}

