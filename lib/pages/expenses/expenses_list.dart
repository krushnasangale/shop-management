import 'dart:async';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flashbill/pages/expenses/expense_details.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:flashbill/utils/app_logger.dart';

class ExpensesList extends StatefulWidget {
  const ExpensesList({super.key});

  @override
  State<ExpensesList> createState() => _ExpensesListState();
}

class _ExpensesListState extends State<ExpensesList>
    with SingleTickerProviderStateMixin {
  late CollectionReference _expensesRef;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _filteredExpenses = [];
  List<Map<String, dynamic>> _displayedExpenses = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  late TextEditingController _searchController;
  bool _showSearchBar = false;
  final ScrollController _scrollController = ScrollController();
  int _displayedItemCount = 50;
  bool _isLoadingMore = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController = TextEditingController();
    _searchController.addListener(_filterExpenses);
    _scrollController.addListener(_onScroll);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _expensesRef = FirebaseFirestore.instance
          .collection('expenses')
          .doc(user.uid)
          .collection('entries');
      _loadExpensesRealtime();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore || _displayedItemCount >= _filteredExpenses.length) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _displayedItemCount = (_displayedItemCount + 50).clamp(
            0,
            _filteredExpenses.length,
          );
          _displayedExpenses = _filteredExpenses
              .take(_displayedItemCount)
              .toList();
          _isLoadingMore = false;
        });
      }
    });
  }

  void _loadExpensesRealtime() {
    _streamSubscription = _expensesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              final expenses = snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();

              setState(() {
                _expenses = expenses;
                _filteredExpenses = expenses;
                _displayedItemCount = 50;
                _displayedExpenses = expenses
                    .take(_displayedItemCount)
                    .toList();
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            appLog('Error loading expenses: $error');
            setState(() {
              _isLoading = false;
            });
          },
        );
  }

  void _filterExpenses() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _filteredExpenses = _expenses;
        _displayedItemCount = 50;
        _displayedExpenses = _filteredExpenses
            .take(_displayedItemCount)
            .toList();
      });
    } else {
      setState(() {
        _filteredExpenses = _expenses.where((expense) {
          final category = (expense['category'] ?? '').toString();
          final description = (expense['description'] ?? '').toString();
          final amount = (expense['amount'] ?? '').toString();
          return SearchUtils.matchesSubsequence(category, query) ||
              SearchUtils.matchesSubsequence(description, query) ||
              SearchUtils.matchesSubsequence(amount, query);
        }).toList();
        _displayedItemCount = 50;
        _displayedExpenses = _filteredExpenses
            .take(_displayedItemCount)
            .toList();
      });
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _tabController.removeListener(_onTabChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      // Hide search bar when not on Recent tab (index 1)
      if (_tabController.index != 1) {
        _showSearchBar = false;
        _searchController.clear();
      }
    });
  }

  Widget _buildRecentExpensesTab() {
    return Column(
      children: [
        // Search Bar
        if (_showSearchBar)
          Padding(
            padding: const EdgeInsets.only(
              left: 12.0,
              right: 12.0,
              top: 5,
              bottom: 2,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 0,
                    offset: const Offset(0, 0),
                    spreadRadius: 1,
                  ),
                ],
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.white.withValues(alpha: 0.95)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      AppLocalizations.of(context)?.searchByCategoryOrAmount ??
                      'Search by category or amount',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: false,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        // List
        Expanded(
          child: _filteredExpenses.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)?.noMatchingEntriesFound ??
                        'No matching entries found',
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount:
                      _displayedExpenses.length + (_isLoadingMore ? 1 : 0),
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                  itemBuilder: (context, index) {
                    if (index == _displayedExpenses.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final expense = _displayedExpenses[index];
                    final date = expense['date'] ?? 'N/A';
                    final category = expense['category'] ?? 'Other';
                    final amount = expense['amount'] ?? 0.0;
                    final description = expense['description'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          width: 1,
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 0,
                            offset: const Offset(0, 0),
                            spreadRadius: 1,
                          ),
                        ],
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withValues(alpha: 0.95),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ExpenseDetails(expense: expense),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row
                              Row(
                                children: [
                                  // Category Icon
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(
                                        category,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(category),
                                      color: _getCategoryColor(category),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          date,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.red.shade400,
                                          Colors.red.shade600,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '₹${amount == amount.toInt() ? amount.toInt() : amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.description,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryExpensesTab() {
    // Group expenses by category
    Map<String, List<Map<String, dynamic>>> categoryExpenses = {};
    for (var expense in _expenses) {
      final category = expense['category'] ?? 'Other';
      if (!categoryExpenses.containsKey(category)) {
        categoryExpenses[category] = [];
      }
      categoryExpenses[category]!.add(expense);
    }

    // Create category summaries
    final categorySummaries = categoryExpenses.entries.map((entry) {
      final category = entry.key;
      final expenses = entry.value;
      final totalAmount = expenses.fold<double>(
        0,
        (total, expense) => total + ((expense['amount'] ?? 0) as num).toDouble(),
      );
      final totalExpenses = expenses.length;
      final lastExpenseDate = expenses.isNotEmpty
          ? expenses[0]['date'] ?? ''
          : '';

      return {
        'category': category,
        'totalAmount': totalAmount,
        'totalExpenses': totalExpenses,
        'lastExpenseDate': lastExpenseDate,
        'expenses': expenses,
      };
    }).toList();

    // Sort by total amount descending
    categorySummaries.sort(
      (a, b) =>
          (b['totalAmount'] as double).compareTo(a['totalAmount'] as double),
    );

    return categorySummaries.isEmpty
        ? Center(
            child: Text(
              AppLocalizations.of(context)?.noExpensesYet ?? 'No expenses yet',
            ),
          )
        : ListView.builder(
            itemCount: categorySummaries.length,
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            itemBuilder: (context, index) {
              final summary = categorySummaries[index];
              final category = summary['category'] ?? 'Other';
              final totalAmount = summary['totalAmount'] ?? 0.0;
              final totalExpenses = summary['totalExpenses'] ?? 0;
              final lastExpenseDate = summary['lastExpenseDate'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    width: 1,
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 0,
                      offset: const Offset(0, 0),
                      spreadRadius: 1,
                    ),
                  ],
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.white.withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // Navigate to category-specific expense list
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryExpensesPage(
                          category: category,
                          expenses: summary['expenses'] ?? [],
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(
                                      category,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(category),
                                    color: _getCategoryColor(category),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category,
                                      style: context.bodyLargeText?.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Last: $lastExpenseDate',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '₹${totalAmount == totalAmount.toInt() ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.receipt,
                                    size: 12,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$totalExpenses Expenses',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.category,
                                    size: 12,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Category',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildDashboardTab() {
    // Calculate dashboard statistics
    final totalExpenses = _expenses.length;
    final totalAmount = _expenses.fold<double>(
      0,
      (total, expense) => total + ((expense['amount'] ?? 0) as num).toDouble(),
    );

    // Group by categories for pie chart data
    Map<String, double> categoryTotals = {};
    for (var expense in _expenses) {
      final category = expense['category'] ?? 'Other';
      final amount = (expense['amount'] ?? 0) as num;
      categoryTotals[category] =
          (categoryTotals[category] ?? 0) + amount.toDouble();
    }

    // Get top categories
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(5).toList();

    // Calculate monthly trend (last 6 months)
    final now = DateTime.now();
    Map<String, double> monthlyExpenses = {};
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey =
          '${month.year}-${month.month.toString().padLeft(2, '0')}';
      monthlyExpenses[monthKey] = 0;
    }

    for (var expense in _expenses) {
      final dateStr = expense['date'] ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final date = DateFormat('dd/MM/yyyy').parse(dateStr);
          final monthKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}';
          if (monthlyExpenses.containsKey(monthKey)) {
            monthlyExpenses[monthKey] =
                monthlyExpenses[monthKey]! +
                (expense['amount'] ?? 0).toDouble();
          }
        } catch (e) {
          // Skip invalid dates
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title:
                      AppLocalizations.of(context)?.totalExpenses ??
                      'Total Expenses',
                  value: '₹${totalAmount.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet,
                  color: Colors.blue,
                  subtitle: '$totalExpenses entries',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  title:
                      AppLocalizations.of(context)?.thisMonth ?? 'This Month',
                  value: _getCurrentMonthTotal(monthlyExpenses),
                  icon: Icons.calendar_month,
                  color: Colors.orange,
                  subtitle: _getMonthComparison(
                    monthlyExpenses,
                    AppLocalizations.of(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Top Categories
          ...(topCategories.isNotEmpty
              ? [
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.pie_chart,
                                color: Colors.purple,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.of(context)?.topCategories ??
                                  'Top Categories',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...topCategories.map((entry) {
                          final percentage = totalAmount > 0
                              ? (entry.value / totalAmount * 100)
                              : 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${entry.value.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ]
              : []),

          const SizedBox(height: 12),

          // Monthly Trend
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: Colors.blue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)?.monthlyTrendLast6Months ??
                          'Monthly Trend (Last 6 Months)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...monthlyExpenses.entries.map((entry) {
                  final monthName = _getMonthName(entry.key);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text(
                            monthName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: totalAmount > 0
                                ? entry.value / totalAmount
                                : 0,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              entry.value > 0
                                  ? Colors.red.shade400
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 70,
                          child: Text(
                            '₹${entry.value.toStringAsFixed(0)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Payment Methods
          ...(_getPaymentMethodBreakdown().isNotEmpty
              ? [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.payment,
                                color: Colors.indigo,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)?.paymentMethods ??
                                  'Payment Methods',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._getPaymentMethodBreakdown().map((method) {
                          final percentage = totalAmount > 0
                              ? (method['amount'] / totalAmount * 100)
                              : 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _getPaymentMethodColor(
                                      method['method'],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    method['method'].toString().toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${method['amount'].toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ]
              : []),

          // Recent Activity
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.history,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)?.recentActivity ??
                          'Recent Activity',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._expenses.take(5).map((expense) {
                  final date = expense['date'] ?? 'N/A';
                  final category = expense['category'] ?? 'Other';
                  final amount = expense['amount'] ?? 0.0;
                  final description = expense['description'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(category),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _getCategoryColor(
                                  category,
                                ).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              date,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[category.hashCode % colors.length];
  }

  IconData _getCategoryIcon(String category) {
    final categoryLower = category.toLowerCase();
    if (categoryLower.contains('food') ||
        categoryLower.contains('restaurant')) {
      return Icons.restaurant;
    } else if (categoryLower.contains('transport') ||
        categoryLower.contains('travel')) {
      return Icons.directions_car;
    } else if (categoryLower.contains('shopping') ||
        categoryLower.contains('clothes')) {
      return Icons.shopping_bag;
    } else if (categoryLower.contains('entertainment') ||
        categoryLower.contains('movie')) {
      return Icons.movie;
    } else if (categoryLower.contains('health') ||
        categoryLower.contains('medical')) {
      return Icons.local_hospital;
    } else if (categoryLower.contains('education') ||
        categoryLower.contains('book')) {
      return Icons.school;
    } else if (categoryLower.contains('utility') ||
        categoryLower.contains('electricity')) {
      return Icons.electrical_services;
    } else if (categoryLower.contains('rent') ||
        categoryLower.contains('home')) {
      return Icons.home;
    } else {
      return Icons.category;
    }
  }

  String _getMonthName(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[month - 1]} $year';
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations?.myExpenses ?? 'My Expenses',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withValues(alpha: 0.95),
                Theme.of(context).primaryColor.withValues(alpha: 0.85),
                Theme.of(context).primaryColor.withValues(alpha: 0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        actions: [
          // Only show search icon when on Recent tab (index 1)
          if (_tabController.index == 1)
            IconButton(
              icon: Icon(
                _showSearchBar ? Icons.close : Icons.search,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _showSearchBar = !_showSearchBar;
                  if (!_showSearchBar) {
                    _searchController.clear();
                  }
                });
              },
              tooltip: _showSearchBar ? 'Close Search' : 'Search',
            ),
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
              onPressed: () async {
                AppNavigator.push(context, const MyProfile());
              },
              tooltip: localizations?.myProfile,
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
          ? Center(
              child: Text(localizations?.noExpensesYet ?? 'No expenses yet'),
            )
          : Column(
              children: [
                // Modern animated toggle buttons
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  width: screenWidth - 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ToggleButtons(
                    isSelected: [
                      _tabController.index == 0,
                      _tabController.index == 1,
                      _tabController.index == 2,
                    ],
                    onPressed: (index) {
                      setState(() {
                        _tabController.animateTo(index);
                      });
                    },
                    borderRadius: BorderRadius.circular(14.0),
                    selectedColor: Colors.white,
                    fillColor: Theme.of(context).primaryColor,
                    color: Colors.grey.shade600,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                    constraints: BoxConstraints(
                      minHeight: 44.0,
                      minWidth: (screenWidth - 20) / 3,
                    ),
                    borderWidth: 0,
                    selectedBorderColor: Colors.transparent,
                    children: [
                      _buildToggleButton(
                        icon: Icons.dashboard,
                        label: localizations?.dashboard ?? 'Dashboard',
                        isSelected: _tabController.index == 0,
                      ),
                      _buildToggleButton(
                        icon: Icons.access_time,
                        label: localizations?.recent ?? 'Recent',
                        isSelected: _tabController.index == 1,
                      ),
                      _buildToggleButton(
                        icon: Icons.category,
                        label: localizations?.byCategory ?? 'By Category',
                        isSelected: _tabController.index == 2,
                      ),
                    ],
                  ),
                ),
                // Tab Bar View
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDashboardTab(),
                      _buildRecentExpensesTab(),
                      _buildCategoryExpensesTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _getCurrentMonthTotal(Map<String, double> monthlyExpenses) {
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final amount = monthlyExpenses[currentMonthKey] ?? 0;
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _getMonthComparison(
    Map<String, double> monthlyExpenses,
    AppLocalizations? localizations,
  ) {
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastMonthKey =
        '${now.year}-${(now.month - 1).toString().padLeft(2, '0')}';

    final currentAmount = monthlyExpenses[currentMonthKey] ?? 0;
    final lastAmount = monthlyExpenses[lastMonthKey] ?? 0;

    if (lastAmount == 0) {
      return localizations?.vsLastMonth ?? 'vs last month';
    }

    final difference = currentAmount - lastAmount;
    final percentChange = (difference / lastAmount * 100).abs();

    if (difference > 0) {
      return '+${percentChange.toStringAsFixed(0)}${localizations?.vsLast ?? '% vs last'}';
    } else if (difference < 0) {
      return '-${percentChange.toStringAsFixed(0)}${localizations?.vsLast ?? '% vs last'}';
    } else {
      return localizations?.sameAsLast ?? 'Same as last';
    }
  }

  List<Map<String, dynamic>> _getPaymentMethodBreakdown() {
    Map<String, double> methodTotals = {};
    for (var expense in _expenses) {
      final method = expense['paymentMethod'] ?? 'cash';
      final amount = (expense['amount'] ?? 0) as num;
      methodTotals[method] = (methodTotals[method] ?? 0) + amount.toDouble();
    }

    return methodTotals.entries
        .map((entry) => {'method': entry.key, 'amount': entry.value})
        .toList()
      ..sort((a, b) {
        final aAmount = a['amount'] as double? ?? 0;
        final bAmount = b['amount'] as double? ?? 0;
        return bAmount.compareTo(aAmount);
      });
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'upi':
        return Colors.purple;
      case 'netbanking':
        return Colors.orange;
      case 'wallet':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

// Placeholder for category expenses page
class CategoryExpensesPage extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> expenses;

  const CategoryExpensesPage({
    super.key,
    required this.category,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // Calculate category statistics
    final totalAmount = expenses.fold<double>(
      0,
      (double total, expense) =>
          total + ((expense['amount'] ?? 0) as num).toDouble(),
    );
    final totalExpenses = expenses.length;
    final averageAmount = totalExpenses > 0 ? totalAmount / totalExpenses : 0.0;
    final highestExpense = expenses.isNotEmpty
        ? expenses
              .map((e) => (e['amount'] ?? 0) as num)
              .reduce((a, b) => a > b ? a : b)
              .toDouble()
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('$category Expenses'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: expenses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations?.noExpensesYet ??
                        'No expenses in this category',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Category Summary Card - Different Design
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    elevation: 8,
                    shadowColor: const Color(0xFF667eea).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [Colors.white, const Color(0xFFF8F9FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Category Header with Icon
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF667eea,
                                      ).withValues(alpha: 0.3),
                                      spreadRadius: 2,
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _getCategoryIcon(category),
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D3748),
                                      ),
                                    ),
                                    Text(
                                      '$totalExpenses ${totalExpenses == 1 ? 'expense' : 'expenses'}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Total Amount Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF667eea,
                                      ).withValues(alpha: 0.3),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '₹${totalAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Statistics Row
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildCompactStat(
                                  'Average',
                                  '₹${averageAmount.toStringAsFixed(0)}',
                                  Icons.trending_up,
                                  const Color(0xFF48BB78),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey[300],
                                ),
                                _buildCompactStat(
                                  'Highest',
                                  '₹${highestExpense.toStringAsFixed(0)}',
                                  Icons.arrow_upward,
                                  const Color(0xFFED8936),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey[300],
                                ),
                                _buildCompactStat(
                                  'Count',
                                  '$totalExpenses',
                                  Icons.receipt_long,
                                  const Color(0xFF667eea),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Expenses List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      final date = expense['date'] ?? 'N/A';
                      final amount = expense['amount'] ?? 0.0;
                      final description = expense['description'] ?? '';
                      final paymentMethod = expense['paymentMethod'] ?? 'cash';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ExpenseDetails(expense: expense),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Amount Circle
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF667eea),
                                        Color(0xFF764ba2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '₹${amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Expense Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        description.isNotEmpty
                                            ? description
                                            : 'No description',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            date,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(
                                            paymentMethod.toLowerCase() ==
                                                    'cash'
                                                ? Icons.money
                                                : paymentMethod.toLowerCase() ==
                                                      'card'
                                                ? Icons.credit_card
                                                : Icons.account_balance_wallet,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            paymentMethod,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Arrow Icon
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCompactStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'restaurant':
        return Icons.restaurant;
      case 'transport':
      case 'travel':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'health':
      case 'medical':
        return Icons.local_hospital;
      case 'education':
        return Icons.school;
      case 'utilities':
        return Icons.electrical_services;
      case 'rent':
      case 'housing':
        return Icons.home;
      case 'salary':
      case 'income':
        return Icons.attach_money;
      default:
        return Icons.category;
    }
  }
}
