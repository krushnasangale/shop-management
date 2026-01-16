import 'package:flashbill/pages/profile/logged_in_devices.dart';
import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/login/login.dart';
import 'package:flashbill/pages/profile/customer/customers.dart';
import 'package:flashbill/pages/profile/products/product.dart';
import 'package:flashbill/pages/profile/supplier/suppliers.dart';
import 'package:flashbill/pages/profile/units/units.dart';
import 'package:flashbill/pages/profile/edit_profile.dart';
import 'package:flashbill/pages/profile/privacy_policy.dart';
import 'package:flashbill/providers/theme_provider.dart';
import 'package:flashbill/providers/language_provider.dart';
import 'package:flashbill/widgets/language_selector.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class MyProfile extends StatefulWidget {
  const MyProfile({super.key});

  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  bool _isLoggingOut = false;
  String _shopName = '----';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _shopNameSubscription;

  @override
  void initState() {
    super.initState();
    _listenToShopName();
  }

  void _listenToShopName() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _shopNameSubscription = FirebaseFirestore.instance
          .collection('shop-profile')
          .doc(user.uid)
          .snapshots()
          .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
            if (mounted && snapshot.exists) {
              final shopName = snapshot.data()?['shopName'] as String?;
              if (shopName != null && shopName.isNotEmpty) {
                setState(() => _shopName = shopName);
              }
            }
          });
    } catch (e) {
      print('Error listening to shop name: $e');
    }
  }

  @override
  void dispose() {
    _shopNameSubscription?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations?.logoutFailed ?? 'Logout failed'}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? currentPasswordError;
    String? newPasswordError;
    String? confirmPasswordError;
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                localizations?.changePassword ?? 'Change Password',
                style: context.bodyLargeText,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Current Password Field
                    TextField(
                      controller: currentPasswordController,
                      obscureText: !showCurrentPassword,
                      decoration: InputDecoration(
                        labelText:
                            localizations?.currentPassword ??
                            'Current Password',
                        hintText:
                            localizations?.enterCurrentPassword ??
                            'Enter your current password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showCurrentPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              showCurrentPassword = !showCurrentPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: currentPasswordError != null
                                ? Colors.red
                                : Colors.blue,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (currentPasswordError != null) {
                          setDialogState(() => currentPasswordError = null);
                        }
                      },
                    ),
                    if (currentPasswordError != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentPasswordError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    // New Password Field
                    TextField(
                      controller: newPasswordController,
                      obscureText: !showNewPassword,
                      decoration: InputDecoration(
                        labelText: localizations?.newPassword ?? 'New Password',
                        hintText:
                            localizations?.enterNewPassword ??
                            'Enter your new password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showNewPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              showNewPassword = !showNewPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: newPasswordError != null
                                ? Colors.red
                                : Colors.blue,
                            width: 2,
                          ),
                        ),
                        helperText:
                            localizations?.passwordMinLength ??
                            'Password must be at least 6 characters',
                      ),
                      onChanged: (_) {
                        if (newPasswordError != null) {
                          setDialogState(() => newPasswordError = null);
                        }
                      },
                    ),
                    if (newPasswordError != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              newPasswordError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Confirm Password Field
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: !showConfirmPassword,
                      decoration: InputDecoration(
                        labelText:
                            localizations?.confirmNewPassword ??
                            'Confirm New Password',
                        hintText:
                            localizations?.reEnterNewPassword ??
                            'Re-enter your new password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showConfirmPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              showConfirmPassword = !showConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: confirmPasswordError != null
                                ? Colors.red
                                : Colors.blue,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (confirmPasswordError != null) {
                          setDialogState(() => confirmPasswordError = null);
                        }
                      },
                    ),
                    if (confirmPasswordError != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              confirmPasswordError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(localizations?.cancel ?? 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validate inputs
                    bool hasError = false;
                    setDialogState(() {
                      currentPasswordError = null;
                      newPasswordError = null;
                      confirmPasswordError = null;

                      if (currentPasswordController.text.isEmpty) {
                        currentPasswordError =
                            localizations?.currentPasswordRequired ??
                            'Current password is required';
                        hasError = true;
                      }

                      if (newPasswordController.text.isEmpty) {
                        newPasswordError =
                            localizations?.newPasswordRequired ??
                            'New password is required';
                        hasError = true;
                      } else if (newPasswordController.text.length < 6) {
                        newPasswordError =
                            localizations?.passwordMinLength ??
                            'Password must be at least 6 characters';
                        hasError = true;
                      }

                      if (confirmPasswordController.text.isEmpty) {
                        confirmPasswordError =
                            localizations?.confirmPasswordRequired ??
                            'Please confirm your password';
                        hasError = true;
                      } else if (newPasswordController.text !=
                          confirmPasswordController.text) {
                        confirmPasswordError =
                            localizations?.passwordsDoNotMatch ??
                            'Passwords do not match';
                        hasError = true;
                      }
                    });

                    if (hasError) return;

                    try {
                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext loadingContext) {
                          return AlertDialog(
                            content: SizedBox(
                              height: 80,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    localizations?.updatingPassword ??
                                        'Updating password...',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );

                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        Navigator.pop(context); // Close loading
                        Navigator.pop(dialogContext); // Close dialog
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localizations?.userNotAuthenticated ??
                                  'User not authenticated',
                            ),
                          ),
                        );
                        return;
                      }

                      // Re-authenticate user with current password
                      final credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: currentPasswordController.text,
                      );

                      await user.reauthenticateWithCredential(credential);

                      // Update password
                      await user.updatePassword(newPasswordController.text);

                      Navigator.pop(context); // Close loading
                      Navigator.pop(dialogContext); // Close dialog

                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localizations?.passwordChangedSuccessfully ??
                                  'Password changed successfully!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      Navigator.pop(context); // Close loading

                      String errorMessage =
                          localizations?.failedToChangePassword ??
                          'Failed to change password';
                      if (e.toString().contains('wrong-password')) {
                        errorMessage =
                            localizations?.currentPasswordIncorrect ??
                            'Current password is incorrect';
                      } else if (e.toString().contains('weak-password')) {
                        errorMessage =
                            localizations?.newPasswordTooWeak ??
                            'New password is too weak';
                      } else if (e.toString().contains(
                        'requires-recent-login',
                      )) {
                        errorMessage =
                            localizations?.reauthenticateRequired ??
                            'Please log out and log in again for security';
                      }

                      setDialogState(() {
                        currentPasswordError = errorMessage;
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text(
                    localizations?.changePassword ?? 'Change Password',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localizations?.myProfile ?? 'My Profile')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Profile Header
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF2196F3),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      title: Text(
                        _shopName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        localizations?.viewAndEditProfile ??
                            'View and edit profile',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        AppNavigator.push(context, const EditProfile());
                      },
                    ),
                  ),

                  // Add
                  _buildSectionHeader(
                    localizations?.add.toUpperCase() ?? 'ADD',
                    context,
                  ),
                  _buildCountMenuItem(
                    Icons.person_add_outlined,
                    localizations?.suppliers ?? 'Suppliers',
                    context,
                    'suppliers',
                    onTap: () {
                      AppNavigator.push(context, const Suppliers());
                    },
                  ),
                  _buildCountMenuItem(
                    Icons.scale_outlined,
                    localizations?.units ?? 'Units',
                    context,
                    'units',
                    onTap: () {
                      AppNavigator.push(
                        context,
                        const MeasurementUnitsScreen(),
                      );
                    },
                  ),
                  _buildCountMenuItem(
                    Icons.shopping_bag_outlined,
                    localizations?.productNames ?? 'Product Names',
                    context,
                    'product-names',
                    onTap: () {
                      AppNavigator.push(context, const ProductName());
                    },
                  ),
                  _buildCountMenuItem(
                    Icons.people_alt_outlined,
                    localizations?.customers ?? 'Customers',
                    context,
                    'customers',
                    onTap: () {
                      AppNavigator.push(context, const Customers());
                    },
                  ),

                  // Privacy Section
                  _buildSectionHeader(
                    localizations?.privacy.toUpperCase() ?? 'PRIVACY',
                    context,
                  ),
                  _buildLoggedInDevicesMenuItem(context),
                  _buildMenuItem(
                    Icons.lock_outline,
                    localizations?.changePassword ?? 'Change Password',
                    context,
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                  _buildMenuItem(
                    Icons.policy_outlined,
                    localizations?.privacyPolicy ?? 'Privacy Policy',
                    context,
                    onTap: () {
                      AppNavigator.push(context, const PrivacyPolicyPage());
                    },
                  ),

                  // General Section
                  _buildSectionHeader(
                    localizations?.general.toUpperCase() ?? 'GENERAL',
                    context,
                  ),
                  Consumer<LanguageProvider>(
                    builder: (context, languageProvider, _) {
                      return _buildMenuItem(
                        Icons.language,
                        localizations?.language ?? 'Language',
                        context,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              languageProvider.getNativeLanguageName(
                                languageProvider.currentLocale.languageCode,
                              ),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        onTap: () {
                          AppNavigator.push(context, const LanguageSelector());
                        },
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.brightness_6_outlined,
                    localizations?.theme ?? 'Theme',
                    context,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          localizations?.dark ?? 'Dark',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Transform.scale(
                          scale: 0.75,
                          child: Consumer<ThemeProvider>(
                            builder: (context, themeProvider, _) {
                              return Switch(
                                value: themeProvider.isLightTheme,
                                onChanged: (value) {
                                  themeProvider.toggleTheme();
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          localizations?.light ?? 'Light',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: ElevatedButton.icon(
                      onPressed: _isLoggingOut ? null : _logout,
                      icon: _isLoggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.redAccent,
                                ),
                              ),
                            )
                          : const Icon(Icons.logout, color: Colors.redAccent),
                      label: Text(
                        _isLoggingOut
                            ? (localizations?.loggingOut ?? 'Logging Out...')
                            : (localizations?.logOut ?? 'Log Out'),
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Logout Button (fixed at bottom)
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 20.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildLoggedInDevicesMenuItem(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final localizations = AppLocalizations.of(context);

    if (user == null) {
      return _buildMenuItem(
        Icons.device_unknown,
        localizations?.loggedInDevices ?? 'Logged In Devices',
        context,
        onTap: () {
          AppNavigator.push(context, const LoggedInDevicesScreen());
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user-devices')
          .doc(user.uid)
          .collection('devices')
          .snapshots(),
      builder: (context, snapshot) {
        int deviceCount = 0;

        if (snapshot.hasData) {
          // Filter out revoked devices
          deviceCount = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['revokedAt'] == null;
          }).length;
        }

        return _buildMenuItem(
          Icons.device_unknown,
          localizations?.loggedInDevices ?? 'Logged In Devices',
          context,
          onTap: () {
            AppNavigator.push(context, const LoggedInDevicesScreen());
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$deviceCount',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountMenuItem(
    IconData icon,
    String title,
    BuildContext context,
    String collectionName, {
    GestureTapCallback? onTap,
  }) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildMenuItem(icon, title, context, onTap: onTap);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionName)
          .doc(user.uid)
          .collection('items')
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;

        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }

        return _buildMenuItem(
          icon,
          title,
          context,
          onTap: onTap,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    BuildContext context, {
    Widget? trailing,
    bool showChevron = true,
    GestureTapCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          height: 35,
          width: 35,
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        trailing: showChevron
            ? (trailing ?? const Icon(Icons.chevron_right, color: Colors.grey))
            : trailing,
        onTap: onTap,
      ),
    );
  }
}
