import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/providers/subscription_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// Blocks add / edit / delete when the shop subscription has expired.
abstract final class SubscriptionGuard {
  static bool canWrite(BuildContext context) {
    try {
      return context.read<SubscriptionProvider>().canWrite;
    } catch (_) {
      return true;
    }
  }

  static bool isExpired(BuildContext context) {
    try {
      return context.read<SubscriptionProvider>().isExpired;
    } catch (_) {
      return false;
    }
  }

  /// Returns `true` if writes are allowed. Otherwise shows a dialog and
  /// returns `false`.
  static bool ensureCanWrite(BuildContext context) {
    if (canWrite(context)) return true;
    showExpiredDialog(context);
    return false;
  }

  static void showExpiredDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc?.subscriptionExpired ?? 'Subscription Expired'),
        content: Text(
          loc?.subscriptionExpiredMessage ??
              'Your subscription has expired. You can view existing data, but adding, editing, or deleting is disabled. Please renew your subscription to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc?.close ?? 'Close'),
          ),
        ],
      ),
    );
  }
}

/// Dashboard notice: yellow when expiry is within 30 days, red when expired.
class SubscriptionExpiredBanner extends StatelessWidget {
  const SubscriptionExpiredBanner({super.key});

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscription, _) {
        final loc = AppLocalizations.of(context);
        if (subscription.isExpired) {
          final scheme = Theme.of(context).colorScheme;
          return _SubscriptionBannerBar(
            background: scheme.errorContainer,
            foreground: scheme.onErrorContainer,
            icon: Icons.lock_outline,
            message: loc?.subscriptionExpiredBanner ??
                'Subscription expired — view only. Tap for details.',
            onTap: () => SubscriptionGuard.showExpiredDialog(context),
          );
        }
        if (subscription.isExpiringSoon && subscription.expiryDate != null) {
          final isLight = Theme.of(context).brightness == Brightness.light;
          return _SubscriptionBannerBar(
            background:
                isLight ? const Color(0xFFFFF3CD) : const Color(0xFF4E3B00),
            foreground:
                isLight ? const Color(0xFF7A5C00) : const Color(0xFFFFE082),
            icon: Icons.warning_amber_rounded,
            message: loc?.subscriptionExpiringBanner(
                  _formatDate(subscription.expiryDate!),
                ) ??
                'Your subscription will expire on ${_formatDate(subscription.expiryDate!)}. Please renew it before it expires.',
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _SubscriptionBannerBar extends StatelessWidget {
  const _SubscriptionBannerBar({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.message,
    this.onTap,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
    return Material(
      color: background,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}
