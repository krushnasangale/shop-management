import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/services/profile_service.dart';
import 'package:flashbill/utils/app_logger.dart';
import 'package:material_ui/material_ui.dart';

/// Tracks shop subscription expiry from `shop-profile.subscriptionExpiry`.
///
/// When expired, the app stays readable but write actions should be blocked
/// via [SubscriptionGuard].
class SubscriptionProvider with ChangeNotifier {
  final ProfileService _profileService = ProfileService();
  StreamSubscription<Map<String, dynamic>>? _profileSubscription;
  String? _listeningUid;

  DateTime? _expiryDate;
  bool _loaded = false;

  DateTime? get expiryDate => _expiryDate;
  bool get isLoaded => _loaded;

  /// True when today is after the expiry calendar day.
  /// Missing expiry date = not expired (legacy shops stay writable).
  bool get isExpired {
    if (_expiryDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      _expiryDate!.year,
      _expiryDate!.month,
      _expiryDate!.day,
    );
    return today.isAfter(expiry);
  }

  bool get canWrite => !isExpired;

  void start() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      stop();
      return;
    }
    if (_listeningUid == user.uid && _profileSubscription != null) return;

    _profileSubscription?.cancel();
    _listeningUid = user.uid;
    _profileService.initialize(user.uid);
    _profileSubscription = _profileService.profileStream.listen(
      _onProfile,
      onError: (error) => appLog('Subscription profile stream error: $error'),
    );

    final cached = _profileService.getCachedProfileData();
    if (cached != null) {
      _onProfile(cached);
    }
  }

  void stop() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _listeningUid = null;
    _expiryDate = null;
    _loaded = false;
    notifyListeners();
  }

  void _onProfile(Map<String, dynamic> profile) {
    final next = _parseExpiry(profile['subscriptionExpiry']);
    final changed = next != _expiryDate || !_loaded;
    _expiryDate = next;
    _loaded = true;
    if (changed) notifyListeners();
  }

  static DateTime? _parseExpiry(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'not set') return null;
      try {
        return DateTime.parse(trimmed);
      } catch (_) {
        try {
          // dd/MM/yyyy shown on profile
          final parts = trimmed.split('/');
          if (parts.length == 3) {
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (_) {}
      }
    }
    return null;
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _profileService.dispose();
    super.dispose();
  }
}
