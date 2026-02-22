import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

class DeviceUtils {
  static Future<String> getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return windowsInfo.deviceId;
      } else {
        return 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      return 'error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = '';
      String deviceName = '';
      String deviceModel = '';
      String osVersion = '';
      String platform = '';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceName = androidInfo.model;
        deviceModel = androidInfo.device;
        osVersion = 'Android ${androidInfo.version.release}';
        platform = 'Android';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        deviceName = iosInfo.name;
        deviceModel = iosInfo.model;
        osVersion = 'iOS ${iosInfo.systemVersion}';
        platform = 'iOS';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
        deviceName = windowsInfo.computerName;
        deviceModel = 'Windows PC';
        osVersion = windowsInfo.productName;
        platform = 'Windows';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceId = macInfo.systemGUID ?? 'unknown';
        deviceName = macInfo.computerName;
        deviceModel = macInfo.model;
        osVersion = 'macOS ${macInfo.osRelease}';
        platform = 'macOS';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceId = linuxInfo.machineId ?? 'unknown';
        deviceName = linuxInfo.name;
        deviceModel = linuxInfo.prettyName;
        osVersion = linuxInfo.version ?? 'unknown';
        platform = 'Linux';
      } else {
        // Web or other platforms
        platform = 'Web';
        deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
        deviceName = 'Web Browser';
        deviceModel = 'Browser';
        osVersion = 'Web';
      }

      return {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'deviceModel': deviceModel,
        'platform': platform,
        'osVersion': osVersion,
      };
    } catch (e) {
      return {
        'deviceId': 'error_${DateTime.now().millisecondsSinceEpoch}',
        'deviceName': 'Unknown Device',
        'deviceModel': 'Unknown Model',
        'platform': 'Unknown',
        'osVersion': 'Unknown',
      };
    }
  }
}
