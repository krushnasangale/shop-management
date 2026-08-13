import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:material_ui/material_ui.dart';

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

    final rows = [
      _SettingRowData(
        icon: Icons.directions_car_outlined,
        title: loc?.vehicleNumberInBills ?? 'Vehicle Number in Bills',
        subtitle:
            loc?.enableVehicleNumberOption ??
            'Enable option to enter vehicle number when creating bills',
        value: _vehicleNumberEnabled,
        onChanged: (value) {
          setState(() => _vehicleNumberEnabled = value);
          _saveSetting('vehicleNumberEnabled', value);
        },
      ),
      _SettingRowData(
        icon: Icons.local_shipping_outlined,
        title: loc?.deliveryCharges ?? 'Delivery Charges',
        subtitle:
            loc?.enableDeliveryChargesField ??
            'Enable delivery charges field in bill creation',
        value: _deliveryChargesEnabled,
        onChanged: (value) {
          setState(() => _deliveryChargesEnabled = value);
          _saveSetting('deliveryChargesEnabled', value);
        },
      ),
      _SettingRowData(
        icon: Icons.account_balance_wallet_outlined,
        title: loc?.previousDueAmount ?? 'Previous Due Amount',
        subtitle:
            loc?.enablePreviousDueField ??
            'Enable previous due amount field in bill creation',
        value: _previousDueEnabled,
        onChanged: (value) {
          setState(() => _previousDueEnabled = value);
          _saveSetting('previousDueEnabled', value);
        },
      ),
      _SettingRowData(
        icon: Icons.event_outlined,
        title: loc?.expiryDateInPurchases ?? 'Expiry Date in Purchases',
        subtitle:
            loc?.enableExpiryDateField ??
            'Enable expiry date field when adding purchase entries',
        value: _expiryDateEnabled,
        onChanged: (value) {
          setState(() => _expiryDateEnabled = value);
          _saveSetting('expiryDateEnabled', value);
        },
      ),
      _SettingRowData(
        icon: Icons.payments_outlined,
        title: loc?.expenses ?? 'Expenses',
        subtitle: 'Enable or disable the expenses tracking feature in the app',
        value: _expensesEnabled,
        onChanged: (value) {
          setState(() => _expensesEnabled = value);
          _saveSetting('expensesEnabled', value);
        },
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _sectionLabel(loc?.appSettings ?? 'App Settings'),
        _SettingsGroup(
          children: [for (final row in rows) _SettingTile(row: row)],
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

class _SettingRowData {
  const _SettingRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
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

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.row});

  final _SettingRowData row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leading = Icon(row.icon, color: scheme.primary, size: 22);
    final switchWidget = Adaptive.isCupertino
        ? CupertinoSwitch(value: row.value, onChanged: row.onChanged)
        : Switch(value: row.value, onChanged: row.onChanged);

    if (Adaptive.isCupertino) {
      return CupertinoListTile(
        leading: leading,
        title: Text(row.title),
        subtitle: Text(row.subtitle),
        trailing: switchWidget,
        onTap: () => row.onChanged(!row.value),
      );
    }

    return SwitchListTile(
      secondary: leading,
      title: Text(
        row.title,
        style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      subtitle: Text(row.subtitle),
      value: row.value,
      onChanged: row.onChanged,
    );
  }
}
