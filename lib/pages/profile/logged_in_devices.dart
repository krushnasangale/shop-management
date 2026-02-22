import 'package:flutter/material.dart';
import 'package:flashbill/ui helpers/app_text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flashbill/pages/login/login.dart';
import 'package:intl/intl.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/utils/device_utils.dart';

class LoggedInDevicesScreen extends StatefulWidget {
  const LoggedInDevicesScreen({super.key});

  @override
  State<LoggedInDevicesScreen> createState() => _LoggedInDevicesScreenState();
}

class _LoggedInDevicesScreenState extends State<LoggedInDevicesScreen> {
  String _currentDeviceId = 'unknown';

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final id = await _getCurrentDeviceId();
    if (mounted) setState(() => _currentDeviceId = id);
  }

  Future<void> _removeDevice(BuildContext context, String deviceId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Instead of deleting, mark the device as revoked
      await FirebaseFirestore.instance
          .collection('user-devices')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .update({'revokedAt': FieldValue.serverTimestamp()});

      if (context.mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.deviceRemovedSuccessfully ??
                  'Device removed and logged out successfully',
            ),
          ),
        );
      }

      // If the removed device is the current device, sign out locally as well.
      try {
        if (_currentDeviceId == deviceId) {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      } catch (_) {
        // ignore
      }
    } catch (e) {
      if (context.mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations?.errorRemovingDevice ?? 'Error removing device'}: $e',
            ),
          ),
        );
      }
    }
  }

  Future<String> _getCurrentDeviceId() async {
    return await DeviceUtils.getDeviceId();
  }

  void _showRemoveConfirmation(
    BuildContext context,
    String deviceId,
    String deviceName,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(
            localizations?.removeDevice ?? 'Remove Device',
            style: context.bodyLargeText,
          ),
          content: Text(
            (localizations?.removeDeviceFromLoggedIn ??
                    'Remove "{deviceName}" from logged-in devices?')
                .replaceAll('{deviceName}', deviceName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations?.cancel ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeDevice(context, deviceId);
              },
              child: Text(
                localizations?.delete ?? 'Remove',
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations?.loggedInDevices ?? 'Logged In Devices'),
        ),
        body: Center(
          child: Text(
            localizations?.pleaseLoginToViewDevices ??
                'Please login to view devices',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.loggedInDevices ?? 'Logged In Devices'),
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user-devices')
            .doc(user.uid)
            .collection('devices')
            .orderBy('lastLoginAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${localizations?.error ?? 'Error'}: ${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                localizations?.noDevicesLoggedIn ?? 'No devices logged in',
              ),
            );
          }

          // Filter out revoked devices
          final devices = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['revokedAt'] == null;
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final data = device.data() as Map<String, dynamic>;

              final deviceName = data['deviceName'] ?? 'Unknown Device';
              final platform = data['platform'] ?? 'Unknown';
              final deviceModel = data['deviceModel'] ?? '';
              final osVersion = data['osVersion'] ?? '';
              final lastLogin = data['lastLoginAt'] as Timestamp?;
              final firstLogin = data['firstLoginAt'] as Timestamp?;

              String lastLoginStr = 'Never';
              if (lastLogin != null) {
                final date = lastLogin.toDate();
                lastLoginStr = DateFormat(
                  'MMM dd, yyyy - hh:mm a',
                ).format(date);
              }

              String firstLoginStr = 'Unknown';
              if (firstLogin != null) {
                final date = firstLogin.toDate();
                firstLoginStr = DateFormat('MMM dd, yyyy').format(date);
              }

              IconData platformIcon;
              Color platformColor;

              switch (platform.toLowerCase()) {
                case 'android':
                  platformIcon = Icons.android;
                  platformColor = Colors.green;
                  break;
                case 'ios':
                  platformIcon = Icons.phone_iphone;
                  platformColor = Colors.blue;
                  break;
                case 'windows':
                  platformIcon = Icons.computer;
                  platformColor = Colors.blue[700]!;
                  break;
                case 'macos':
                  platformIcon = Icons.laptop_mac;
                  platformColor = Colors.grey[700]!;
                  break;
                case 'linux':
                  platformIcon = Icons.computer;
                  platformColor = Colors.orange;
                  break;
                case 'web':
                  platformIcon = Icons.web;
                  platformColor = Colors.purple;
                  break;
                default:
                  platformIcon = Icons.device_unknown;
                  platformColor = Colors.grey;
              }

              final storedDeviceId = (data['deviceId'] ?? '').toString();
              final isCurrent =
                  (_currentDeviceId.isNotEmpty &&
                      _currentDeviceId != 'unknown') &&
                  (device.id == _currentDeviceId ||
                      storedDeviceId == _currentDeviceId);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: platformColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(platformIcon, color: platformColor, size: 28),
                  ),
                  title: Text(
                    deviceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('$platform • $deviceModel'),
                      if (osVersion.isNotEmpty) Text(osVersion),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Last login: $lastLoginStr',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'First login: $firstLoginStr',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: isCurrent
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            localizations?.currentDevice ?? 'Current device',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red[600],
                          onPressed: () => _showRemoveConfirmation(
                            context,
                            device.id,
                            deviceName,
                          ),
                          tooltip: 'Remove device',
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
