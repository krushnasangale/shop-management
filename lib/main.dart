import 'package:flashbill/pages/expenses/add_expense_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/login/login.dart';
import 'package:flashbill/pages/products/available_products.dart';
import 'package:flashbill/pages/billing/bills.dart';
import 'package:flashbill/pages/billing/create_new_bill.dart';
import 'package:flashbill/pages/purchase/purchase_items_list.dart';
import 'package:flashbill/pages/purchase/add_purchase_entry.dart';
import 'package:flashbill/pages/expenses/expenses_list.dart';
import 'package:flashbill/pages/dashboard.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flashbill/pages/reports/reports_page.dart';
import 'package:flashbill/providers/theme_provider.dart';
import 'package:flashbill/providers/dashboard_provider.dart';
import 'package:flashbill/providers/language_provider.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/services/gemini_service.dart';
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

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Gemini service (uses Firebase Vertex AI)
  try {
    await GeminiService().initialize();
  } catch (e) {
    print('⚠️ Warning: Could not initialize Gemini service: $e');
    print('   Make sure Firebase is properly configured for this project.');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
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
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentTheme,
          locale: languageProvider.currentLocale,
          supportedLocales: const [
            Locale('en', ''), // English
            Locale('hi', ''), // Hindi
            Locale('mr', ''), // Marathi
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
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
                                    final localizations = AppLocalizations.of(
                                      context,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          localizations
                                                  ?.deviceLoggedOutRemotely ??
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
  late final ProfileService _profileService;
  StreamSubscription<Map<String, dynamic>>? _shopNameSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _productsSubscription;
  StreamSubscription<Map<String, dynamic>>? _appSettingsSubscription;
  int _productsCount = 0;
  bool _expensesEnabled = false; // Default to disabled

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _profileService.initialize(user.uid);
    }
    _listenToShopName();
    _listenToProductsCount();
    _listenToAppSettings();
  }

  void _listenToShopName() {
    try {
      _shopNameSubscription = _profileService.profileStream.listen(
        (profileData) {
          if (mounted) {
            final shopName = profileData['shopName'] as String?;
            if (shopName != null && shopName.isNotEmpty) {
              setState(() => _shopName = shopName);
            }
          }
        },
        onError: (error) {
          print('Error listening to shop name: $error');
        },
      );
    } catch (e) {
      print('Error setting up shop name listener: $e');
    }
  }

  void _listenToAppSettings() {
    try {
      _appSettingsSubscription = _profileService.appSettingsStream.listen(
        (appSettings) {
          if (mounted) {
            final expensesEnabled = appSettings['expensesEnabled'] ?? false;
            setState(() => _expensesEnabled = expensesEnabled);
          }
        },
        onError: (error) {
          print('Error listening to app settings: $error');
        },
      );
    } catch (e) {
      print('Error setting up app settings listener: $e');
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
    _appSettingsSubscription?.cancel();
    _profileService.dispose();
    super.dispose();
  }

  // Dynamic list of screens based on settings
  List<Widget> get _screens => [
    const Dashboard(),
    const AvailableProducts(),
    const Bills(),
    const PurchaseItemsList(),
    if (_expensesEnabled) const ExpensesList(),
  ];

  // Dynamic list of navigation items based on settings
  List<BottomNavigationBarItem> get _navigationItems {
    final localizations = AppLocalizations.of(context);
    return [
      BottomNavigationBarItem(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _selectedIndex == 0
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.dashboard, size: 24),
        ),
        label: localizations?.dashboard ?? 'Dashboard',
      ),
      BottomNavigationBarItem(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _selectedIndex == 1
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(Icons.inventory_2, size: 24),
              if (_productsCount > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade500,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade500.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _productsCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        label: localizations?.availability ?? 'Availability',
      ),
      BottomNavigationBarItem(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _selectedIndex == 2
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.receipt_long, size: 24),
        ),
        label: localizations?.bills ?? 'Bills',
      ),
      BottomNavigationBarItem(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _selectedIndex == 3
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.shopping_bag, size: 24),
        ),
        label: localizations?.purchases ?? 'Purchases',
      ),
      if (_expensesEnabled)
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _selectedIndex == (_expensesEnabled ? 4 : -1)
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.account_balance_wallet, size: 24),
          ),
          label: localizations?.expenses ?? 'Expenses',
        ),
    ];
  }

  void _onItemTapped(int index) {
    // Ensure the selected index is valid for the current screens
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              title: Text(_shopName),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  onPressed: () {
                    AppNavigator.push(context, const ReportsPage());
                  },
                  tooltip: localizations?.reports ?? 'Reports',
                ),
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
                    tooltip: localizations?.myProfile ?? 'My Profile',
                  ),
                ),
                const SizedBox(width: 14),
              ],
            )
          : null,
      body: IndexedStack(index: _selectedIndex, children: _screens),

      floatingActionButton:
          (_selectedIndex == 2 ||
              _selectedIndex == 3 ||
              (_expensesEnabled && _selectedIndex == 4))
          ? Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade400,
                    Colors.blue.shade400,
                    Colors.cyan.shade400,
                    Colors.teal.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.shade300.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.blue.shade300.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.cyan.shade300.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: FloatingActionButton(
                  heroTag: 'fab_$_selectedIndex',
                  onPressed: () {
                    if (_selectedIndex == 2) {
                      AppNavigator.push(context, const CreateNewBill());
                    } else if (_selectedIndex == 3) {
                      AppNavigator.push(context, const AddPurchaseEntry());
                    } else if (_expensesEnabled && _selectedIndex == 4) {
                      AppNavigator.push(context, const AddExpenseEntry());
                    }
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  tooltip: localizations?.addItem ?? 'Add Item',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade500,
                          Colors.blue.shade500,
                          Colors.cyan.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 32),
                  ),
                ),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          elevation: 0,
          showUnselectedLabels: true,
          items: _navigationItems,
        ),
      ),
    );
  }
}
