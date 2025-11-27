import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:nkt/navigation/app_navigator.dart';
import 'package:nkt/pages/login/login.dart';
import 'package:nkt/pages/profile/customer/customers.dart';
import 'package:nkt/pages/profile/products/product.dart';
import 'package:nkt/pages/profile/supplier/suppliers.dart';
import 'package:nkt/pages/profile/units/units.dart';
import 'package:nkt/pages/profile/edit_profile.dart';
import 'package:nkt/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class MyProfile extends StatefulWidget {
  const MyProfile({super.key});

  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  bool _isLoggingOut = false;
  String _shopName = '----';

  @override
  void initState() {
    super.initState();
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('shop-profile/${user.uid}/shopName').get();

      if (snapshot.exists) {
        final shopName = snapshot.value as String?;
        if (shopName != null && shopName.isNotEmpty) {
          setState(() => _shopName = shopName);
        }
      }
    } catch (e) {
      print('Error loading shop name: $e');
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Profile'),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
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
                    _buildSectionHeader('Add', context),
                    _buildMenuItem(
                      Icons.person_add_outlined,
                      'Supplier',
                      context,
                      onTap: () {
                        AppNavigator.push(context, const Suppliers());
                      },
                    ),
                    _buildMenuItem(
                      Icons.scale_outlined,
                      'Unit',
                      context,
                      onTap: () {
                        AppNavigator.push(context, const MeasurementUnitsScreen());
                      },
                    ),
                    _buildMenuItem(
                      Icons.shopping_bag_outlined,
                      'Product Name',
                      context,
                      onTap: () {
                        AppNavigator.push(context, const ProductName());
                      },
                    ),
                    _buildMenuItem(
                      Icons.people_alt_outlined,
                      'Customer',
                      context,
                      onTap: () {
                        AppNavigator.push(context, const Customers());
                      },
                    ),

                    // Privacy Section
                    _buildSectionHeader('PRIVACY', context),
                    _buildMenuItem(
                      Icons.lock_outline,
                      'Change Password',
                      context,
                    ),
                    _buildMenuItem(
                      Icons.policy_outlined,
                      'Privacy Policy',
                      context,
                    ),

                    // General Section
                    _buildSectionHeader('GENERAL', context),
                    _buildMenuItem(
                      Icons.language,
                      'Language',
                      context,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'English',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                    _buildMenuItem(
                      Icons.brightness_6_outlined,
                      'Theme',
                      context,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Dark',
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
                            'Light',
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
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                                ),
                              )
                            : const Icon(Icons.logout, color: Colors.redAccent),
                        label: Text(
                          _isLoggingOut ? 'Logging Out...' : 'Log Out',
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
