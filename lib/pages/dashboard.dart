import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:nkt/pages/helpers/utils.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  DateTime selectedDate = DateTime.now();
  bool _isLoading = true;
  int _totalSales = 0;
  int _totalBuying = 0;
  int _totalProfitLoss = 0;
  int _totalSalesCount = 0; // Number of bills/sales
  int _totalItemsSold = 0; // Total items sold
  int _totalBuyingCount = 0; // Number of purchase transactions
  int _totalItemsBought = 0; // Total items bought in selected month
  int _totalQuantityBought = 0; // Total quantity of items bought in selected month
  double _salesPercentageChange = 0;
  double _buyingPercentageChange = 0;
  StreamSubscription<DatabaseEvent>? _billsSubscription;
  StreamSubscription<DatabaseEvent>? _purchasesSubscription;
  StreamSubscription<DatabaseEvent>? _productsSubscription;

  @override
  void initState() {
    super.initState();
    _loadSalesReport();
  }

  @override
  void dispose() {
    _billsSubscription?.cancel();
    _purchasesSubscription?.cancel();
    _productsSubscription?.cancel();
    super.dispose();
  }

  void _loadSalesReport() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final database = FirebaseDatabase.instance;
    final userId = user.uid;

    // Listen to bills changes
    _billsSubscription = database.ref('bills/$userId').onValue.listen((_) {
      _calculateAndUpdateDashboard(user.uid);
    });

    // Listen to purchases changes
    _purchasesSubscription = database.ref('purchases/$userId').onValue.listen((_) {
      _calculateAndUpdateDashboard(user.uid);
    });

    // Listen to purchased products changes (for inventory)
    _productsSubscription = database.ref('purchased-products/$userId').onValue.listen((_) {
      _calculateAndUpdateDashboard(user.uid);
    });
  }

  Future<void> _calculateAndUpdateDashboard(String userId) async {
    try {
      final database = FirebaseDatabase.instance;
      
      // Load bills data and calculate sales + profit
      int totalSales = 0;
      int totalProfit = 0;
      int totalBuying = 0;
      int salesCount = 0;
      int itemsSold = 0;
      
      final billsSnapshot = await database.ref('bills/$userId').get();

      if (billsSnapshot.exists) {
        final data = billsSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final billData = Map<String, dynamic>.from(value);
            final billDate = billData['billDate'] as String? ?? '';
            final totalAmount = billData['totalAmount'] ?? 0;
            final products = billData['products'] as Map<dynamic, dynamic>?;

            // Check if bill is from selected month
            if (_isFromSelectedMonth(billDate)) {
              totalSales += (totalAmount as num).toInt();
              salesCount++; // Increment sales count

              // Calculate profit for this bill using bought price and selling price
              if (products != null) {
                products.forEach((pKey, pValue) {
                  if (pValue is Map) {
                    final productData = Map<String, dynamic>.from(pValue);
                    final quantity = productData['quantity'] as num? ?? 0;
                    final sellingPrice = productData['price'] as num? ?? 0;
                    final boughtPrice = productData['boughtPrice'] as num? ?? 0;
                  
                    itemsSold += quantity.toInt();
                    
                    final profitPerUnit = (sellingPrice - boughtPrice).toInt();
                    final productProfit = (profitPerUnit * quantity).toInt();
                    
                    totalProfit += productProfit;
                  }
                });
              }
            }
          }
        });
      }

      // Load bought products data for the selected month
      int buyingCount = 0;
      int totalItemsBoughtThisMonth = 0;
      int totalQuantityBoughtThisMonth = 0;
      final purchasesSnapshot = await database.ref('purchases/$userId').get();

      if (purchasesSnapshot.exists) {
        final data = purchasesSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final purchaseData = Map<String, dynamic>.from(value);
            final purchaseDate = purchaseData['date'] as String? ?? '';
            
            // Check if purchase is from selected month
            if (_isFromSelectedMonth(purchaseDate)) {
              final totalAmount = purchaseData['totalAmount'] ?? 0;
              totalBuying += (totalAmount as num).toInt();
              buyingCount++;
              
              // Count total products in this purchase
              final totalProducts = purchaseData['totalProducts'] as num? ?? 0;
              totalItemsBoughtThisMonth += totalProducts.toInt();
              
              // Count total units/quantity in this purchase
              final totalUnits = purchaseData['totalUnits'] as num? ?? 0;
              totalQuantityBoughtThisMonth += totalUnits.toInt();
            }
          }
        });
      }

      // Calculate previous month data for comparison
      final prevMonth = DateTime(selectedDate.year, selectedDate.month - 1);
      int prevMonthSales = 0;
      int prevMonthBuying = 0;

      if (billsSnapshot.exists) {
        final data = billsSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final billData = Map<String, dynamic>.from(value);
            final billDate = billData['billDate'] as String? ?? '';
            final totalAmount = billData['totalAmount'] ?? 0;

            // Check if bill is from previous month
            if (_isFromMonth(billDate, prevMonth)) {
              prevMonthSales += (totalAmount as num).toInt();
            }
          }
        });
      }

      // Load previous month purchases
      if (purchasesSnapshot.exists) {
        final data = purchasesSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final purchaseData = Map<String, dynamic>.from(value);
            final purchaseDate = purchaseData['date'] as String? ?? '';
            
            // Check if purchase is from previous month
            if (_isFromMonth(purchaseDate, prevMonth)) {
              final totalAmount = purchaseData['totalAmount'] ?? 0;
              prevMonthBuying += (totalAmount as num).toInt();
            }
          }
        });
      }

      // Calculate percentage changes
      double salesPercentage = 0;
      double buyingPercentage = 0;
      
      if (prevMonthSales > 0) {
        salesPercentage = ((totalSales - prevMonthSales) / prevMonthSales) * 100;
      }
      
      if (prevMonthBuying > 0) {
        buyingPercentage = ((totalBuying - prevMonthBuying) / prevMonthBuying) * 100;
      }

      if (mounted) {
        setState(() {
          _totalSales = totalSales;
          _totalBuying = totalBuying;
          _totalProfitLoss = totalProfit;
          _totalSalesCount = salesCount;
          _totalItemsSold = itemsSold;
          _totalBuyingCount = buyingCount;
          _totalItemsBought = totalItemsBoughtThisMonth;
          _totalQuantityBought = totalQuantityBoughtThisMonth;
          _salesPercentageChange = salesPercentage;
          _buyingPercentageChange = buyingPercentage;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error calculating dashboard: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isFromSelectedMonth(String billDate) {
    try {
      // Expected format: "dd/MM/yyyy" (e.g., "18/11/2025")
      final parts = billDate.split('/');
      if (parts.length != 3) return false;

      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      return month == selectedDate.month && year == selectedDate.year;
    } catch (e) {
      print('Error parsing date "$billDate": $e');
      return false;
    }
  }

  bool _isFromMonth(String billDate, DateTime month) {
    try {
      // Expected format: "dd/MM/yyyy" (e.g., "18/11/2025")
      final parts = billDate.split('/');
      if (parts.length != 3) return false;

      final billMonth = int.parse(parts[1]);
      final billYear = int.parse(parts[2]);

      return billMonth == month.month && billYear == month.year;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                  ),
                ),
                IconButton(
                  onPressed: () => _showMonthPicker(context),
                  icon: const Icon(Icons.calendar_month),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _getMonthYear(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 34,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildDashboardCard(
                          title: 'Total Sales',
                          value: '₹ ${_formatCurrency(_totalSales)}',
                          subtitleTop: 'Bills: $_totalSalesCount',
                          subtitleBottom: 'Items Sold: $_totalItemsSold',
                          percentageText: '${_salesPercentageChange >= 0 ? '+' : ''}${_salesPercentageChange.toStringAsFixed(1)}% vs. last month',
                          isPositive: _salesPercentageChange >= 0,
                        ),
                        _buildDashboardCard(
                          title: 'Total Purchase',
                          value: '₹ ${_formatCurrency(_totalBuying)}',
                          subtitleTop: 'Purchases: $_totalBuyingCount',
                          subtitleMiddle: 'Products Bought: $_totalItemsBought',
                          subtitleBottom: 'Quantity Bought: $_totalQuantityBought',
                          percentageText: '${_buyingPercentageChange >= 0 ? '+' : ''}${_buyingPercentageChange.toStringAsFixed(1)}% vs. last month',
                          isPositive: _buyingPercentageChange >= 0,
                        ),
                        _buildDashboardCard(
                          title: 'Profit / Loss',
                          value: '₹ ${_formatCurrency(_totalProfitLoss)}',
                          percentageText: _totalProfitLoss >= 0 ? 'Profit' : 'Loss',
                          isPositive: _totalProfitLoss >= 0,
                        ),
                        const SizedBox(height: 80), // Space for FAB
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }

  void _showMonthPicker(BuildContext context) {
    int selectedYear = selectedDate.year;
    int selectedMonth = selectedDate.month;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Month & Year'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setStateDialog(() {
                              selectedYear--;
                            });
                          },
                        ),
                        Text(
                          selectedYear.toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setStateDialog(() {
                              selectedYear++;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Month Grid
                    GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () {
                            setStateDialog(() {
                              selectedMonth = index + 1;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: selectedMonth == index + 1
                                  ? Theme.of(context).primaryColor
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedMonth == index + 1
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                getMonthName(index + 1).substring(0, 3),
                                style: TextStyle(
                                  color: selectedMonth == index + 1
                                      ? Colors.white
                                      : null,
                                  fontWeight: selectedMonth == index + 1
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedDate = DateTime(selectedYear, selectedMonth, 1);
                  _isLoading = true;
                });
                Navigator.of(context).pop();
                _loadSalesReport();
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  String _getMonthYear() {
    return '${getMonthName(selectedDate.month)} ${selectedDate.year}';
  }

  // Helper widget for the dashboard cards
  Widget _buildDashboardCard({
    required String title,
    required String value,
    String? percentageText,
    String? subtitleTop,
    String? subtitleMiddle,
    String? subtitleBottom,
    required bool isPositive,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8.0),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12.0),
            if (subtitleTop != null && subtitleTop.isNotEmpty)
              Text(
                subtitleTop,
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            if (subtitleMiddle != null && subtitleMiddle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  subtitleMiddle,
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            if (subtitleBottom != null && subtitleBottom.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  subtitleBottom,
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            if (percentageText != null && percentageText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPositive ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      percentageText,
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
