import 'package:flutter/material.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/login/login.dart';
import 'package:flashbill/pages/products/available_products.dart';
import 'package:flashbill/pages/billing/bills.dart';
import 'package:flashbill/pages/billing/create_new_bill.dart';
import 'package:flashbill/pages/purchase/purchase_items_list.dart';
import 'package:flashbill/pages/purchase/add_purchase_entry.dart';
import 'package:flashbill/pages/dashboard.dart';
import 'package:flashbill/pages/admin_dashboard.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flashbill/providers/theme_provider.dart';
import 'package:flashbill/providers/dashboard_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String> _getCurrentDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = '';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceId = macInfo.systemGUID ?? 'unknown';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceId = linuxInfo.machineId ?? 'unknown';
      } else {
        deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
      }

      return deviceId;
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return 'unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentTheme,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData && snapshot.data != null) {
                // Listen to device revocation status in real-time
                return FutureBuilder<String>(
                  future: _getCurrentDeviceId(),
                  builder: (context, deviceIdSnapshot) {
                    if (deviceIdSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final deviceId = deviceIdSnapshot.data ?? 'unknown';

                    // Stream for device document with error handling to avoid
                    // permission-denied crashes when auth state changes rapidly.
                    final deviceStream = FirebaseFirestore.instance
                        .collection('user-devices')
                        .doc(snapshot.data!.uid)
                        .collection('devices')
                        .doc(deviceId)
                        .snapshots()
                        .handleError((e) {
                          // Swallow permission errors (user signed out) to avoid
                          // unhandled exceptions coming from the native plugin.
                          if (e is FirebaseException &&
                              e.code == 'permission-denied') {
                            debugPrint(
                              'Ignored permission error on device snapshot: $e',
                            );
                            return;
                          }
                          // Re-throw other errors so they surface normally.
                          throw e;
                        });

                    return StreamBuilder<DocumentSnapshot>(
                      stream: deviceStream,
                      builder: (context, deviceSnapshot) {
                        if (deviceSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (deviceSnapshot.hasError) {
                          debugPrint(
                            'Device snapshot error: ${deviceSnapshot.error}',
                          );
                          // If there's an auth/permission error, ensure user is
                          // signed out and show login screen to recover.
                          try {
                            FirebaseAuth.instance.signOut();
                          } catch (_) {}
                          return const LoginScreen();
                        }

                        // Check if device is revoked
                        if (deviceSnapshot.hasData &&
                            deviceSnapshot.data!.exists) {
                          final data =
                              deviceSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                          if (data != null &&
                              data.containsKey('revokedAt') &&
                              data['revokedAt'] != null) {
                            try {
                              final revokedTs = data['revokedAt'];
                              DateTime revokedAt;
                              if (revokedTs is Timestamp) {
                                revokedAt = revokedTs.toDate();
                              } else if (revokedTs is DateTime) {
                                revokedAt = revokedTs;
                              } else {
                                revokedAt = DateTime.now();
                              }

                              final user = FirebaseAuth.instance.currentUser;
                              final lastSignIn = user?.metadata.lastSignInTime;

                              // If the user just signed in after revocation was set
                              // (race condition), allow the session. Add a small
                              // grace window to account for server timestamp delays.
                              if (lastSignIn != null &&
                                  lastSignIn.isAfter(
                                    revokedAt.subtract(
                                      const Duration(seconds: 3),
                                    ),
                                  )) {
                                // Recent login — treat as valid, don't force sign-out.
                              } else {
                                // Device is revoked and not a fresh login — sign out.
                                FirebaseAuth.instance.signOut();
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'This device has been logged out remotely',
                                        ),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                });
                                return const LoginScreen();
                              }
                            } catch (e) {
                              debugPrint('Error parsing revokedAt: $e');
                              try {
                                FirebaseAuth.instance.signOut();
                              } catch (_) {}
                              return const LoginScreen();
                            }
                          }
                        }

                        return const MyHomePage(title: '');
                      },
                    );
                  },
                );
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  String _shopName = '----';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _shopNameSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _productsSubscription;
  int _productsCount = 0;

  @override
  void initState() {
    super.initState();
    _listenToShopName();
    _listenToProductsCount();
  }

  void _listenToShopName() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
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
      }
    } catch (e) {
      print('Error listening to shop name: $e');
    }
  }

  void _listenToProductsCount() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _productsSubscription = FirebaseFirestore.instance
            .collection('purchased-products')
            .doc(user.uid)
            .collection('items')
            .where('quantity', isGreaterThan: 0)
            .snapshots()
            .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
              if (mounted) {
                // Group by product name to get unique count
                final uniqueProducts = <String>{};
                for (var doc in snapshot.docs) {
                  final productName = doc.data()['productName'] as String?;
                  if (productName != null) {
                    uniqueProducts.add(productName);
                  }
                }
                setState(() => _productsCount = uniqueProducts.length);
              }
            });
      }
    } catch (e) {
      print('Error listening to products count: $e');
    }
  }

  @override
  void dispose() {
    _shopNameSubscription?.cancel();
    _productsSubscription?.cancel();
    super.dispose();
  }

  // List of screens for the IndexedStack
  final List<Widget> _screens = const [
    Dashboard(),
    AvailableProducts(),
    Bills(),
    PurchaseItemsList(),
    AdminDashboard(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              title: Text(_shopName),
              automaticallyImplyLeading: false,
              actions: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.grey.withOpacity(0.2),
                  ),
                  height: 40,
                  width: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.account_circle, size: 35),
                    onPressed: () async {
                      AppNavigator.push(context, const MyProfile());
                    },
                    tooltip: 'My Profile',
                  ),
                ),
                const SizedBox(width: 14),
              ],
            )
          : null,
      body: IndexedStack(index: _selectedIndex, children: _screens),

      floatingActionButton: _selectedIndex == 2 || _selectedIndex == 3
          ? FloatingActionButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onPressed: () {
                if (_selectedIndex == 2) {
                  AppNavigator.push(context, const CreateNewBill());
                } else if (_selectedIndex == 3) {
                  AppNavigator.push(context, const AddPurchaseEntry());
                }
              },
              backgroundColor: const Color(0xFF2196F3),
              tooltip: 'Add Item',
              child: const Icon(Icons.add, color: Colors.white, size: 45),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(Icons.inventory_2),
                if (_productsCount > 0)
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        _productsCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Availability',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Bills',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Purchases',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
        ],
      ),
    );
  }
}
