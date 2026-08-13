import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform, File;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flashbill/utils/device_utils.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Callback for handling notification navigation
  void Function(Map<String, dynamic> data)? _onNotificationOpened;

  // Set the navigation callback
  void setOnNotificationOpened(
    void Function(Map<String, dynamic> data) callback,
  ) {
    _onNotificationOpened = callback;
  }

  Future<void> initialize() async {
    if (Platform.isWindows) return; // Skip for Windows

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);

    // Set up listeners without requesting permission yet
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // Show local notification with image support
        await _showLocalNotification(message);
      }
    });

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked!');
      if (_onNotificationOpened != null) {
        _onNotificationOpened!(message.data);
      }
    });

    // When FCM rotates the token (e.g. app reinstall, token expiry),
    // update the stored token so this device keeps receiving notifications.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('FCM token refreshed — updating Firestore: $newToken');
      await _saveTokenToFirestore(newToken);
    });
  }

  Future<void> requestPermission() async {
    if (Platform.isWindows) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Get token after permission
    final fCMToken = await messaging.getToken();
    print('FCM Token: $fCMToken');

    // Note: Token is saved to Firestore only on login, not here
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get device ID and name for unique token storage
        final deviceId = await DeviceUtils.getDeviceId();
        final deviceInfo = await DeviceUtils.getDeviceInfo();
        final docId = '${user.uid}_$deviceId'; // Combine userId and deviceId

        // Remove this token from any OTHER user's documents first
        // (same device can only belong to one user at a time)
        final existing = await FirebaseFirestore.instance
            .collection('users-fcm-tokens')
            .where('token', isEqualTo: token)
            .get();
        for (final doc in existing.docs) {
          if (doc.data()['userId'] != user.uid) {
            await doc.reference.delete();
            print('Removed stale token from another user: ${doc.id}');
          }
        }

        await FirebaseFirestore.instance
            .collection('users-fcm-tokens')
            .doc(docId)
            .set({
              'userId': user.uid,
              'token': token,
              'deviceId': deviceId,
              'deviceName': deviceInfo['deviceName'] ?? 'Unknown Device',
              'deviceModel': deviceInfo['deviceModel'] ?? '',
              'platform': Platform.isAndroid
                  ? 'android'
                  : Platform.isIOS
                  ? 'ios'
                  : 'other',
              'updatedAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        print('FCM Token saved to Firestore for device: $deviceId');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Call this on logout to stop receiving notifications for this user
  Future<void> removeTokenFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final deviceId = await DeviceUtils.getDeviceId();
      final docId = '${user.uid}_$deviceId';
      await FirebaseFirestore.instance
          .collection('users-fcm-tokens')
          .doc(docId)
          .delete();
      print('FCM Token removed from Firestore on logout');
    } catch (e) {
      print('Error removing FCM token on logout: $e');
    }
  }

  // Get all FCM tokens for a user (for sending notifications to all devices)
  static Future<List<String>> getUserTokens(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users-fcm-tokens')
          .where('userId', isEqualTo: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data()['token'] as String)
          .where((token) => token.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error getting user tokens: $e');
      return [];
    }
  }

  // Example: Send notification to all user's devices (call this from your server/backend)
  // This is a utility method showing how to use the tokens
  static Future<void> sendNotificationToUser(
    String userId,
    String title,
    String body, {
    Map<String, dynamic>? data,
  }) async {
    final tokens = await getUserTokens(userId);

    if (tokens.isEmpty) {
      print('No FCM tokens found for user: $userId');
      return;
    }

    // Here you would call your backend API to send FCM messages
    // Example payload for FCM:
    /*
    {
      "registration_ids": tokens,  // Send to all user's devices
      "notification": {
        "title": title,
        "body": body
      },
      "data": data ?? {}
    }
    */

    print('Found ${tokens.length} device(s) for user $userId');
    print('Tokens: $tokens');
    // In production, send this to your FCM server
  }

  Future<String?> getToken() async {
    if (Platform.isWindows) return null;
    return await FirebaseMessaging.instance.getToken();
  }

  // Save current FCM token to Firestore (for login)
  Future<void> saveTokenToFirestore() async {
    final token = await getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification!;
    final imageUrl = message.data['imageUrl'];
    final notifId = DateTime.now().millisecondsSinceEpoch % 100000;

    AndroidNotificationDetails androidDetails;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final imagePath = await _downloadAndSaveImage(
          imageUrl,
          'notification_$notifId',
        );
        final bigPictureStyle = BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath),
          largeIcon: FilePathAndroidBitmap(imagePath),
          contentTitle: notification.title,
          summaryText: notification.body,
          htmlFormatContentTitle: false,
          htmlFormatSummaryText: false,
        );
        androidDetails = AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          styleInformation: bigPictureStyle,
          largeIcon: FilePathAndroidBitmap(imagePath),
        );
      } catch (e) {
        print('Error loading notification image: $e');
        androidDetails = const AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        );
      }
    } else {
      androidDetails = const AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      );
    }

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      notifId,
      notification.title,
      notification.body,
      details,
    );
  }

  Future<String> _downloadAndSaveImage(String url, String fileName) async {
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName.jpg';
    final file = File(filePath);
    if (await file.exists()) return filePath;
    final response = await http.get(Uri.parse(url));
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }
}
