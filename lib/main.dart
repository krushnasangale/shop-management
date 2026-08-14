import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/login/login.dart';
import 'package:flashbill/pages/products/available_products.dart';
import 'package:flashbill/pages/billing/bills.dart';
import 'package:flashbill/pages/billing/create_new_bill.dart';
import 'package:flashbill/pages/purchase/purchase_items_list.dart';
import 'package:flashbill/pages/purchase/add_purchase_entry.dart';
import 'package:flashbill/pages/expenses/expenses_list.dart';
import 'package:flashbill/pages/pending_payments_page.dart';
import 'package:flashbill/pages/dashboard.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flashbill/providers/theme_provider.dart';
import 'package:flashbill/providers/dashboard_provider.dart';
import 'package:flashbill/providers/language_provider.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/services/notification_service.dart';
import 'package:flashbill/utils/device_utils.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'package:flashbill/services/gemini_service.dart';
import 'package:flashbill/services/crash_reporting_service.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/theme/app_theme.dart';
import 'package:flashbill/widgets/app_bottom_nav.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  appLog("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics + Performance: crashes, uncaught errors, ANRs, UI hangs
  await CrashReportingService.instance.initialize();

  // Initialize Firebase Analytics
  FirebaseAnalytics.instance;

  // Initialize Firebase Messaging for mobile platforms
  if (!Platform.isWindows) {
    await NotificationService().initialize();
    NotificationService().setOnNotificationOpened(
      MyApp.handleNotificationOpened,
    );
  }

  // Initialize Gemini service (uses Firebase Vertex AI)
  try {
    await GeminiService().initialize();
  } catch (e, stack) {
    appLog('⚠️ Warning: Could not initialize Gemini service: $e');
    appLog('   Make sure Firebase is properly configured for this project.');
    await CrashReportingService.instance.recordError(
      e,
      stack,
      reason: 'gemini_init',
    );
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

  // Global navigator key for navigation from services
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Handle notification navigation
  static void handleNotificationOpened(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Handle different notification types
    final type = data['type'];

    switch (type) {
      case 'bill':
        // Navigate to bill details (if implemented)
        // AppNavigator.push(context, BillDetailsPage(billId: id));
        break;
      case 'payment':
        // Navigate to pending payments
        AppNavigator.push(context, const PendingPaymentsPage());
        break;
      case 'product':
        // Navigate to available products
        AppNavigator.push(context, const AvailableProducts());
        break;
      case 'good_morning':
        // Navigate to dashboard for daily overview
        AppNavigator.push(context, const Dashboard());
        break;
      case 'low_stock':
        // Navigate to products page to check stock
        AppNavigator.push(context, const AvailableProducts());
        break;
      default:
        // Navigate to dashboard
        AppNavigator.push(context, const Dashboard());
    }
  }

  Future<String> _getCurrentDeviceId() async {
    return await DeviceUtils.getDeviceId();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        return MaterialApp(
          navigatorKey: MyApp.navigatorKey,
          navigatorObservers: [CrashReportingService.navigatorObserver],
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          locale: languageProvider.currentLocale,
          supportedLocales: const [
            Locale('en', ''), // English
            Locale('hi', ''), // Hindi
            Locale('mr', ''), // Marathi
          ],
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              CrashReportingService.instance.markAppReady();
            });
            final content = child ?? const SizedBox.shrink();
            // Plugins still import package:flutter/material.dart during the SDK transition.
            // ignore: deprecated_member_use
            return MaterialUiCompatibilityBridge(
              child: CupertinoTheme(
                data: AppTheme.cupertino(Theme.of(context).brightness),
                child: content,
              ),
            );
          },
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(body: Center(child: Adaptive.progress()));
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
          appLog('Error listening to shop name: $error');
        },
      );
    } catch (e) {
      appLog('Error setting up shop name listener: $e');
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
          appLog('Error listening to app settings: $error');
        },
      );
    } catch (e) {
      appLog('Error setting up app settings listener: $e');
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
      appLog('Error listening to products count: $e');
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

  List<AppDestination> get _destinations {
    final localizations = AppLocalizations.of(context);
    return [
      AppDestination(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: localizations?.dashboard ?? 'Dashboard',
      ),
      AppDestination(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: localizations?.availability ?? 'Availability',
        badge: _productsCount > 0 ? _productsCount.toString() : null,
      ),
      AppDestination(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: localizations?.bills ?? 'Bills',
      ),
      AppDestination(
        icon: Icons.shopping_bag_outlined,
        selectedIcon: Icons.shopping_bag,
        label: localizations?.purchases ?? 'Purchases',
      ),
      if (_expensesEnabled)
        AppDestination(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
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
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                  height: 40,
                  width: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.account_circle, size: 35),
                    onPressed: () {
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
      floatingActionButton: (_selectedIndex == 2 || _selectedIndex == 3)
          ? FloatingActionButton(
              heroTag: 'fab_$_selectedIndex',
              onPressed: () {
                if (_selectedIndex == 2) {
                  AppNavigator.push(context, const CreateNewBill());
                } else if (_selectedIndex == 3) {
                  AppNavigator.push(context, const AddPurchaseEntry());
                }
              },
              tooltip: localizations?.addItem ?? 'Add Item',
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: AppBottomNav(
        index: _selectedIndex,
        destinations: _destinations,
        onSelect: _onItemTapped,
      ),
    );
  }
}
