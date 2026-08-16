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

/// Persistent read-only notice shown under the app bar when expired.
class SubscriptionExpiredBanner extends StatelessWidget {
  const SubscriptionExpiredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscription, _) {
        if (!subscription.isExpired) return const SizedBox.shrink();
        final loc = AppLocalizations.of(context);
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.errorContainer,
          child: InkWell(
            onTap: () => SubscriptionGuard.showExpiredDialog(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 18, color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc?.subscriptionExpiredBanner ??
                          'Subscription expired — view only. Tap for details.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
