import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/models/user_model.dart';
import '../services/profile_service.dart';

class DashboardProvider with ChangeNotifier {
  int _totalUsers = 0;
  bool _isLoading = false;
  String? _error;
  List<UserModel> _usersList = [];
  bool _isCreatingUser = false;
  final ProfileService _profileService = ProfileService();

  int get totalUsers => _totalUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserModel> get usersList => _usersList;
  bool get isCreatingUser => _isCreatingUser;

  /// Fetch total count of users from Firebase Authentication
  Future<void> fetchTotalUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Only count current user since ProfileService is restricted to current user data
      _totalUsers = 1; // Current user only
      _usersList = []; // No admin access to other users

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error fetching users: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch list of all users with their details
  Future<void> fetchUsersList() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      _usersList = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();

      _totalUsers = _usersList.length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error fetching users list: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new user with Firebase Auth and add to Firestore
  Future<UserModel?> createUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String accessLevel, // 'admin' or 'user'
    required String planType, // 'free', 'basic', 'premium'
  }) async {
    _isCreatingUser = true;
    _error = null;
    notifyListeners();

    try {
      // Create user in Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final newUser = userCredential.user;
      if (newUser == null) {
        throw Exception('Failed to create user');
      }

      // Determine subscription details based on plan type
      final plan = SubscriptionPlan.getPlanByType(planType);
      if (plan == null) {
        throw Exception('Invalid subscription plan');
      }

      final now = DateTime.now();
      final expiryDate = planType == 'free'
          ? DateTime(2099, 12, 31) // No expiry for free plan
          : now.add(Duration(days: plan.durationDays));

      // Create subscription
      final subscription = SubscriptionModel(
        planType: planType,
        isActive: true,
        startDate: now,
        expiryDate: expiryDate,
        amount: plan.price,
      );

      // Create user document in Firestore
      final userModel = UserModel(
        uid: newUser.uid,
        email: email,
        name: name,
        phone: phone,
        accessLevel: accessLevel,
        isActive: true,
        createdAt: now,
        subscription: subscription,
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUser.uid)
          .set(userModel.toMap());

      // Also create shop-profile for the user (for app functionality)
      await FirebaseFirestore.instance
          .collection('shop-profile')
          .doc(newUser.uid)
          .set({
            'email': email,
            'shopName': name,
            'shopPhone': phone,
            'userType': 'user',
            'expiryDate': DateTime.now().add(const Duration(days: 30)),
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

      _isCreatingUser = false;
      await fetchUsersList(); // Refresh users list
      return userModel;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Error creating user';
      _isCreatingUser = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Error: $e';
      _isCreatingUser = false;
      notifyListeners();
      return null;
    }
  }

  /// Update user access level
  Future<bool> updateUserAccessLevel({
    required String uid,
    required String newAccessLevel,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'accessLevel': newAccessLevel,
      });

      // Update local list
      final index = _usersList.indexWhere((user) => user.uid == uid);
      if (index != -1) {
        _usersList[index] = _usersList[index].copyWith(
          accessLevel: newAccessLevel,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Error updating access level: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update user subscription
  Future<bool> updateUserSubscription({
    required String uid,
    required String planType,
  }) async {
    try {
      final plan = SubscriptionPlan.getPlanByType(planType);
      if (plan == null) {
        throw Exception('Invalid subscription plan');
      }

      final now = DateTime.now();
      final expiryDate = planType == 'free'
          ? DateTime(2099, 12, 31)
          : now.add(Duration(days: plan.durationDays));

      final subscription = SubscriptionModel(
        planType: planType,
        isActive: true,
        startDate: now,
        expiryDate: expiryDate,
        amount: plan.price,
      );

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'subscription': subscription.toMap(),
      });

      // Update local list
      final index = _usersList.indexWhere((user) => user.uid == uid);
      if (index != -1) {
        _usersList[index] = _usersList[index].copyWith(
          subscription: subscription,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Error updating subscription: $e';
      notifyListeners();
      return false;
    }
  }

  /// Deactivate user
  Future<bool> deactivateUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isActive': false,
      });

      // Update local list
      final index = _usersList.indexWhere((user) => user.uid == uid);
      if (index != -1) {
        _usersList[index] = _usersList[index].copyWith(isActive: false);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Error deactivating user: $e';
      notifyListeners();
      return false;
    }
  }

  /// Activate user
  Future<bool> activateUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isActive': true,
      });

      // Update local list
      final index = _usersList.indexWhere((user) => user.uid == uid);
      if (index != -1) {
        _usersList[index] = _usersList[index].copyWith(isActive: true);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Error activating user: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reset dashboard data
  void reset() {
    _totalUsers = 0;
    _isLoading = false;
    _error = null;
    _usersList = [];
    _isCreatingUser = false;
    notifyListeners();
  }

  /// Clean up resources
  @override
  void dispose() {
    _profileService.dispose();
    super.dispose();
  }
}
