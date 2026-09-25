import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/profile/edit_profile.dart';
import 'package:flashbill/services/profile_completion.dart';
import 'package:material_ui/material_ui.dart';

class ProfileIncompleteBanner extends StatelessWidget {
  const ProfileIncompleteBanner({super.key, this.forBilling = false});

  final bool forBilling;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shop-profile')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final completion = ProfileCompletion.from(snapshot.data!.data());
        if (completion.isComplete) return const SizedBox.shrink();
        return _ProfileIncompleteBar(
          percent: completion.percent,
          forBilling: forBilling,
        );
      },
    );
  }
}

class _ProfileIncompleteBar extends StatelessWidget {
  const _ProfileIncompleteBar({
    required this.percent,
    required this.forBilling,
  });

  final int percent;
  final bool forBilling;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final background = isLight
        ? const Color(0xFFFFF3CD)
        : const Color(0xFF4E3B00);
    final foreground = isLight
        ? const Color(0xFF7A5C00)
        : const Color(0xFFFFE082);
    final title =
        (loc?.profilePercentComplete ?? 'Profile {percent}% complete')
            .replaceAll('{percent}', '$percent');
    final message = forBilling
        ? (loc?.profileIncompleteBills ??
              'Complete your shop profile to create bills.')
        : (loc?.profileIncompleteDashboard ??
              'Complete your shop profile to use all features.');

    return Material(
      color: background,
      child: InkWell(
        onTap: () => AppNavigator.push(context, const EditProfile()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 5,
                        backgroundColor: foreground.withValues(alpha: 0.2),
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> ensureProfileCompleteForBilling(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final snapshot = await FirebaseFirestore.instance
      .collection('shop-profile')
      .doc(user.uid)
      .get();
  final completion = ProfileCompletion.from(snapshot.data());
  if (completion.isComplete) return true;
  if (!context.mounted) return false;
  final loc = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        loc?.profileRequiredToCreateBill ??
            'Complete your shop profile before creating a bill.',
      ),
    ),
  );
  return false;
}
