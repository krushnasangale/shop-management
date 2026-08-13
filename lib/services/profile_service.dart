import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/utils/app_logger.dart';

/// Centralized service for managing profile-related data and operations
class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cached profile data - updated only by real-time stream
  Map<String, dynamic>? _cachedProfileData;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  // Stream controllers for different data types
  final StreamController<Map<String, dynamic>> _profileController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _appSettingsController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of complete profile data
  Stream<Map<String, dynamic>> get profileStream => _profileController.stream;

  /// Stream of app settings only
  Stream<Map<String, dynamic>> get appSettingsStream =>
      _appSettingsController.stream;

  /// Initialize the service with a user ID
  void initialize(String userId) {
    // Cancel any existing subscription
    _profileSubscription?.cancel();

    // Set up single stream listener for profile collection
    _profileSubscription = _firestore
        .collection('shop-profile')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              _cachedProfileData = snapshot.data() ?? {};
              _profileController.add(_cachedProfileData!);

              // Also emit app settings separately
              final appSettings =
                  _cachedProfileData!['appSettings'] as Map<String, dynamic>? ??
                  {};
              _appSettingsController.add(appSettings);
            } else {
              _cachedProfileData = {};
              _profileController.add({});
              _appSettingsController.add({});
            }
          },
          onError: (error) {
            appLog('Error in profile stream: $error');
          },
        );
  }

  /// Get cached profile data (synchronous)
  Map<String, dynamic>? getCachedProfileData() => _cachedProfileData;

  /// Get cached app settings (synchronous)
  Map<String, dynamic> getCachedAppSettings() {
    return _cachedProfileData?['appSettings'] as Map<String, dynamic>? ?? {};
  }

  /// Update shop profile data
  Future<void> updateProfileData(Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _firestore
          .collection('shop-profile')
          .doc(user.uid)
          .set(updates, SetOptions(merge: true));

      // Real-time stream will automatically update the cache
    } catch (e) {
      appLog('Error updating profile data: $e');
      rethrow;
    }
  }

  /// Update specific app setting
  Future<void> updateAppSetting(String key, dynamic value) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final docRef = _firestore.collection('shop-profile').doc(user.uid);

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
      appLog('Error updating app setting: $e');
      rethrow;
    }
  }

  /// Update multiple app settings at once
  Future<void> updateAppSettings(Map<String, dynamic> settings) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final docRef = _firestore.collection('shop-profile').doc(user.uid);

      // Get current data
      final snapshot = await docRef.get();
      final data = snapshot.data() ?? {};
      final currentAppSettings =
          data['appSettings'] as Map<String, dynamic>? ?? {};

      // Merge new settings with existing ones
      final updatedAppSettings = {...currentAppSettings, ...settings};

      // Save back
      await docRef.set({
        ...data,
        'appSettings': updatedAppSettings,
      }, SetOptions(merge: true));
    } catch (e) {
      appLog('Error updating app settings: $e');
      rethrow;
    }
  }

  /// Clear all caches (useful after logout or when forcing refresh)
  void clearCache() {
    _cachedProfileData = null;
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Always return real-time cached data - no API calls
      return _cachedProfileData;
    } catch (e) {
      appLog('Error getting current user profile: $e');
      rethrow;
    }
  }

  /// Get specific user's profile data (only works for current user)
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final currentUser = _auth.currentUser;

      // Only allow access to current user's profile
      if (currentUser == null || currentUser.uid != userId) {
        throw Exception('Access denied: Can only access current user profile');
      }

      // Return real-time cached data
      return _cachedProfileData;
    } catch (e) {
      appLog('Error getting user profile: $e');
      rethrow;
    }
  }

  /// Clean up resources
  void dispose() {
    _profileSubscription?.cancel();
    _profileController.close();
    _appSettingsController.close();
  }
}
