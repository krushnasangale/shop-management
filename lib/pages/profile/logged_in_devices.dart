import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/l10n/app_localizations.dart';
import 'package:flashbill/pages/login/login.dart';
import 'package:flashbill/services/notification_service.dart';
import 'package:flashbill/theme/adaptive.dart';
import 'package:flashbill/utils/device_utils.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

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
    final id = await DeviceUtils.getDeviceId();
    if (mounted) setState(() => _currentDeviceId = id);
  }

  Future<void> _removeDevice(String deviceId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('user-devices')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .update({'revokedAt': FieldValue.serverTimestamp()});

      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc?.deviceRemovedSuccessfully ??
                'Device removed and logged out successfully',
          ),
        ),
      );

      try {
        if (_currentDeviceId == deviceId) {
          await NotificationService().removeTokenFromFirestore();
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (_) {
        // ignore
      }
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc?.errorRemovingDevice ?? 'Error removing device'}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _confirmRemove(String deviceId, String deviceName) async {
    final loc = AppLocalizations.of(context);
    final title = loc?.removeDevice ?? 'Remove Device';
    final message =
        (loc?.removeDeviceFromLoggedIn ??
                'Remove "{deviceName}" from logged-in devices?')
            .replaceAll('{deviceName}', deviceName);

    final confirmed = Adaptive.isCupertino
        ? await showCupertinoDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return CupertinoAlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(loc?.cancel ?? 'Cancel'),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(loc?.delete ?? 'Remove'),
                  ),
                ],
              );
            },
          )
        : await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(loc?.cancel ?? 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: Text(loc?.delete ?? 'Remove'),
                  ),
                ],
              );
            },
          );

    if (confirmed == true) {
      await _removeDevice(deviceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc?.loggedInDevices ?? 'Logged In Devices';
    final user = FirebaseAuth.instance.currentUser;

    if (Adaptive.isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(title)),
        child: SafeArea(child: _buildBody(loc, user)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _buildBody(loc, user),
    );
  }

  Widget _buildBody(AppLocalizations? loc, User? user) {
    if (user == null) {
      return _EmptyState(
        icon: Icons.devices_outlined,
        message:
            loc?.pleaseLoginToViewDevices ?? 'Please login to view devices',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user-devices')
          .doc(user.uid)
          .collection('devices')
          .orderBy('lastLoginAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Adaptive.progress());
        }

        if (snapshot.hasError) {
          return _EmptyState(
            icon: Icons.error_outline,
            message: '${loc?.error ?? 'Error'}: ${snapshot.error}',
          );
        }

        final devices =
            snapshot.data?.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['revokedAt'] == null;
            }).toList() ??
            [];

        if (devices.isEmpty) {
          return _EmptyState(
            icon: Icons.devices_outlined,
            message: loc?.noDevicesLoggedIn ?? 'No devices logged in',
          );
        }

        final current = <QueryDocumentSnapshot>[];
        final others = <QueryDocumentSnapshot>[];
        for (final device in devices) {
          if (_isCurrent(device)) {
            current.add(device);
          } else {
            others.add(device);
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (current.isNotEmpty) ...[
              _sectionLabel('This device'),
              _DevicesGroup(
                children: [
                  for (final device in current)
                    _DeviceTile(
                      device: device,
                      isCurrent: true,
                      currentLabel: loc?.currentDevice ?? 'This device',
                    ),
                ],
              ),
              _sectionFooter('This is the device you are using now.'),
              const SizedBox(height: 20),
            ],
            if (others.isNotEmpty) ...[
              _sectionLabel('Other devices'),
              _DevicesGroup(
                children: [
                  for (final device in others)
                    _DeviceTile(
                      device: device,
                      isCurrent: false,
                      currentLabel: loc?.currentDevice ?? 'This device',
                      onRemove: () {
                        final data = device.data() as Map<String, dynamic>;
                        _confirmRemove(
                          device.id,
                          data['deviceName'] ?? 'Unknown Device',
                        );
                      },
                    ),
                ],
              ),
              _sectionFooter(
                'Removing a device will sign it out of this account.',
              ),
            ],
          ],
        );
      },
    );
  }

  bool _isCurrent(QueryDocumentSnapshot device) {
    final data = device.data() as Map<String, dynamic>;
    final storedDeviceId = (data['deviceId'] ?? '').toString();
    return (_currentDeviceId.isNotEmpty && _currentDeviceId != 'unknown') &&
        (device.id == _currentDeviceId || storedDeviceId == _currentDeviceId);
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

class _DevicesGroup extends StatelessWidget {
  const _DevicesGroup({required this.children});

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

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isCurrent,
    required this.currentLabel,
    this.onRemove,
  });

  final QueryDocumentSnapshot device;
  final bool isCurrent;
  final String currentLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = device.data() as Map<String, dynamic>;
    final deviceName = (data['deviceName'] ?? 'Unknown Device') as String;
    final platform = (data['platform'] ?? 'Unknown') as String;
    final deviceModel = (data['deviceModel'] ?? '') as String;
    final osVersion = (data['osVersion'] ?? '') as String;
    final lastLogin = data['lastLoginAt'] as Timestamp?;

    var lastLoginStr = 'Never';
    if (lastLogin != null) {
      lastLoginStr = DateFormat(
        'MMM dd, yyyy · hh:mm a',
      ).format(lastLogin.toDate());
    }

    final details = [
      platform,
      if (deviceModel.isNotEmpty) deviceModel,
      if (osVersion.isNotEmpty) osVersion,
    ].join('  ·  ');

    final leading = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: scheme.primaryContainer,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            _platformIcon(platform),
            size: 20,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
    final nameStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );
    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (details.isNotEmpty)
          Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(lastLoginStr, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
    final trailing = isCurrent
        ? Text(
            currentLabel,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          )
        : IconButton(
            icon: Icon(Icons.delete_outline, color: scheme.error),
            tooltip: 'Remove device',
            onPressed: onRemove,
          );

    if (Adaptive.isCupertino) {
      return CupertinoListTile(
        padding: const EdgeInsets.fromLTRB(16, 7, 12, 7),
        leading: leading,
        title: Text(deviceName, style: nameStyle),
        subtitle: subtitle,
        trailing: isCurrent
            ? trailing
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onRemove,
                child: Icon(
                  CupertinoIcons.delete,
                  color: CupertinoColors.destructiveRed,
                ),
              ),
      );
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 3, 12, 3),
      minVerticalPadding: 7,
      leading: leading,
      title: Text(
        deviceName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: nameStyle,
      ),
      subtitle: subtitle,
      trailing: trailing,
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'windows':
        return Icons.computer;
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.computer;
      case 'web':
        return Icons.language_outlined;
      default:
        return Icons.devices_outlined;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
