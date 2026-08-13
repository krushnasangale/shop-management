import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/pages/login/login.dart';
import 'package:flashbill/pages/profile/app_preferences/app_settings.dart';
import 'package:flashbill/pages/profile/change_password.dart';
import 'package:flashbill/pages/profile/customer/customers.dart';
import 'package:flashbill/pages/profile/edit_profile.dart';
import 'package:flashbill/pages/profile/logged_in_devices.dart';
import 'package:flashbill/pages/profile/privacy_policy.dart';
import 'package:flashbill/pages/profile/products/product.dart';
import 'package:flashbill/pages/profile/supplier/suppliers.dart';
import 'package:flashbill/pages/profile/units/units.dart';
import 'package:flashbill/providers/language_provider.dart';
import 'package:flashbill/providers/theme_provider.dart';
import 'package:flashbill/services/notification_service.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/widgets/language_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class MyProfile extends StatefulWidget {
  const MyProfile({super.key});

  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  bool _isLoggingOut = false;
  String _shopName = '----';
  StreamSubscription<Map<String, dynamic>>? _profileSubscription;
  late final ProfileService _profileService;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
    _listenToShopName();
  }

  void _listenToShopName() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _profileService.initialize(user.uid);
      _profileSubscription = _profileService.profileStream.listen(
        (profileData) {
          if (!mounted) return;
          final shopName = profileData['shopName'] as String?;
          if (shopName != null && shopName.isNotEmpty) {
            setState(() => _shopName = shopName);
          }
        },
        onError: (error) {
          appLog('Error listening to shop name: $error');
        },
      );
    } catch (e) {
      appLog('Error initializing profile service: $e');
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _profileService.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await NotificationService().removeTokenFromFirestore();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizations?.logoutFailed ?? 'Logout failed'}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc?.myProfile ?? 'My Profile';

    if (Adaptive.isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(title)),
        child: SafeArea(child: _buildBody(loc)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _buildBody(loc),
    );
  }

  Widget _buildBody(AppLocalizations? loc) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _ProfileHeader(
          shopName: _shopName,
          subtitle: loc?.viewAndEditProfile ?? 'View and edit profile',
          onTap: () => AppNavigator.push(context, const EditProfile()),
        ),
        const SizedBox(height: 24),
        _sectionLabel(loc?.add ?? 'Add'),
        _SettingsGroup(
          children: [
            _CountTile(
              icon: Icons.local_shipping_outlined,
              title: loc?.suppliers ?? 'Suppliers',
              collection: 'suppliers',
              onTap: () => AppNavigator.push(context, const Suppliers()),
            ),
            _CountTile(
              icon: Icons.straighten_outlined,
              title: loc?.units ?? 'Units',
              collection: 'units',
              onTap: () =>
                  AppNavigator.push(context, const MeasurementUnitsScreen()),
            ),
            _CountTile(
              icon: Icons.inventory_2_outlined,
              title: loc?.productNames ?? 'Product Names',
              collection: 'product-names',
              onTap: () => AppNavigator.push(context, const ProductName()),
            ),
            _CountTile(
              icon: Icons.people_outline,
              title: loc?.customers ?? 'Customers',
              collection: 'customers',
              onTap: () => AppNavigator.push(context, const Customers()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionLabel(loc?.privacy ?? 'Privacy'),
        _SettingsGroup(
          children: [
            _DevicesTile(
              title: loc?.loggedInDevices ?? 'Logged In Devices',
              onTap: () =>
                  AppNavigator.push(context, const LoggedInDevicesScreen()),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: loc?.changePassword ?? 'Change Password',
              onTap: () =>
                  AppNavigator.push(context, const ChangePasswordPage()),
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: loc?.privacyPolicy ?? 'Privacy Policy',
              onTap: () =>
                  AppNavigator.push(context, const PrivacyPolicyPage()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionLabel(loc?.general ?? 'General'),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.tune_outlined,
              title: loc?.appSettings ?? 'App Settings',
              onTap: () => AppNavigator.push(context, const AppSettings()),
            ),
            Consumer<LanguageProvider>(
              builder: (context, languageProvider, _) {
                return _SettingsTile(
                  icon: Icons.language_outlined,
                  title: loc?.language ?? 'Language',
                  value: languageProvider.getNativeLanguageName(
                    languageProvider.currentLocale.languageCode,
                  ),
                  onTap: () =>
                      AppNavigator.push(context, const LanguageSelector()),
                );
              },
            ),
            _ThemeTile(
              title: loc?.theme ?? 'Theme',
              lightLabel: loc?.light ?? 'Light',
              darkLabel: loc?.dark ?? 'Dark',
            ),
          ],
        ),
        const SizedBox(height: 28),
        _LogoutButton(
          loading: _isLoggingOut,
          label: _isLoggingOut
              ? (loc?.loggingOut ?? 'Logging Out...')
              : (loc?.logOut ?? 'Log Out'),
          onPressed: _isLoggingOut ? null : _logout,
        ),
      ],
    );
  }

  Widget _sectionLabel(String title) {
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
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.shopName,
    required this.subtitle,
    required this.onTap,
  });

  final String shopName;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              Icons.storefront_rounded,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );

    if (Adaptive.isCupertino) {
      return GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: content,
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (Adaptive.isCupertino) {
      return CupertinoListSection.insetGrouped(
        margin: EdgeInsets.zero,
        children: children,
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leading = Icon(icon, color: scheme.primary, size: 22);

    if (Adaptive.isCupertino) {
      return CupertinoListTile(
        leading: leading,
        title: Text(title),
        additionalInfo: value != null ? Text(value!) : null,
        trailing: trailing ?? const CupertinoListTileChevron(),
        onTap: onTap,
      );
    }

    return ListTile(
      leading: leading,
      title: Text(title),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                Text(value!, style: TextStyle(color: scheme.onSurfaceVariant)),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
      onTap: onTap,
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.icon,
    required this.title,
    required this.collection,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _SettingsTile(icon: icon, title: title, onTap: onTap);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .collection('items')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        return _SettingsTile(
          icon: icon,
          title: title,
          value: waiting ? null : '$count',
          trailing: waiting
              ? SizedBox(width: 16, height: 16, child: Adaptive.progress())
              : null,
          onTap: onTap,
        );
      },
    );
  }
}

class _DevicesTile extends StatelessWidget {
  const _DevicesTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _SettingsTile(
        icon: Icons.devices_outlined,
        title: title,
        onTap: onTap,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user-devices')
          .doc(user.uid)
          .collection('devices')
          .snapshots(),
      builder: (context, snapshot) {
        var deviceCount = 0;
        if (snapshot.hasData) {
          deviceCount = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['revokedAt'] == null;
          }).length;
        }
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        return _SettingsTile(
          icon: Icons.devices_outlined,
          title: title,
          value: waiting ? null : '$deviceCount',
          trailing: waiting
              ? SizedBox(width: 16, height: 16, child: Adaptive.progress())
              : null,
          onTap: onTap,
        );
      },
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.title,
    required this.lightLabel,
    required this.darkLabel,
  });

  final String title;
  final String lightLabel;
  final String darkLabel;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isLight = themeProvider.isLightTheme;
        final scheme = Theme.of(context).colorScheme;
        final switchWidget = Adaptive.isCupertino
            ? CupertinoSwitch(
                value: isLight,
                onChanged: (_) => themeProvider.toggleTheme(),
              )
            : Switch(
                value: isLight,
                onChanged: (_) => themeProvider.toggleTheme(),
              );

        return _SettingsTile(
          icon: Icons.contrast_outlined,
          title: title,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLight ? lightLabel : darkLabel,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(width: 8),
              switchWidget,
            ],
          ),
        );
      },
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(width: 18, height: 18, child: Adaptive.progress())
        : Text(label);

    if (Adaptive.isCupertino) {
      return CupertinoButton(
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: CupertinoColors.destructiveRed),
          child: child,
        ),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
        side: BorderSide(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }
}
