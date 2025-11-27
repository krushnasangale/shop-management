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
      int totalQuantityBoughtThisMonth = 0;
      
      // Try to get data from purchases (purchase entry headers)
      final purchasesSnapshot = await database.ref('purchases/$userId').get();

      if (purchasesSnapshot.exists) {
        final data = purchasesSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final purchaseData = Map<String, dynamic>.from(value);
            final purchaseDate = purchaseData['date'] as String? ?? '';

            // Check if purchase is from selected month
            if (_isFromSelectedMonth(purchaseDate)) {
              final amount = purchaseData['totalAmount'] ?? 0;
              totalBuying += (amount as num).toInt();
              buyingCount++;

              // Get total units for this purchase
              final totalUnits = purchaseData['totalUnits'] as num? ?? 0;
              totalQuantityBoughtThisMonth += totalUnits.toInt();
            }
          }
        });
      } else {
        // Fallback: Calculate from purchased-products if purchases doesn't exist
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
                totalQuantityBoughtThisMonth += quantity.toInt();
              }
            }
          });
          
          // Count distinct purchases from the products
          final purchasesFromProducts = <String>{};
          data.forEach((key, value) {
            if (value is Map) {
              final productData = Map<String, dynamic>.from(value);
              final productDate = productData['date'] as String? ?? '';
              if (_isFromSelectedMonth(productDate)) {
                final purchaseId = productData['purchaseId'] as String?;
                if (purchaseId != null) {
                  purchasesFromProducts.add(purchaseId);
                }
              }
            }
          });
          buyingCount = purchasesFromProducts.length;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.blue.withOpacity(0.6) : Colors.blue.withOpacity(0.3),
                                width: isDark ? 1.2 : 1,
                              ),
                            ),
                            child: Text(
                              _getMonthYear(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.blue[300] : Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[750] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.grey[600]! : Colors.transparent,
                                width: isDark ? 1 : 0,
                              ),
                            ),
                            child: PopupMenuButton<String>(
                              offset: const Offset(0, 40),
                              itemBuilder: (BuildContext context) => [
                                PopupMenuItem(
                                  value: 'day',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 18),
                                      const SizedBox(width: 8),
                                      const Text('Day'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'month',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month, size: 18),
                                      const SizedBox(width: 8),
                                      const Text('Month'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'year',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month, size: 18),
                                      const SizedBox(width: 8),
                                      const Text('Year'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (String newValue) {
                                setState(() {
                                  filterType = newValue;
                                  _isLoading = true;
                                });
                                _loadSalesReport();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.filter_list, color: Colors.blue[600], size: 20),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_drop_down, color: Colors.blue[600], size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: IconButton(
                              icon: Icon(Icons.calendar_today, color: Colors.blue[600], size: 22),
                              onPressed: () => _showMonthPicker(context),
                              style: IconButton.styleFrom(
                                backgroundColor: isDark ? Colors.grey[750] : Colors.grey[100],
                                side: isDark ? BorderSide(color: Colors.grey[600]!, width: 1) : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: Column(
                        children: [
                          // Two Column Layout
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernCard(
                                  title: 'Total Sales',
                                  value: '₹${_formatCurrency(_totalSales)}',
                                  subtitle: 'Bills: $_totalSalesCount • Items: $_totalItemsSold',
                                  backgroundColor: Colors.blue.withOpacity(0.1),
                                  textColor: Colors.blue[700]!,
                                  icon: Icons.trending_up,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModernCard(
                                  title: 'Total Purchase',
                                  value: '₹${_formatCurrency(_totalBuying)}',
                                  subtitle: 'Orders: $_totalBuyingCount • Qty: $_totalQuantityBought',
                                  backgroundColor: Colors.orange.withOpacity(0.1),
                                  textColor: Colors.orange[700]!,
                                  icon: Icons.shopping_bag,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Profit/Loss Card
                          _buildProfitLossCard(),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required String value,
    required String subtitle,
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? textColor.withOpacity(0.4) : textColor.withOpacity(0.2),
          width: isDark ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? textColor.withOpacity(0.15) : textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitLossCard() {
    final isProfitable = _totalProfitLoss >= 0;
    final bgColor = isProfitable ? Colors.green : Colors.red;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? bgColor.withOpacity(0.4) : bgColor.withOpacity(0.2),
          width: isDark ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isProfitable ? 'Profit' : 'Loss',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${_formatCurrency(_totalProfitLoss.abs())}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: bgColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? bgColor.withOpacity(0.15) : bgColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isProfitable ? Icons.trending_up : Icons.trending_down,
              size: 28,
              color: bgColor,
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
}
