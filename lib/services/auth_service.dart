import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/services/notification_service.dart';
import 'package:flashbill/utils/device_utils.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._();

  static bool isCancelled(Object error) {
    if (error is FirebaseAuthException) {
      final code = error.code.toLowerCase();
      return code.contains('cancel') ||
          code.contains('aborted') ||
          code == 'web-context-canceled';
    }
    final text = error.toString().toLowerCase();
    return text.contains('cancel') || text.contains('aborted');
  }

  static Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});

    if (kIsWeb) {
      return FirebaseAuth.instance.signInWithPopup(provider);
    }
    return FirebaseAuth.instance.signInWithProvider(provider);
  }

  static Future<bool> hasShopProfile(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shop-profile')
        .doc(userId)
        .get();
    if (!snapshot.exists) return false;
    final shopName = snapshot.data()?['shopName'];
    return shopName is String && shopName.trim().isNotEmpty;
  }

  static Future<void> ensureGoogleShopProfile(User user) async {
    if (await hasShopProfile(user.uid)) return;
    final email = (user.email ?? '').trim();
    final name = (user.displayName ?? '').trim();
    final fallbackName = name.isNotEmpty
        ? name
        : (email.contains('@') ? email.split('@').first : 'My Shop');
    await saveShopProfile(
      userId: user.uid,
      email: email,
      shopName: fallbackName,
      ownerName: name,
      ownerPhone: '',
      shopAddress: '',
      shopPhone: '',
      shopEmail: email,
      ownerSignature: '',
      authProvider: 'google',
    );
  }

  static Future<void> saveShopProfile({
    required String userId,
    required String email,
    required String shopName,
    required String ownerName,
    required String ownerPhone,
    required String shopAddress,
    required String shopPhone,
    required String shopEmail,
    required String ownerSignature,
    String countryCode = '',
    String countryName = '',
    String currencyCode = '',
    String currencySymbol = '',
    String authProvider = 'password',
  }) async {
    await FirebaseFirestore.instance.collection('shop-profile').doc(userId).set({
      'email': email,
      'shopName': shopName,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'shopAddress': shopAddress,
      'shopPhone': shopPhone,
      'shopEmail': shopEmail,
      'ownerSignature': ownerSignature,
      'countryCode': countryCode,
      'countryName': countryName,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'userType': 'user',
      'isActive': true,
      'authProvider': authProvider,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  static Future<void> trackDevice(String userId) async {
    try {
      final deviceInfo = await DeviceUtils.getDeviceInfo();
      await FirebaseFirestore.instance
          .collection('user-devices')
          .doc(userId)
          .collection('devices')
          .doc(deviceInfo['deviceId'])
          .set({
            'deviceId': deviceInfo['deviceId'],
            'deviceName': deviceInfo['deviceName'],
            'deviceModel': deviceInfo['deviceModel'],
            'platform': deviceInfo['platform'],
            'osVersion': deviceInfo['osVersion'],
            'lastLoginAt': FieldValue.serverTimestamp(),
            'firstLoginAt': FieldValue.serverTimestamp(),
            'revokedAt': FieldValue.delete(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error tracking device: $e');
    }
  }

  static Future<void> finishSignIn(String userId) async {
    await trackDevice(userId);
    if (!Platform.isWindows) {
      await NotificationService().saveTokenToFirestore();
    }
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
