import 'package:flutter/material.dart';
import 'package:nkt/navigation/app_navigator.dart';
import 'package:nkt/pages/login/login.dart';
import 'package:nkt/pages/products/available_products.dart';
import 'package:nkt/pages/billing/bills.dart';
import 'package:nkt/pages/billing/create_new_bill.dart';
import 'package:nkt/pages/purchase/purchase_items_list.dart';
import 'package:nkt/pages/purchase/add_purchase_entry.dart';
import 'package:nkt/pages/dashboard.dart';
import 'package:nkt/pages/profile/my_profile.dart';
import 'package:nkt/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          title: 'Nath Krupa',
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
                return const MyHomePage(title: '# NK Nagarwala');
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

  // List of screens for the IndexedStack
  final List<Widget> _screens = const [
    Dashboard(),
    AvailableProducts(),
    Bills(),
    PurchaseItemsList(),
    MyProfile(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title), centerTitle: true),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up),
              label: 'Sells',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag),
              label: 'Purchases',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
          ],
        ),
      ),
    );
  }
}
