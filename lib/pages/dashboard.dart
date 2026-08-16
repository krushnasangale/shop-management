import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flashbill/pages/helpers/utils.dart';
import 'package:flashbill/pages/billing/view_existing_bill_details.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/pending_payments_page.dart';
import 'package:flashbill/pages/previous_due_payments_page.dart';
import 'package:flashbill/pages/order_now_page.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flashbill/services/dashboard_service.dart';
import 'package:flashbill/widgets/app_context_menu.dart';
import 'package:flashbill/widgets/dashboard_widgets.dart';
import 'package:flashbill/services/notification_service.dart';
import 'package:flashbill/services/subscription_guard.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/app_logger.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  DateTime selectedDate = DateTime.now();
  String filterType = 'month';
  DateTime? _rangeStartDate;
  DateTime? _rangeEndDate;

  // Services
  late final DashboardService _dashboardService;

  // Single source of truth for all dashboard data
  DashboardData? _dashboardData;
  bool _isLoading = true;

  // UI Expansion states
  bool _expandTopProducts = false;
  bool _expandLeastProducts = false;
  bool _expandPendingPayments = false;
  bool _expandUpcomingPayments = false;
  bool _expandOrderNow = false;
  bool _expandPreviousDue = false;

  // Tab Controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _dashboardService = DashboardService();
    _loadFilterPreference();

    // Request notification permission after dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().requestPermission();
    });
  }

  @override
  void dispose() {
    _dashboardSubscription?.cancel();
    _tabController.dispose();
    _dashboardService.dispose();
    super.dispose();
  }

  Future<void> _loadFilterPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFilterType = prefs.getString('dashboard_filter_type');
    if (savedFilterType != null) {
      setState(() {
        filterType = savedFilterType;
        if (savedFilterType == 'range') {
          final startDateStr = prefs.getString('dashboard_range_start');
          final endDateStr = prefs.getString('dashboard_range_end');
          if (startDateStr != null && endDateStr != null) {
            _rangeStartDate = DateTime.parse(startDateStr);
            _rangeEndDate = DateTime.parse(endDateStr);
          }
        }
      });
    }
    _initializeDashboardData();
  }

  Future<void> _saveFilterPreference(String filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_filter_type', filter);
    if (filter == 'range' && _rangeStartDate != null && _rangeEndDate != null) {
      await prefs.setString(
        'dashboard_range_start',
        _rangeStartDate!.toIso8601String(),
      );
      await prefs.setString(
        'dashboard_range_end',
        _rangeEndDate!.toIso8601String(),
      );
    }
  }

  StreamSubscription<DashboardData>? _dashboardSubscription;

  void _initializeDashboardData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Initialize services
    _dashboardService.initialize(user.uid);

    // Listen to dashboard data updates with current filter settings
    _updateDashboardSubscription();
  }

  void _updateDashboardSubscription() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Only set loading state if no cached data is available
    final hasCachedData = _dashboardService.billsService
        .getCachedBills()
        .isNotEmpty;
    if (!hasCachedData) {
      setState(() => _isLoading = true);
    }

    // Cancel existing subscription
    _dashboardSubscription?.cancel();

    // Create new subscription with current filter settings
    _dashboardSubscription = _dashboardService
        .getDashboardStream(
          user.uid,
          filterType: filterType,
          selectedDate: selectedDate,
          rangeStartDate: _rangeStartDate,
          rangeEndDate: _rangeEndDate,
        )
        .listen(
          (dashboardData) {
            if (mounted) {
              setState(() {
                _dashboardData = dashboardData;
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            appLog('Dashboard data error: $error');
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        );
  }

  Widget _buildTopSellingProductsCard(AppLocalizations? loc) {
    // Sort products by quantity sold descending and take top 5
    final topProducts =
        (_dashboardData?.topSellingProducts ?? [])
            .map((product) => Map<String, dynamic>.from(product))
            .toList()
          ..sort(
            (a, b) => (b['quantity'] as num).compareTo(a['quantity'] as num),
          );
    final displayProducts = topProducts.take(5).toList();

    return ExpandableCard(
      title: loc?.topSellingProducts ?? 'Top Selling Products',
      themeColor: Colors.purple,
      badgeText: '${displayProducts.length}',
      grouped: true,
      showDivider: true,
      initiallyExpanded: _expandTopProducts,
      onExpansionChanged: () =>
          setState(() => _expandTopProducts = !_expandTopProducts),
      loc: loc,
      expandedContent: Padding(
        padding: const EdgeInsets.all(16),
        child: displayProducts.isEmpty
            ? Center(
                child: Text(
                  loc?.noSalesDataYet ?? 'No sales data yet',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayProducts.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 0, endIndent: 0),
                itemBuilder: (context, index) {
                  final product = displayProducts[index];
                  final profit = (product['totalProfit'] as num?)?.toInt() ?? 0;
                  return ProductListItem(
                    index: index,
                    name: product['name'],
                    quantity: product['quantity'] as int,
                    revenue: product['revenue'] as int,
                    profit: profit,
                    loc: loc,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLeastSellingProductsCard(AppLocalizations? loc) {
    // Get least selling products by sorting in ascending order (lowest quantities first)
    final leastProducts =
        (_dashboardData?.topSellingProducts ?? [])
            .map((product) => Map<String, dynamic>.from(product))
            .toList()
          ..sort(
            (a, b) => (a['quantity'] as num).compareTo(b['quantity'] as num),
          );
    final displayProducts = leastProducts.take(5).toList();

    return ExpandableCard(
      title: loc?.leastSellingProducts ?? 'Least Selling Products',
      themeColor: Colors.red,
      badgeText: '${displayProducts.length}',
      grouped: true,
      showDivider: true,
      initiallyExpanded: _expandLeastProducts,
      onExpansionChanged: () =>
          setState(() => _expandLeastProducts = !_expandLeastProducts),
      loc: loc,
      expandedContent: Padding(
        padding: const EdgeInsets.all(16),
        child: displayProducts.isEmpty
            ? Center(
                child: Text(
                  loc?.noSalesDataYet ?? 'No sales data yet',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayProducts.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final product = displayProducts[index];
                  final profit = (product['totalProfit'] as num?)?.toInt() ?? 0;
                  return ProductListItem(
                    index: index,
                    name: product['name'],
                    quantity: product['quantity'] as int,
                    revenue: product['revenue'] as int,
                    profit: profit,
                    loc: loc,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPendingPaymentsCard(AppLocalizations? loc) {
    return ExpandableCard(
      title: loc?.pendingPayments ?? 'Pending Payments',
      themeColor: Colors.orange,
      badgeText:
          '₹${_formatCurrency(_dashboardData?.pendingPayments.totalAmount ?? 0, loc: AppLocalizations.of(context))}',
      grouped: true,
      showDivider: true,
      initiallyExpanded: _expandPendingPayments,
      onExpansionChanged: () =>
          setState(() => _expandPendingPayments = !_expandPendingPayments),
      loc: loc,
      expandedContent: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: (_dashboardData?.pendingPayments.payments.isEmpty ?? true)
                ? Center(
                    child: Text(
                      loc?.noPendingPayments ?? 'No pending payments',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount:
                        _dashboardData?.pendingPayments.payments.length ?? 0,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final payment =
                          _dashboardData!.pendingPayments.payments[index];
                      return PaymentListItem(
                        customerName: payment['customerName'],
                        totalAmount: payment['totalAmount'] as int,
                        remainingAmount: payment['amountRemaining'] as int,
                        onTap: () => _navigateToBillDetails(payment),
                        loc: loc,
                      );
                    },
                  ),
          ),
          if (_expandPendingPayments &&
              (_dashboardData?.pendingPayments.payments.isNotEmpty ??
                  false)) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    AppNavigator.push(context, const PendingPaymentsPage());
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: Text(
                    loc?.viewAllPendingPayments ?? 'View All Pending Payments',
                  ),
                  style: Adaptive.compactOutlined.copyWith(
                    foregroundColor: WidgetStatePropertyAll(Colors.orange[600]),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviousDueCard(AppLocalizations? loc) {
    return ExpandableCard(
      title: loc?.previousDueTracking ?? 'Previous Due Tracking',
      themeColor: Colors.purple,
      badgeText:
          '${_dashboardData?.previousDueTracking.totalBills == 1 ? (loc?.bill ?? 'Bill') : (loc?.bills ?? 'Bills')} ${_dashboardData?.previousDueTracking.totalBills ?? 0}',
      grouped: true,
      showDivider: true,
      initiallyExpanded: _expandPreviousDue,
      onExpansionChanged: () =>
          setState(() => _expandPreviousDue = !_expandPreviousDue),
      loc: loc,
      expandedContent: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                DashboardMetric(
                  label: loc?.totalDue ?? 'Total Due',
                  value:
                      '₹${_formatCurrency(((_dashboardData?.previousDueTracking.totalCollected ?? 0) + (_dashboardData?.previousDueTracking.totalPending ?? 0)).toInt(), loc: loc)}',
                  valueColor: Colors.purple[600],
                ),
                DashboardMetric(
                  label: loc?.collected ?? 'Collected',
                  value:
                      '₹${_formatCurrency(_dashboardData?.previousDueTracking.totalCollected.toInt() ?? 0, loc: loc)}',
                  valueColor: Colors.green[600],
                ),
                DashboardMetric(
                  label: loc?.pending ?? 'Pending',
                  value:
                      '₹${_formatCurrency(_dashboardData?.previousDueTracking.totalPending.toInt() ?? 0, loc: loc)}',
                  valueColor: Colors.orange[600],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  AppNavigator.push(context, const PreviousDuePaymentsPage());
                },
                icon: const Icon(Icons.visibility, size: 18),
                label: Text(
                  loc?.viewAllPreviousDuePayments ??
                      'View All Previous Due Payments',
                ),
                style: Adaptive.compactOutlined.copyWith(
                  foregroundColor: WidgetStatePropertyAll(Colors.purple[600]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityCard(AppLocalizations? loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          DashboardMetric(
            label: loc?.availableProductsCount ?? 'Products',
            value:
                '${_dashboardData?.productsData.availableProductsCount ?? 0}',
            valueColor: Colors.orange[600],
          ),
          DashboardMetric(
            label: loc?.totalQuantity ?? 'Qty',
            value: '${_dashboardData?.productsData.totalAvailableQty ?? 0}',
            valueColor: Colors.green[600],
          ),
          DashboardMetric(
            label: loc?.stockValue ?? 'Stock value',
            value:
                '₹${_formatCurrency((_dashboardData?.productsData.totalAvailableAmount ?? 0).toInt(), loc: loc)}',
            valueColor: Colors.blue[600],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingPaymentsCard(AppLocalizations? loc) {
    final scheme = Theme.of(context).colorScheme;

    return ExpandableCard(
      title: loc?.upcomingPayments ?? 'Upcoming Payments',
      subtitle:
          '${loc?.getFullMonthName(DateTime.now().month) ?? getMonthName(DateTime.now().month)} ${DateTime.now().year}',
      themeColor: Colors.blue,
      badgeText:
          '${_dashboardData?.upcomingPayments.length ?? 0} ${loc?.due ?? 'due'}',
      grouped: true,
      showDivider: true,
      initiallyExpanded: _expandUpcomingPayments,
      onExpansionChanged: () =>
          setState(() => _expandUpcomingPayments = !_expandUpcomingPayments),
      loc: loc,
      expandedContent: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: (_dashboardData?.upcomingPayments.isEmpty ?? true)
            ? Center(
                child: Text(
                  loc?.noUpcomingPayments ?? 'No upcoming payments',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _dashboardData?.upcomingPayments.length ?? 0,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final payment = _dashboardData!.upcomingPayments[index];
                  return InkWell(
                    onTap: () => _navigateToBillDetails(payment),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payment['customerName'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${loc?.due ?? 'Due'}: ${payment['nextPaymentDate']}  ·  ₹${payment['totalAmount']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${loc?.remaining ?? 'Remaining'}: ₹${payment['amountRemaining']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange[600],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildOrderNowCard(AppLocalizations? loc) {
    final scheme = Theme.of(context).colorScheme;
    final products = _dashboardData?.productsData.orderNowProducts ?? [];
    final visibleCount = products.length > 5 ? 5 : products.length;

    return ExpandableCard(
      title: loc?.orderNow ?? 'Order Now',
      themeColor: Colors.red,
      badgeText: '${products.length}',
      grouped: true,
      initiallyExpanded: _expandOrderNow,
      onExpansionChanged: () =>
          setState(() => _expandOrderNow = !_expandOrderNow),
      loc: loc,
      expandedContent: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: products.isEmpty
            ? Center(
                child: Text(
                  loc?.noProductsToOrder ?? 'No products to order',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            : Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleCount,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['productName'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${product['supplierName']}  ·  ${product['unit']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            loc?.stock0 ?? 'Stock: 0',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.red[600],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (products.length > 5) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AppNavigator.push(
                            context,
                            OrderNowPage(orderNowProducts: products),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: Text(
                          '${loc?.viewAll ?? 'View All'} (${products.length - 5} more)',
                        ),
                        style: Adaptive.compactOutlined.copyWith(
                          foregroundColor: WidgetStatePropertyAll(
                            Colors.red[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    String description, {
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _sectionBox({required Widget child}) {
    return Adaptive.box(context: context, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubscriptionExpiredBanner(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _sectionBox(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionHeader(
                                  loc?.availability ?? 'Availability',
                                  loc?.currentStockOverview ??
                                      'Current Stock Overview',
                                ),
                                _buildAvailabilityCard(loc),
                              ],
                            ),
                          ),
                          _sectionBox(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionHeader(
                                  loc?.salesProfitAnalysis ??
                                      'Sales & Profit / Loss Analysis',
                                  _getMonthYear(),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Builder(
                                        builder: (buttonContext) {
                                          return IconButton(
                                            tooltip: loc?.filter ?? 'Filter',
                                            icon: Icon(
                                              Icons.filter_list,
                                              color: scheme.primary,
                                            ),
                                            onPressed: () =>
                                                AppContextMenu.show(
                                              buttonContext: buttonContext,
                                              items: [
                                                AppContextMenuItem(
                                                  label:
                                                      loc?.allData ??
                                                      'All Data',
                                                  icon: Icons.all_inclusive,
                                                  selected:
                                                      filterType == 'all',
                                                  onPressed: () {
                                                    setState(
                                                      () =>
                                                          filterType = 'all',
                                                    );
                                                    _saveFilterPreference(
                                                      'all',
                                                    );
                                                    _updateDashboardSubscription();
                                                  },
                                                ),
                                                AppContextMenuItem(
                                                  label:
                                                      loc?.dateRange ??
                                                      'Date Range',
                                                  icon: Icons.date_range,
                                                  selected:
                                                      filterType == 'range',
                                                  onPressed: () {
                                                    setState(
                                                      () => filterType =
                                                          'range',
                                                    );
                                                    _saveFilterPreference(
                                                      'range',
                                                    );
                                                    _updateDashboardSubscription();
                                                  },
                                                ),
                                                AppContextMenuItem(
                                                  label: loc?.day ?? 'Day',
                                                  icon: Icons.calendar_today,
                                                  selected:
                                                      filterType == 'day',
                                                  onPressed: () {
                                                    setState(
                                                      () =>
                                                          filterType = 'day',
                                                    );
                                                    _saveFilterPreference(
                                                      'day',
                                                    );
                                                    _updateDashboardSubscription();
                                                  },
                                                ),
                                                AppContextMenuItem(
                                                  label:
                                                      loc?.month ?? 'Month',
                                                  icon: Icons.calendar_month,
                                                  selected:
                                                      filterType == 'month',
                                                  onPressed: () {
                                                    setState(
                                                      () => filterType =
                                                          'month',
                                                    );
                                                    _saveFilterPreference(
                                                      'month',
                                                    );
                                                    _updateDashboardSubscription();
                                                  },
                                                ),
                                                AppContextMenuItem(
                                                  label: loc?.year ?? 'Year',
                                                  icon: Icons
                                                      .calendar_view_month,
                                                  selected:
                                                      filterType == 'year',
                                                  onPressed: () {
                                                    setState(
                                                      () =>
                                                          filterType = 'year',
                                                    );
                                                    _saveFilterPreference(
                                                      'year',
                                                    );
                                                    _updateDashboardSubscription();
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: loc?.select ?? 'Select',
                                        icon: Icon(
                                          Icons.calendar_today,
                                          color: filterType == 'all'
                                              ? scheme.onSurfaceVariant
                                              : scheme.primary,
                                        ),
                                        onPressed: filterType == 'all'
                                            ? null
                                            : () => _showMonthPicker(
                                                context,
                                                loc,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildProfitLossCard(),
                              ],
                            ),
                          ),
                          _sectionBox(
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _sectionHeader(
                                    loc?.businessInsights ??
                                        'Business Insights',
                                    loc?.paymentsProductsAndRestock ??
                                        'Payments, products and restock',
                                  ),
                                ),
                                _buildUpcomingPaymentsCard(loc),
                                _buildTopSellingProductsCard(loc),
                                _buildLeastSellingProductsCard(loc),
                                _buildPendingPaymentsCard(loc),
                                _buildPreviousDueCard(loc),
                                _buildOrderNowCard(loc),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitLossCard() {
    final totalSales = _dashboardData?.salesMetrics.totalSales ?? 0;
    final profit = _dashboardData?.salesMetrics.totalProfit ?? 0;
    final isProfitable = profit >= 0;
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc?.totalSales ?? 'Total Sales',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${_formatCurrency(totalSales, loc: loc)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isProfitable
                      ? loc?.profitLabel ?? 'Profit'
                      : loc?.loss ?? 'Loss',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${isProfitable ? '+' : '-'}₹${_formatCurrency(profit.abs(), loc: loc)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: isProfitable ? Colors.green[600] : Colors.red[600],
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  String _formatCurrency(int amount, {AppLocalizations? loc}) {
    // Format with commas for thousands separator
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return formatted;
  }

  void _showMonthPicker(BuildContext context, AppLocalizations? loc) {
    // If range filter is selected, show date range picker
    if (filterType == 'range') {
      showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: _rangeStartDate != null && _rangeEndDate != null
            ? DateTimeRange(start: _rangeStartDate!, end: _rangeEndDate!)
            : null,
      ).then((pickedRange) {
        if (pickedRange != null) {
          setState(() {
            _rangeStartDate = pickedRange.start;
            _rangeEndDate = pickedRange.end;
          });
          _saveFilterPreference('range');
          _updateDashboardSubscription();
        }
      });
      return;
    }

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
          });
          _updateDashboardSubscription();
        }
      });
      return;
    }

    int selectedYear = selectedDate.year;
    int selectedMonth = selectedDate.month;
    Color primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String dialogTitle = filterType == 'year'
            ? (loc?.selectYear ?? 'Select Year')
            : (loc?.selectMonthYear ?? 'Select Month & Year');

        return AlertDialog(
          title: Text(dialogTitle, style: TextStyle(color: primaryColor)),
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
                                  loc?.getFullMonthName(index + 1) ??
                                      getMonthName(index + 1),
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
              child: Text(loc?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedDate = DateTime(selectedYear, selectedMonth, 1);
                });
                Navigator.of(context).pop();
                _updateDashboardSubscription();
              },
              child: Text(loc?.select ?? 'Select'),
            ),
          ],
        );
      },
    );
  }

  String _getMonthYear() {
    final loc = AppLocalizations.of(context);
    if (filterType == 'all') {
      return loc?.allTime ?? 'All Time';
    } else if (filterType == 'range') {
      if (_rangeStartDate != null && _rangeEndDate != null) {
        return '${_rangeStartDate!.day}/${_rangeStartDate!.month}/${_rangeStartDate!.year} - ${_rangeEndDate!.day}/${_rangeEndDate!.month}/${_rangeEndDate!.year}';
      }
      return loc?.selectRange ?? 'Select Range';
    } else if (filterType == 'year') {
      return '${selectedDate.year}';
    } else if (filterType == 'day') {
      return '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';
    } else {
      return '${loc?.getFullMonthName(selectedDate.month) ?? getMonthName(selectedDate.month)} ${selectedDate.year}';
    }
  }

  void _navigateToBillDetails(Map<String, dynamic> bill) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Convert bill data to match ViewBillDetailsScreen parameters
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ViewBillDetailsScreen(
            billId: bill['id'] as String,
            billDate: bill['billDate'] as String,
            customerName: bill['customerName'] as String,
            customerMobile: (bill['customerMobile'] ?? 'N/A') as String,
            customerVehicle: bill['customerVehicle'] as String?,
            totalAmount: ((bill['totalAmount'] ?? 0) as num).toInt(),
            totalAmountPaid: (bill['totalAmountPaid'] as bool?) ?? false,
            amountPaid: ((bill['amountPaid'] ?? 0) as num).toInt(),
            amountRemaining:
                (((bill['amountRemaining'] ?? bill['totalAmount'] ?? 0) as num)
                    .toInt()),
            products: bill['products'] != null
                ? (bill['products'] as Map).entries
                      .map(
                        (e) => {
                          'productName':
                              (e.value['productName'] ?? 'Unknown') as String,
                          'quantity': ((e.value['quantity'] ?? 0) as num)
                              .toInt(),
                          'price': ((e.value['price'] ?? 0) as num).toInt(),
                          'boughtPrice': ((e.value['boughtPrice'] ?? 0) as num)
                              .toInt(),
                        },
                      )
                      .toList()
                : null,
            paymentMethod: (bill['paymentMethod'] ?? 'cash') as String,
            previousDueAmount: ((bill['previousDueAmount'] ?? 0) as num)
                .toDouble(),
            previousDueDescription:
                (bill['previousDueDescription'] ?? '') as String,
          ),
        ),
      );
    } catch (e) {
      appLog('Error navigating to bill details: $e');
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc?.errorOpeningBillDetails ?? 'Error opening bill details'}: $e',
          ),
        ),
      );
    }
  }
}
