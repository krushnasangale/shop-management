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
  String filterType = 'month'; // 'month', 'year', or 'day'
  bool _isLoading = true;
  int _totalSales = 0;
  int _totalBuying = 0;
  int _totalProfitLoss = 0;
  int _totalSalesCount = 0; // Number of bills/sales
  int _totalItemsSold = 0; // Total items sold
  int _totalBuyingCount = 0; // Number of purchase transactions
  int _totalItemsBought = 0; // Total items bought in selected month
  int _totalQuantityBought = 0;
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

    // Listen to purchase-history changes
    _purchasesSubscription = database.ref('purchase-history/$userId').onValue.listen((_) {
      _calculateAndUpdateDashboard(user.uid);
    });

    // Listen to purchased products changes (for inventory)
    _productsSubscription = database
        .ref('purchased-products/$userId')
        .onValue
        .listen((_) {
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
      
      // Try to get data from purchase-history first
      final purchasesSnapshot = await database.ref('purchase-history/$userId').get();

      if (purchasesSnapshot.exists) {
        final data = purchasesSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final purchaseData = Map<String, dynamic>.from(value);
            final purchaseDate = purchaseData['date'] as String? ?? '';

            // Check if purchase is from selected month
            if (_isFromSelectedMonth(purchaseDate)) {
              final amount = purchaseData['amount'] ?? 0;
              totalBuying += (amount as num).toInt();
              buyingCount++;

              // Count as 1 item (each purchase-history entry is 1 product purchase)
              totalItemsBoughtThisMonth += 1;

              // Get original quantity for this purchase
              final originalQuantity = purchaseData['originalQuantity'] as num? ?? 0;
              totalQuantityBoughtThisMonth += originalQuantity.toInt();
            }
          }
        });
      } else {
        // Fallback: Calculate from purchased-products if purchase-history doesn't exist
        final productsSnapshot = await database.ref('purchased-products/$userId').get();
        if (productsSnapshot.exists) {
          final data = productsSnapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            if (value is Map) {
              final productData = Map<String, dynamic>.from(value);
              final productDate = productData['date'] as String? ?? '';

              // Check if product purchase is from selected month
              if (_isFromSelectedMonth(productDate)) {
                final quantity = productData['quantity'] as num? ?? 0;
                final buyingPrice = productData['buyingPrice'] as num? ?? 0;
                final amount = (quantity * buyingPrice).toInt();
                
                totalBuying += amount;
                buyingCount++;
                totalItemsBoughtThisMonth += 1;
                totalQuantityBoughtThisMonth += quantity.toInt();
              }
            }
          });
        }
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

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      if (filterType == 'month') {
        return month == selectedDate.month && year == selectedDate.year;
      } else if (filterType == 'year') {
        return year == selectedDate.year;
      } else if (filterType == 'day') {
        return day == selectedDate.day &&
            month == selectedDate.month &&
            year == selectedDate.year;
      }
      return false;
    } catch (e) {
      print('Error parsing date "$billDate": $e');
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
                  _getMonthYear(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 30),
                ),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: filterType,
                      items: const [
                        DropdownMenuItem(value: 'day', child: Text('Day')),
                        DropdownMenuItem(value: 'month', child: Text('Month')),
                        DropdownMenuItem(value: 'year', child: Text('Year')),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            filterType = newValue;
                            _isLoading = true;
                          });
                          _loadSalesReport();
                        }
                      },
                    ),
                    IconButton(
                      onPressed: () => _showMonthPicker(context),
                      icon: const Icon(Icons.calendar_month),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Total Sales',
                                value: '₹ ${_formatCurrency(_totalSales)}',
                                subtitleTop: 'Bills: $_totalSalesCount',
                                subtitleBottom: 'Items Sold: $_totalItemsSold',
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDashboardCard(
                                title: 'Total Purchase',
                                value: '₹ ${_formatCurrency(_totalBuying)}',
                                subtitleTop: 'Purchases: $_totalBuyingCount',
                                subtitleMiddle: 'Products Bought: $_totalItemsBought',
                                subtitleBottom:
                                    'Quantity Bought: $_totalQuantityBought',
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDashboardCard(
                                title: _totalProfitLoss >= 0 ? 'Profit' : 'Loss',
                                value: '₹ ${_formatCurrency(_totalProfitLoss.abs())}',
                                valueColor: _totalProfitLoss >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
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
    // If day filter is selected, show calendar picker instead
    if (filterType == 'day') {
      showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      ).then((pickedDate) {
        if (pickedDate != null) {
          setState(() {
            selectedDate = pickedDate;
            _isLoading = true;
          });
          _loadSalesReport();
        }
      });
      return;
    }

    int selectedYear = selectedDate.year;
    int selectedMonth = selectedDate.month;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String dialogTitle = filterType == 'year'
            ? 'Select Year'
            : 'Select Month & Year';

        return AlertDialog(
          title: Text(dialogTitle),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year Selector (always shown)
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
                    // Only show month selector if not year filter
                    if (filterType != 'year') ...[
                      const SizedBox(height: 20),
                      // Month Grid
                      GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
    if (filterType == 'year') {
      return '${selectedDate.year}';
    } else if (filterType == 'day') {
      return '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
    } else {
      return '${getMonthName(selectedDate.month)} ${selectedDate.year}';
    }
  }

  // Helper widget for the dashboard cards
  Widget _buildDashboardCard({
    required String title,
    required String value,
    String? subtitleTop,
    String? subtitleMiddle,
    String? subtitleBottom,
    Color? valueColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: valueColor)),
            const SizedBox(height: 8.0),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 12.0),
            if (subtitleTop != null && subtitleTop.isNotEmpty)
              Text(
                subtitleTop,
                style: TextStyle(
                  color: Colors.green,
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
                    color: Colors.green,
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
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
