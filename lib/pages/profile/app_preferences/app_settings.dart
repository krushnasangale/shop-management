import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/navigation/app_navigator.dart';
import 'package:flashbill/providers/language_provider.dart';
import 'package:flashbill/providers/theme_provider.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/widgets/language_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  bool _vehicleNumberEnabled = false;
  bool _deliveryChargesEnabled = false;
  bool _previousDueEnabled = false;
  bool _expiryDateEnabled = false;
  bool _expensesEnabled = false;
  bool _isLoading = true;

  StreamSubscription<Map<String, dynamic>>? _settingsSubscription;
  late final ProfileService _profileService;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
    _loadSettings();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _profileService.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _profileService.initialize(user.uid);
      _settingsSubscription = _profileService.appSettingsStream.listen(
        (appSettings) {
          if (!mounted) return;
          setState(() {
            _vehicleNumberEnabled =
                appSettings['vehicleNumberEnabled'] ?? false;
            _deliveryChargesEnabled =
                appSettings['deliveryChargesEnabled'] ?? false;
            _previousDueEnabled = appSettings['previousDueEnabled'] ?? false;
            _expiryDateEnabled = appSettings['expiryDateEnabled'] ?? false;
            _expensesEnabled = appSettings['expensesEnabled'] ?? false;
            _isLoading = false;
          });
        },
        onError: (error) {
          appLog('Error loading settings: $error');
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      appLog('Error initializing settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final loc = AppLocalizations.of(context);
    try {
      await _profileService.updateAppSetting(key, value);
    } catch (e) {
      appLog('Error saving setting: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${loc?.error ?? 'Error'}: $e')));
    }
  }

  void _toggle(String key, bool value, void Function(bool) apply) {
    setState(() => apply(value));
    _saveSetting(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc?.settings ?? 'App Settings';

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
    if (_isLoading) {
      return Center(child: Adaptive.progress());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _sectionLabel(loc?.general ?? 'General'),
        _SettingsGroup(
          children: [
            Consumer<LanguageProvider>(
              builder: (context, languageProvider, _) {
                return _NavTile(
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
        const SizedBox(height: 20),
        _sectionLabel(loc?.bills ?? 'Bills'),
        _SettingsGroup(
          children: [
            _SettingTile(
              icon: Icons.directions_car_outlined,
              title: loc?.vehicleNumber ?? 'Vehicle Number',
              value: _vehicleNumberEnabled,
              onChanged: (value) => _toggle(
                'vehicleNumberEnabled',
                value,
                (next) => _vehicleNumberEnabled = next,
              ),
            ),
            _SettingTile(
              icon: Icons.local_shipping_outlined,
              title: loc?.deliveryCharges ?? 'Delivery Charges',
              value: _deliveryChargesEnabled,
              onChanged: (value) => _toggle(
                'deliveryChargesEnabled',
                value,
                (next) => _deliveryChargesEnabled = next,
              ),
            ),
            _SettingTile(
              icon: Icons.account_balance_wallet_outlined,
              title: loc?.previousDueAmount ?? 'Previous Due Amount',
              value: _previousDueEnabled,
              onChanged: (value) => _toggle(
                'previousDueEnabled',
                value,
                (next) => _previousDueEnabled = next,
              ),
            ),
          ],
        ),
        _sectionFooter('These fields appear when creating a bill.'),
        const SizedBox(height: 20),
        _sectionLabel(loc?.purchases ?? 'Purchases'),
        _SettingsGroup(
          children: [
            _SettingTile(
              icon: Icons.event_outlined,
              title: loc?.expiryDate ?? 'Expiry Date',
              value: _expiryDateEnabled,
              onChanged: (value) => _toggle(
                'expiryDateEnabled',
                value,
                (next) => _expiryDateEnabled = next,
              ),
            ),
          ],
        ),
        _sectionFooter(
          loc?.enableExpiryDateField ??
              'Show expiry date when adding purchase entries.',
        ),
        const SizedBox(height: 20),
        _sectionLabel('Features'),
        _SettingsGroup(
          children: [
            _SettingTile(
              icon: Icons.payments_outlined,
              title: loc?.expenses ?? 'Expenses',
              value: _expensesEnabled,
              onChanged: (value) => _toggle(
                'expensesEnabled',
                value,
                (next) => _expensesEnabled = next,
              ),
            ),
          ],
        ),
        _sectionFooter('Turn the expenses tab on or off for this shop.'),
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

  Widget _sectionFooter(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, right: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          color: scheme.onSurfaceVariant,
        ),
      ),
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
            Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? 8 : 0,
                bottom: i == children.length - 1 ? 8 : 0,
              ),
              child: children[i],
            ),
            if (i != children.length - 1) const Divider(height: 1, indent: 64),
          ],
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final leading = _settingsLeading(context, icon);
    final titleStyle = _settingsTitleStyle(context);
    final switchWidget = CupertinoSwitch(
      value: value,
      onChanged: onChanged,
    );

    if (Adaptive.isCupertino) {
      return CupertinoListTile(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
        leading: leading,
        title: Text(title, style: titleStyle),
        trailing: switchWidget,
        onTap: () => onChanged(!value),
      );
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      minVerticalPadding: 7,
      leading: leading,
      title: Text(title, style: titleStyle),
      trailing: switchWidget,
      onTap: () => onChanged(!value),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leading = _settingsLeading(context, icon);
    final titleStyle = _settingsTitleStyle(context);
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      ],
    );

    if (Adaptive.isCupertino) {
      return CupertinoListTile(
        padding: const EdgeInsets.fromLTRB(16, 7, 12, 7),
        leading: leading,
        title: Text(title, style: titleStyle),
        additionalInfo: Text(value),
        trailing: const CupertinoListTileChevron(),
        onTap: onTap,
      );
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 3, 12, 3),
      minVerticalPadding: 7,
      leading: leading,
      title: Text(title, style: titleStyle),
      trailing: trailing,
      onTap: onTap,
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
        final switchWidget = CupertinoSwitch(
          value: isLight,
          onChanged: (_) => themeProvider.toggleTheme(),
        );
        final trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLight ? lightLabel : darkLabel,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            switchWidget,
          ],
        );

        if (Adaptive.isCupertino) {
          return CupertinoListTile(
            padding: const EdgeInsets.fromLTRB(16, 7, 12, 7),
            leading: _settingsLeading(context, Icons.contrast_outlined),
            title: Text(title, style: _settingsTitleStyle(context)),
            trailing: trailing,
            onTap: () => themeProvider.toggleTheme(),
          );
        }

        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.fromLTRB(16, 3, 12, 3),
          minVerticalPadding: 7,
          leading: _settingsLeading(context, Icons.contrast_outlined),
          title: Text(title, style: _settingsTitleStyle(context)),
          trailing: trailing,
          onTap: () => themeProvider.toggleTheme(),
        );
      },
    );
  }
}

Widget _settingsLeading(BuildContext context, IconData icon) {
  final scheme = Theme.of(context).colorScheme;
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

TextStyle _settingsTitleStyle(BuildContext context) {
  return TextStyle(
    fontWeight: FontWeight.w700,
    color: Theme.of(context).colorScheme.onSurface,
  );
}
