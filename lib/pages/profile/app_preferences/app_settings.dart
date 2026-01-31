import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isLoading = true;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _settingsSubscription = FirebaseFirestore.instance
          .collection('shop-profile')
          .doc(user.uid)
          .snapshots()
          .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
            if (mounted && snapshot.exists) {
              final data = snapshot.data() ?? {};
              final appSettings =
                  data['appSettings'] as Map<String, dynamic>? ?? {};
              setState(() {
                _vehicleNumberEnabled =
                    appSettings['vehicleNumberEnabled'] ?? false;
                _deliveryChargesEnabled =
                    appSettings['deliveryChargesEnabled'] ?? false;
                _previousDueEnabled =
                    appSettings['previousDueEnabled'] ?? false;
                _expiryDateEnabled = appSettings['expiryDateEnabled'] ?? false;
                _isLoading = false;
              });
            } else {
              setState(() {
                _isLoading = false;
              });
            }
          });
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = FirebaseFirestore.instance
          .collection('shop-profile')
          .doc(user.uid);

      // Get current appSettings or create new
      final snapshot = await docRef.get();
      final data = snapshot.data() ?? {};
      final appSettings = data['appSettings'] as Map<String, dynamic>? ?? {};

      // Update the setting
      appSettings[key] = value;

      // Save back
      await docRef.set({
        ...data,
        'appSettings': appSettings,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving setting: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save setting: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('App Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('App Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSettingCard(
            title: 'Vehicle Number in Bills',
            subtitle:
                'Enable option to enter vehicle number when creating bills',
            value: _vehicleNumberEnabled,
            onChanged: (value) {
              setState(() => _vehicleNumberEnabled = value);
              _saveSetting('vehicleNumberEnabled', value);
            },
            icon: Icons.directions_car,
          ),
          const SizedBox(height: 8),
          _buildSettingCard(
            title: 'Delivery Charges',
            subtitle: 'Enable delivery charges field in bill creation',
            value: _deliveryChargesEnabled,
            onChanged: (value) {
              setState(() => _deliveryChargesEnabled = value);
              _saveSetting('deliveryChargesEnabled', value);
            },
            icon: Icons.local_shipping,
          ),
          const SizedBox(height: 8),
          _buildSettingCard(
            title: 'Previous Due Amount',
            subtitle: 'Enable previous due amount field in bill creation',
            value: _previousDueEnabled,
            onChanged: (value) {
              setState(() => _previousDueEnabled = value);
              _saveSetting('previousDueEnabled', value);
            },
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 8),
          _buildSettingCard(
            title: 'Expiry Date in Purchases',
            subtitle: 'Enable expiry date field when adding purchase entries',
            value: _expiryDateEnabled,
            onChanged: (value) {
              setState(() => _expiryDateEnabled = value);
              _saveSetting('expiryDateEnabled', value);
            },
            icon: Icons.date_range,
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
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Transform.scale(
                  scale: 1.1,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    activeColor: Theme.of(context).primaryColor,
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
