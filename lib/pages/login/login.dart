import 'package:flutter/material.dart';
import 'package:flashbill/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flashbill/providers/language_provider.dart';

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
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = '';
      String deviceName = '';
      String deviceModel = '';
      String osVersion = '';
      String platform = '';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; // Unique device ID
        deviceName = androidInfo.model;
        deviceModel = androidInfo.device;
        osVersion = 'Android ${androidInfo.version.release}';
        platform = 'Android';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        deviceName = iosInfo.name;
        deviceModel = iosInfo.model;
        osVersion = 'iOS ${iosInfo.systemVersion}';
        platform = 'iOS';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
        deviceName = windowsInfo.computerName;
        deviceModel = 'Windows PC';
        osVersion = windowsInfo.productName;
        platform = 'Windows';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceId = macInfo.systemGUID ?? 'unknown';
        deviceName = macInfo.computerName;
        deviceModel = macInfo.model;
        osVersion = 'macOS ${macInfo.osRelease}';
        platform = 'macOS';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceId = linuxInfo.machineId ?? 'unknown';
        deviceName = linuxInfo.name;
        deviceModel = linuxInfo.prettyName;
        osVersion = linuxInfo.version ?? 'unknown';
        platform = 'Linux';
      } else {
        // Web or other platforms
        platform = 'Web';
        deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
        deviceName = 'Web Browser';
        deviceModel = 'Browser';
        osVersion = 'Web';
      }

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1e1e30) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and close button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196f3).withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        color: Color(0xFF2196f3),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        loc?.selectLanguage ?? 'Select Language',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Language options
                ...languageProvider.supportedLanguages.map((language) {
                  final isSelected =
                      languageProvider.currentLocale.languageCode ==
                      language['code'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () async {
                        await languageProvider.changeLanguage(
                          language['code'] ?? 'en',
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2196f3).withAlpha(20)
                              : (isDarkMode
                                    ? const Color(0xFF2a2a40)
                                    : Colors.grey[50]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2196f3)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Radio indicator
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2196f3)
                                      : (isDarkMode
                                            ? Colors.grey[600]!
                                            : Colors.grey[400]!),
                                  width: 2,
                                ),
                                color: isSelected
                                    ? const Color(0xFF2196f3)
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),

                            // Language names
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    language['nativeName'] ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    language['name'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Selected indicator
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF2196f3),
                                size: 24,
                              ),
                          ],
                        ),
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFFbbdefb),
                    const Color(0xFF64b5f6),
                    const Color(0xFF2196f3),
                  ]
                : [
                    const Color(0xFFbbdefb),
                    const Color(0xFF64b5f6),
                    const Color(0xFF2196f3),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Language selector button
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.selectLanguage ??
                          'Select Language',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    IconButton(
                      onPressed: _showLanguageSelector,
                      icon: const Icon(
                        Icons.language_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      tooltip: 'Change Language',
                    ),
                  ],
                ),
              ),
              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: size.width > 600 ? 450 : double.infinity,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo and Welcome Text
                        _buildHeader(),
                        const SizedBox(height: 48),

                        // Login Card
                        _buildLoginCard(isDarkMode),
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

  Widget _buildHeader() {
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        // Modern Logo Container
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.store_rounded,
            size: 50,
            color: Color(0xFF2196f3),
          ),
        ),
        const SizedBox(height: 24),

        // Welcome Text
        Text(
          loc?.welcomeBack ?? 'Welcome Back',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          loc?.signInToContinue ?? 'Sign in to continue',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withAlpha(204),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(bool isDarkMode) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFFbbdefb).withAlpha(235)
            : Colors.white.withAlpha(250),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email Field
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
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 24),

            // Password Field
            _buildTextField(
              controller: _passwordController,
              label: loc?.password ?? 'Password',
              hint: loc?.enterPassword ?? 'Enter your password',
              icon: Icons.lock_outline_rounded,
              obscureText: !_showPassword,
              isDarkMode: isDarkMode,
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return loc?.pleaseEnterPassword ?? 'Please enter password';
                }
                return null;
              },
            ),
            const SizedBox(height: 40),

            // Login Button
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
              fontSize: 15,
            ),
            prefixIcon: Icon(
              icon,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              size: 22,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDarkMode ? const Color(0xFFe3f2fd) : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18.0,
              horizontal: 16.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(
                color: isDarkMode
                    ? Colors.transparent
                    : Colors.grey.withAlpha(25),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: BorderSide(color: const Color(0xFF2196f3), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.0),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    final loc = AppLocalizations.of(context);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF64b5f6), Color(0xFF2196f3)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196f3).withAlpha(46),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                loc?.signIn ?? 'Sign In',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
