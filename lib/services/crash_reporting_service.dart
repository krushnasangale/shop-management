import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:flashbill/utils/device_utils.dart';

/// Reports crashes, uncaught exceptions, and recovered UI hangs to Firebase.
///
/// Native Android ANRs and iOS watchdog kills are collected by Crashlytics
/// automatically. Dart UI freezes are reported after the isolate recovers.
class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService instance = CrashReportingService._();

  static final NavigatorObserver navigatorObserver =
      _CrashlyticsNavigatorObserver();

  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  bool _enabled = false;
  StreamSubscription<User?>? _authSubscription;
  Timer? _hangTimer;
  DateTime _lastUiHeartbeat = DateTime.now();
  bool _hangInFlight = false;
  RawReceivePort? _isolateErrorPort;
  Trace? _appStartTrace;

  Future<void> initialize() async {
    if (!isSupported) {
      appLog('Crash reporting skipped: platform not supported');
      return;
    }

    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      _enabled = true;

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      _isolateErrorPort = RawReceivePort((dynamic pair) {
        final errorAndStack = pair as List<dynamic>;
        FirebaseCrashlytics.instance.recordError(
          errorAndStack.first,
          errorAndStack.last is StackTrace ? errorAndStack.last : null,
          fatal: true,
          reason: 'isolate_error',
        );
      });
      Isolate.current.addErrorListener(_isolateErrorPort!.sendPort);

      await FirebaseCrashlytics.instance.setCustomKey('debug', kDebugMode);
      await FirebaseCrashlytics.instance.setCustomKey(
        'platform',
        Platform.operatingSystem,
      );

      try {
        final deviceId = await DeviceUtils.getDeviceId();
        await FirebaseCrashlytics.instance.setCustomKey('device_id', deviceId);
      } catch (e) {
        appLog('Could not set Crashlytics device id: $e');
      }

      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        _syncUser,
      );

      _startHangDetector();
      await _startAppStartTrace();

      appLog('Crash reporting initialized');
    } catch (e, stack) {
      appLog('Failed to initialize crash reporting: $e', error: e, stackTrace: stack);
    }
  }

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, Object>? information,
  }) async {
    appLog(reason ?? error, error: error, stackTrace: stack);
    if (!_enabled) return;

    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
        information: information?.entries.map((e) => '${e.key}: ${e.value}') ??
            const [],
      );
    } catch (e) {
      appLog('Failed to record error with Crashlytics: $e');
    }
  }

  void log(String message) {
    appLog(message);
    if (!_enabled) return;
    FirebaseCrashlytics.instance.log(message);
  }

  void setCustomKey(String key, Object value) {
    if (!_enabled) return;
    FirebaseCrashlytics.instance.setCustomKey(key, value);
  }

  Future<void> markAppReady() async {
    if (_appStartTrace == null) return;
    try {
      await _appStartTrace!.stop();
    } catch (e) {
      appLog('Failed to stop app start trace: $e');
    } finally {
      _appStartTrace = null;
    }
  }

  void dispose() {
    _hangTimer?.cancel();
    _authSubscription?.cancel();
    _isolateErrorPort?.close();
  }

  void _syncUser(User? user) {
    if (!_enabled) return;
    if (user == null) {
      FirebaseCrashlytics.instance.setUserIdentifier('');
      return;
    }
    FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
  }

  Future<void> _startAppStartTrace() async {
    try {
      _appStartTrace = FirebasePerformance.instance.newTrace('app_start');
      await _appStartTrace!.start();
    } catch (e) {
      appLog('Failed to start performance trace: $e');
      _appStartTrace = null;
    }
  }

  /// Detects UI isolate freezes. Timers pause while the isolate is hung, so
  /// the next tick sees a wall-clock gap and reports a recovered hang.
  void _startHangDetector() {
    _lastUiHeartbeat = DateTime.now();
    _hangTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final gap = now.difference(_lastUiHeartbeat);
      const hangThreshold = Duration(seconds: 5);

      if (gap >= hangThreshold && !_hangInFlight) {
        _hangInFlight = true;
        unawaited(
          recordError(
            StateError('UI hang recovered after ${gap.inSeconds}s'),
            StackTrace.current,
            reason: 'ui_hang',
            information: {'duration_ms': gap.inMilliseconds},
          ),
        );
      } else if (gap < hangThreshold) {
        _hangInFlight = false;
      }

      _lastUiHeartbeat = now;
    });
  }
}

class _CrashlyticsNavigatorObserver extends NavigatorObserver {
  void _record(String action, Route<dynamic>? route) {
    final name = route?.settings.name ?? route?.runtimeType.toString();
    if (name == null || name.isEmpty) return;
    CrashReportingService.instance.log('$action: $name');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('push', route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('pop', route);
  }
}
