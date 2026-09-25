import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/services/notification_service.dart';
import 'package:flashbill/services/onboarding_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/theme/app_theme.dart';
import 'package:flashbill/widgets/language_selector.dart';
import 'package:material_ui/material_ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.benefits = const [],
    this.isNotificationPage = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<(IconData, String)> benefits;
  final bool isNotificationPage;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  List<_OnboardingPage> _pages(AppLocalizations? loc) {
    return [
      _OnboardingPage(
        icon: Icons.storefront_rounded,
        title: loc?.onboardingWelcomeTitle ?? 'Welcome to FlashBill',
        subtitle:
            loc?.onboardingWelcomeSubtitle ??
            'Run stock, bills, and profit from one shop app.',
      ),
      _OnboardingPage(
        icon: Icons.inventory_2_rounded,
        title: loc?.onboardingStockTitle ?? 'Stock that stays current',
        subtitle:
            loc?.onboardingStockSubtitle ??
            'Record purchases and see what is available, instantly.',
      ),
      _OnboardingPage(
        icon: Icons.receipt_long_rounded,
        title: loc?.onboardingBillingTitle ?? 'Bill in seconds',
        subtitle:
            loc?.onboardingBillingSubtitle ??
            'Create bills, collect payments, and share receipts.',
      ),
      _OnboardingPage(
        icon: Icons.insights_rounded,
        title: loc?.onboardingInsightsTitle ?? 'See your profit clearly',
        subtitle:
            loc?.onboardingInsightsSubtitle ??
            'Sales, dues, and daily performance at a glance.',
      ),
      _OnboardingPage(
        icon: Icons.notifications_active_rounded,
        title: loc?.onboardingNotificationsTitle ?? 'Stay in the loop',
        subtitle:
            loc?.onboardingNotificationsSubtitle ??
            'Allow notifications for low stock, pending payments, and daily shop updates.',
        isNotificationPage: true,
        benefits: [
          (
            Icons.inventory_2_outlined,
            loc?.onboardingNotificationsLowStock ?? 'Low stock warnings',
          ),
          (
            Icons.payments_outlined,
            loc?.onboardingNotificationsPayments ??
                'Pending payment reminders',
          ),
          (
            Icons.wb_sunny_outlined,
            loc?.onboardingNotificationsDaily ?? 'Daily shop updates',
          ),
        ],
      ),
    ];
  }

  Future<void> _finish({
    bool requestNotifications = false,
    bool fromNotificationPage = false,
  }) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    if (requestNotifications) {
      try {
        await NotificationService().requestPermission();
      } catch (_) {}
    }
    if (fromNotificationPage) {
      await OnboardingService.markNotificationPrompted();
    }
    await OnboardingService.complete();
    if (!mounted) return;
    widget.onComplete();
  }

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _skipToNotifications() {
    final last = _pages(AppLocalizations.of(context)).length - 1;
    setState(() => _index = last);
    _controller.jumpToPage(last);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pages = _pages(loc);
    final isLast = _index == pages.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index > 0) {
          _goTo(_index - 1);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    if (!isLast)
                      TextButton(
                        onPressed: _finishing ? null : _skipToNotifications,
                        child: Text(loc?.skip ?? 'Skip'),
                      )
                    else
                      const SizedBox(width: 64),
                    const Spacer(),
                    const LanguageMenuButton(filledTonal: true),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) {
                      return _OnboardingPageView(page: pages[index]);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pages.length, (i) {
                    final selected = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: selected ? 22 : 8,
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                _OnboardingAction(
                  label: pages[_index].isNotificationPage
                      ? (loc?.allowNotifications ?? 'Allow notifications')
                      : (loc?.next ?? 'Next'),
                  loading: _finishing && pages[_index].isNotificationPage,
                  onPressed: _finishing
                      ? null
                      : () {
                          if (pages[_index].isNotificationPage) {
                            _finish(
                              requestNotifications: true,
                              fromNotificationPage: true,
                            );
                          } else {
                            _goTo(_index + 1);
                          }
                        },
                ),
                if (pages[_index].isNotificationPage) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _finishing
                        ? null
                        : () => _finish(fromNotificationPage: true),
                    child: Text(loc?.notNow ?? 'Not now'),
                  ),
                ] else
                  const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(page.icon, size: 52, color: scheme.onPrimary),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            loc?.appName ?? 'FlashBill',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.2,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (page.benefits.isNotEmpty) ...[
            const SizedBox(height: 28),
            ...page.benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(benefit.$1, size: 22, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        benefit.$2,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _OnboardingAction extends StatelessWidget {
  const _OnboardingAction({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(height: 22, width: 22, child: Adaptive.progress())
        : Text(label);

    if (Adaptive.isCupertino) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onPressed: onPressed,
          child: child,
        ),
      );
    }

    return FilledButton(onPressed: onPressed, child: child);
  }
}
