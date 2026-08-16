import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/expenses/add_expense_entry.dart';
import 'package:flashbill/pages/expenses/expense_details.dart';
import 'package:flashbill/pages/profile/my_profile.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/utils/search_utils.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flashbill/services/subscription_guard.dart';

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

    setState(() => _isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
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
    });
  }

  void _loadExpensesRealtime() {
    _streamSubscription = _expensesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
              final expenses = snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();

              setState(() {
                _expenses = expenses;
                _isLoading = false;
              });
            _filterExpenses();
          },
          onError: (error) {
            appLog('Error loading expenses: $error');
            if (mounted) setState(() => _isLoading = false);
          },
        );
  }

  void _filterExpenses() {
    final query = _searchController.text;
      setState(() {
      _filteredExpenses = query.isEmpty
          ? _expenses
          : _expenses.where((expense) {
          final category = (expense['category'] ?? '').toString();
          final description = (expense['description'] ?? '').toString();
          final amount = (expense['amount'] ?? '').toString();
          return SearchUtils.matchesSubsequence(category, query) ||
              SearchUtils.matchesSubsequence(description, query) ||
              SearchUtils.matchesSubsequence(amount, query);
        }).toList();
        _displayedItemCount = 50;
      _displayedExpenses = _filteredExpenses.take(_displayedItemCount).toList();
      });
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
    if (!_tabController.indexIsChanging) {
    setState(() {
      if (_tabController.index != 1) {
        _showSearchBar = false;
        _searchController.clear();
      }
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.myExpenses ?? 'My Expenses'),
        automaticallyImplyLeading: false,
        actions: [
          if (_tabController.index == 1)
            IconButton(
              style: Adaptive.compactIconButton,
              icon: Icon(
                _showSearchBar ? CupertinoIcons.xmark : CupertinoIcons.search,
                size: 28,
              ),
              tooltip: _showSearchBar
                  ? (loc?.closeSearch ?? 'Close Search')
                  : (loc?.search ?? 'Search'),
                          onPressed: () {
                setState(() {
                  _showSearchBar = !_showSearchBar;
                  if (!_showSearchBar) _searchController.clear();
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 32),
            tooltip: loc?.addExpense ?? 'Add Expense',
            onPressed: () {
              if (!SubscriptionGuard.ensureCanWrite(context)) return;
              AppNavigator.push(context, const AddExpenseEntry());
            },
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
              tooltip: loc?.myProfile ?? 'My Profile',
              onPressed: () => AppNavigator.push(context, const MyProfile()),
            ),
          ),
          const SizedBox(width: 14),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: loc?.dashboard ?? 'Dashboard'),
            Tab(text: loc?.recent ?? 'Recent'),
            Tab(text: loc?.byCategory ?? 'By Category'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: Adaptive.progress())
          : _expenses.isEmpty
          ? _EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              message: loc?.noExpensesYet ?? 'No expenses yet',
            )
          : TabBarView(
              controller: _tabController,
                                    children: [
                _OverviewTab(expenses: _expenses, loc: loc, scheme: scheme),
                _RecentTab(
                  loc: loc,
                  showSearchBar: _showSearchBar,
                  searchController: _searchController,
                  filteredExpenses: _filteredExpenses,
                  displayedExpenses: _displayedExpenses,
                  isLoadingMore: _isLoadingMore,
                  scrollController: _scrollController,
                ),
                _CategoryTab(expenses: _expenses, loc: loc, scheme: scheme),
              ],
            ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.expenses,
    required this.loc,
    required this.scheme,
  });

  final List<Map<String, dynamic>> expenses;
  final AppLocalizations? loc;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final totalAmount = expenses.fold<double>(
      0,
      (total, expense) => total + ((expense['amount'] ?? 0) as num).toDouble(),
    );

    final categoryTotals = <String, double>{};
    for (final expense in expenses) {
      final category = (expense['category'] ?? 'Other').toString();
      categoryTotals[category] =
          (categoryTotals[category] ?? 0) +
          ((expense['amount'] ?? 0) as num).toDouble();
    }
    final topCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final now = DateTime.now();
    final monthlyExpenses = <String, double>{};
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      monthlyExpenses['${month.year}-${month.month.toString().padLeft(2, '0')}'] =
          0;
    }
    for (final expense in expenses) {
      final dateStr = expense['date'] ?? '';
      if (dateStr.isEmpty) continue;
        try {
          final date = DateFormat('dd/MM/yyyy').parse(dateStr);
          final monthKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}';
          if (monthlyExpenses.containsKey(monthKey)) {
            monthlyExpenses[monthKey] =
                monthlyExpenses[monthKey]! +
              ((expense['amount'] ?? 0) as num).toDouble();
        }
      } catch (_) {}
    }

    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final thisMonth = monthlyExpenses[currentMonthKey] ?? 0;

    final methodTotals = <String, double>{};
    for (final expense in expenses) {
      final method = (expense['paymentMethod'] ?? 'cash').toString();
      methodTotals[method] =
          (methodTotals[method] ?? 0) +
          ((expense['amount'] ?? 0) as num).toDouble();
    }
    final methods = methodTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              _SummaryTile(
                icon: Icons.account_balance_wallet_outlined,
                label: loc?.totalExpenses ?? 'Total',
                value: '₹${_formatAmount(totalAmount)}',
              ),
              const SizedBox(width: 8),
              _SummaryTile(
                icon: Icons.calendar_month_outlined,
                label: loc?.thisMonth ?? 'This Month',
                value: '₹${_formatAmount(thisMonth)}',
                valueColor: scheme.error,
              ),
              const SizedBox(width: 8),
              _SummaryTile(
                icon: Icons.receipt_long_outlined,
                label: loc?.recent ?? 'Entries',
                value: '${expenses.length}',
              ),
            ],
          ),
        ),
        if (topCategories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _sectionLabel(
              context,
              loc?.topCategories ?? 'Top Categories',
            ),
          ),
          Adaptive.fullWidthGroup(
            context: context,
            bordered: true,
                              children: [
              for (final entry in topCategories.take(5))
                _InfoTile(
                  icon: _categoryIcon(entry.key),
                  title: _categoryLabel(entry.key, loc),
                  subtitle:
                      '${totalAmount > 0 ? (entry.value / totalAmount * 100).toStringAsFixed(1) : 0}%',
                  trailing: '₹${_formatAmount(entry.value)}',
                  trailingColor: scheme.error,
                                    ),
                                  ],
                                ),
          const SizedBox(height: 20),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _sectionLabel(
            context,
            loc?.monthlyTrendLast6Months ?? 'Monthly Trend',
          ),
        ),
        Adaptive.fullWidthGroup(
          context: context,
          bordered: true,
              children: [
            for (final entry in monthlyExpenses.entries)
              _InfoTile(
                icon: Icons.calendar_today_outlined,
                title: _monthName(entry.key),
                subtitle: '',
                trailing: '₹${_formatAmount(entry.value)}',
                trailingColor: entry.value > 0 ? scheme.error : null,
                    ),
                  ],
                ),
        if (methods.isNotEmpty) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _sectionLabel(
              context,
              loc?.paymentMethods ?? 'Payment Methods',
            ),
          ),
          Adaptive.fullWidthGroup(
            context: context,
            bordered: true,
                      children: [
              for (final method in methods)
                _InfoTile(
                  icon: _paymentIcon(method.key),
                  title: _paymentLabel(method.key, loc),
                  subtitle:
                      '${totalAmount > 0 ? (method.value / totalAmount * 100).toStringAsFixed(1) : 0}%',
                  trailing: '₹${_formatAmount(method.value)}',
                        ),
                      ],
                    ),
        ],
        if (expenses.isNotEmpty) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _sectionLabel(
              context,
              loc?.recentActivity ?? 'Recent Activity',
            ),
          ),
          Adaptive.fullWidthGroup(
            context: context,
            bordered: true,
                      children: [
              for (final expense in expenses.take(5))
                _ExpenseTile(
                  expense: expense,
                  onTap: () => AppNavigator.push(
                    context,
                    ExpenseDetails(expense: expense),
                                  ),
                            ),
                          ],
          ),
        ],
      ],
    );
  }
}

class _RecentTab extends StatelessWidget {
  const _RecentTab({
    required this.loc,
    required this.showSearchBar,
    required this.searchController,
    required this.filteredExpenses,
    required this.displayedExpenses,
    required this.isLoadingMore,
    required this.scrollController,
  });

  final AppLocalizations? loc;
  final bool showSearchBar;
  final TextEditingController searchController;
  final List<Map<String, dynamic>> filteredExpenses;
  final List<Map<String, dynamic>> displayedExpenses;
  final bool isLoadingMore;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
                      children: [
        if (showSearchBar)
          Adaptive.searchField(
            controller: searchController,
            query: searchController.text,
            hint:
                loc?.searchByCategoryOrAmount ?? 'Search by category or amount',
          ),
                        Expanded(
          child: filteredExpenses.isEmpty
              ? _EmptyState(
                  icon: Icons.search_off,
                  message:
                      loc?.noMatchingEntriesFound ??
                      'No matching entries found',
                )
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                            children: [
                    Adaptive.fullWidthGroup(
                      context: context,
                          children: [
                        for (final expense in displayedExpenses)
                          _ExpenseTile(
                            expense: expense,
                            onTap: () => AppNavigator.push(
                              context,
                              ExpenseDetails(expense: expense),
                              ),
                            ),
                          ],
                        ),
                    if (isLoadingMore)
                      Padding(
      padding: const EdgeInsets.all(16),
                        child: Center(child: Adaptive.progress()),
                      ),
                  ],
            ),
          ),
        ],
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.expenses,
    required this.loc,
    required this.scheme,
  });

  final List<Map<String, dynamic>> expenses;
  final AppLocalizations? loc;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final expense in expenses) {
      final category = (expense['category'] ?? 'Other').toString();
      grouped.putIfAbsent(category, () => []).add(expense);
    }

    final summaries =
        grouped.entries.map((entry) {
          final totalAmount = entry.value.fold<double>(
            0,
            (total, expense) =>
                total + ((expense['amount'] ?? 0) as num).toDouble(),
          );
          return {
            'category': entry.key,
            'totalAmount': totalAmount,
            'totalExpenses': entry.value.length,
            'lastExpenseDate': entry.value.isNotEmpty
                ? (entry.value.first['date'] ?? '')
                : '',
            'expenses': entry.value,
          };
        }).toList()..sort(
          (a, b) => (b['totalAmount'] as double).compareTo(
            a['totalAmount'] as double,
          ),
        );

    if (summaries.isEmpty) {
      return _EmptyState(
        icon: Icons.category_outlined,
        message: loc?.noExpensesYet ?? 'No expenses yet',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        children: [
        Adaptive.fullWidthGroup(
          context: context,
          children: [
            for (final summary in summaries)
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
                minVerticalPadding: 4,
                onTap: () => AppNavigator.push(
                  context,
                  CategoryExpensesPage(
                    category: summary['category'] as String,
                    expenses:
                        (summary['expenses'] as List<Map<String, dynamic>>),
                  ),
                ),
                leading: _squareIcon(
                  _categoryIcon(summary['category'] as String),
                  scheme,
                ),
        title: Text(
                  _categoryLabel(summary['category'] as String, loc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
            fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  '${summary['totalExpenses']}  ·  ${summary['lastExpenseDate']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
              children: [
                    Text(
                      '₹${_formatAmount(summary['totalAmount'] as double)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.error,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 24,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                      ),
                    ],
                  ),
      ],
    );
  }
}

class CategoryExpensesPage extends StatelessWidget {
  const CategoryExpensesPage({
    super.key,
    required this.category,
    required this.expenses,
  });

  final String category;
  final List<Map<String, dynamic>> expenses;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final totalAmount = expenses.fold<double>(
      0,
      (total, expense) => total + ((expense['amount'] ?? 0) as num).toDouble(),
    );
    final average = expenses.isEmpty ? 0.0 : totalAmount / expenses.length;

    return Scaffold(
      appBar: AppBar(title: Text(_categoryLabel(category, loc))),
      body: expenses.isEmpty
          ? _EmptyState(
              icon: Icons.category_outlined,
              message: loc?.noExpensesYet ?? 'No expenses in this category',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _SummaryTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: loc?.total ?? 'Total',
                        value: '₹${_formatAmount(totalAmount)}',
                        valueColor: scheme.error,
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        icon: Icons.trending_up,
                        label: loc?.average ?? 'Average',
                        value: '₹${_formatAmount(average)}',
                      ),
                      const SizedBox(width: 8),
                      _SummaryTile(
                        icon: Icons.receipt_long_outlined,
                        label: loc?.recent ?? 'Count',
                        value: '${expenses.length}',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _sectionLabel(context, loc?.recent ?? 'Expenses'),
                ),
                Adaptive.fullWidthGroup(
                  context: context,
                                  children: [
                    for (final expense in expenses)
                      _ExpenseTile(
                        expense: expense,
                        onTap: () => AppNavigator.push(
                          context,
                          ExpenseDetails(expense: expense),
                                      ),
                                    ),
                                  ],
                                ),
              ],
            ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.onTap});

  final Map<String, dynamic> expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final category = (expense['category'] ?? 'Other').toString();
    final date = (expense['date'] ?? '').toString();
    final description = (expense['description'] ?? '').toString();
    final amount = (expense['amount'] ?? 0) as num;
    final method = (expense['paymentMethod'] ?? 'cash').toString();

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
      minVerticalPadding: 4,
      onTap: onTap,
      leading: _squareIcon(_categoryIcon(category), scheme),
      title: Text(
        description.isNotEmpty ? description : _categoryLabel(category, loc),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: Text(
        [
          if (description.isNotEmpty) _categoryLabel(category, loc),
          date,
          _paymentLabel(method, loc),
        ].join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
                              children: [
          Text(
            '₹${_formatAmount(amount)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: scheme.error),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 24,
            color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.trailingColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      minVerticalPadding: 4,
      leading: _squareIcon(icon, scheme),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Text(
        trailing,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: trailingColor ?? scheme.onSurface,
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Adaptive.box(
        context: context,
        margin: EdgeInsets.zero,
                          child: Padding(
          padding: const EdgeInsets.all(12),
                                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
              _squareIcon(icon, scheme),
              const SizedBox(height: 8),
                                      Text(
                label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
                                          Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? scheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _squareIcon(icon, scheme),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
                          ),
                        ),
                      );
  }
}

Widget _sectionLabel(BuildContext context, String title) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: scheme.onSurfaceVariant,
      ),
            ),
    );
  }

Widget _squareIcon(IconData icon, ColorScheme scheme) {
  return ClipRRect(
            borderRadius: BorderRadius.circular(8),
    child: ColoredBox(
      color: scheme.primaryContainer,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
      ),
    ),
  );
}

String _formatAmount(num amount) {
  if (amount == amount.roundToDouble()) return amount.toInt().toString();
  return amount.toStringAsFixed(2);
}

String _monthName(String monthKey) {
  final parts = monthKey.split('-');
  final month = int.parse(parts[1]);
  const names = [
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
  return '${names[month - 1]} ${parts[0]}';
}

IconData _categoryIcon(String category) {
  final value = category.toLowerCase();
  if (value.contains('food') || value.contains('restaurant')) {
    return Icons.restaurant_outlined;
  }
  if (value.contains('transport') || value.contains('travel')) {
    return Icons.directions_car_outlined;
  }
  if (value.contains('shop') || value.contains('clothes')) {
    return Icons.shopping_bag_outlined;
  }
  if (value.contains('office')) return Icons.business_outlined;
  if (value.contains('hospital') || value.contains('health')) {
    return Icons.local_hospital_outlined;
  }
  if (value.contains('utility') || value.contains('electric')) {
    return Icons.electrical_services_outlined;
  }
  if (value.contains('rent') || value.contains('home')) {
    return Icons.home_outlined;
  }
  return Icons.category_outlined;
}

IconData _paymentIcon(String method) {
  switch (method.toLowerCase()) {
    case 'online':
      return Icons.qr_code_outlined;
    case 'card':
      return Icons.credit_card_outlined;
      default:
      return Icons.payments_outlined;
  }
}

String _paymentLabel(String method, AppLocalizations? loc) {
  switch (method.toLowerCase()) {
    case 'online':
      return loc?.online ?? 'Online';
    case 'card':
      return loc?.card ?? 'Card';
    default:
      return loc?.cash ?? 'Cash';
  }
}

String _categoryLabel(String category, AppLocalizations? loc) {
  switch (category) {
    case 'Office':
      return loc?.office ?? category;
    case 'Travel':
      return loc?.travel ?? category;
    case 'Utilities':
      return loc?.utilities ?? category;
    case 'Food':
      return loc?.food ?? category;
    case 'Hospital':
      return loc?.hospital ?? category;
    case 'Other':
      return loc?.other ?? category;
    default:
      return category;
  }
}
