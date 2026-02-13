import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'dart:async';

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
  bool _expensesEnabled = false; // Default to disabled
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

      // Initialize profile service
      _profileService.initialize(user.uid);

      // Listen to app settings updates
      _settingsSubscription = _profileService.appSettingsStream.listen(
        (appSettings) {
          if (mounted) {
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
          }
        },
        onError: (error) {
          print('Error loading settings: $error');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );
    } catch (e) {
      print('Error initializing settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final loc = AppLocalizations.of(context);
    try {
      await _profileService.updateAppSetting(key, value);
    } catch (e) {
      print('Error saving setting: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${loc?.error ?? 'Error'}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(loc?.settings ?? 'App Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc?.settings ?? 'App Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          _buildSettingCard(
            title: loc?.vehicleNumberInBills ?? 'Vehicle Number in Bills',
            subtitle:
                loc?.enableVehicleNumberOption ??
                'Enable option to enter vehicle number when creating bills',
            value: _vehicleNumberEnabled,
            onChanged: (value) {
              setState(() => _vehicleNumberEnabled = value);
              _saveSetting('vehicleNumberEnabled', value);
            },
            icon: Icons.directions_car,
          ),
          const SizedBox(height: 4),
          _buildSettingCard(
            title: loc?.deliveryCharges ?? 'Delivery Charges',
            subtitle:
                loc?.enableDeliveryChargesField ??
                'Enable delivery charges field in bill creation',
            value: _deliveryChargesEnabled,
            onChanged: (value) {
              setState(() => _deliveryChargesEnabled = value);
              _saveSetting('deliveryChargesEnabled', value);
            },
            icon: Icons.local_shipping,
          ),
          const SizedBox(height: 4),
          _buildSettingCard(
            title: loc?.previousDueAmount ?? 'Previous Due Amount',
            subtitle:
                loc?.enablePreviousDueField ??
                'Enable previous due amount field in bill creation',
            value: _previousDueEnabled,
            onChanged: (value) {
              setState(() => _previousDueEnabled = value);
              _saveSetting('previousDueEnabled', value);
            },
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 4),
          _buildSettingCard(
            title: loc?.expiryDateInPurchases ?? 'Expiry Date in Purchases',
            subtitle:
                loc?.enableExpiryDateField ??
                'Enable expiry date field when adding purchase entries',
            value: _expiryDateEnabled,
            onChanged: (value) {
              setState(() => _expiryDateEnabled = value);
              _saveSetting('expiryDateEnabled', value);
            },
            icon: Icons.date_range,
          ),
          const SizedBox(height: 4),
          _buildSettingCard(
            title: 'Expenses Feature',
            subtitle:
                'Enable or disable the expenses tracking feature in the app',
            value: _expensesEnabled,
            onChanged: (value) {
              setState(() => _expensesEnabled = value);
              _saveSetting('expensesEnabled', value);
            },
            icon: Icons.account_balance,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.0),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Transform.scale(
                  scale: 1.1,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: Theme.of(context).primaryColor,
                    activeTrackColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.4),
                    inactiveThumbColor: Colors.grey.shade400,
                    inactiveTrackColor: Colors.grey.shade300,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
