import 'package:flutter/material.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/login/login.dart';
import 'package:flashbill/pages/products/available_products.dart';
import 'package:flashbill/pages/billing/bills.dart';
import 'package:flashbill/pages/billing/create_new_bill.dart';
import 'package:flashbill/pages/purchase/purchase_items_list.dart';
import 'package:flashbill/pages/purchase/add_purchase_entry.dart';
import 'package:flashbill/pages/dashboard.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flashbill/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
              if (snapshot.hasData) {
                return const MyHomePage(title: '');
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _shopNameSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSubscription;
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
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              icon: const Icon(Icons.account_circle, size: 35,),
              onPressed: () async {
                AppNavigator.push(context, const MyProfile());
              },
              tooltip: 'Logout',
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
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
            label: 'Products',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Bills',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Purchases',
          ),
        ],
      ),
    );
  }
}
