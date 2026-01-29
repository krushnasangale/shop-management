import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized service for managing bills data to reduce Firestore reads
class BillsDataService {
  final StreamController<List<Map<String, dynamic>>> _billsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _billsSubscription;
  List<Map<String, dynamic>> _cachedBills = [];

  /// Stream of bills data - all dashboard calculations should listen to this
  Stream<List<Map<String, dynamic>>> get billsStream => _billsController.stream;

  /// Get cached bills data (synchronous)
  List<Map<String, dynamic>> getCachedBills() => _cachedBills;

  /// Initialize the service with a user ID
  void initialize(String userId) {
    // Cancel any existing subscription
    _billsSubscription?.cancel();

    // Set up single stream listener for bills collection
    _billsSubscription = FirebaseFirestore.instance
        .collection('bills')
        .doc(userId)
        .collection('items')
        .snapshots()
        .listen(
          (snapshot) {
            _cachedBills = snapshot.docs
                .map(
                  (doc) => doc.data()..['id'] = doc.id,
                ) // Add document ID to data
                .toList();
            _billsController.add(_cachedBills);
          },
          onError: (error) {
            print('Error in bills stream: $error');
          },
        );
  }

  /// Clean up resources
  void dispose() {
    _billsSubscription?.cancel();
    _billsController.close();
  }
}
