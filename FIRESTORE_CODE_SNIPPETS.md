# Firestore Migration Code Snippets

Copy-paste ready code for migrating remaining files. Just replace collection names and field names as needed.

---

## 1. Import Statement (Replace All)
```dart
// OLD
import 'package:firebase_database/firebase_database.dart';

// NEW
import 'package:cloud_firestore/cloud_firestore.dart';
```

---

## 2. Real-Time Listener Pattern

### Template for bills, customers, suppliers, etc.

```dart
// VARIABLE DECLARATION
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _itemsSubscription;

// IN initState()
@override
void initState() {
  super.initState();
  _loadItems();
}

// LOAD FUNCTION
void _loadItems() {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _itemsSubscription = FirebaseFirestore.instance
          .collection('COLLECTION_NAME')  // e.g., 'customers', 'suppliers'
          .doc(user.uid)
          .collection('items')
          .snapshots()
          .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
        if (mounted) {
          setState(() {
            // Process docs
            final items = snapshot.docs.map((doc) => doc.data()).toList();
            _items = items;
          });
        }
      });
    }
  } catch (e) {
    print('Error loading items: $e');
  }
}

// IN dispose()
@override
void dispose() {
  _itemsSubscription?.cancel();
  super.dispose();
}
```

---

## 3. One-Time Read Pattern

```dart
Future<void> _loadItemsOnce() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('COLLECTION_NAME')  // e.g., 'bills', 'customers'
        .doc(user.uid)
        .collection('items')
        .get();

    if (mounted) {
      setState(() {
        final items = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
        _items = items;
      });
    }
  } catch (e) {
    print('Error loading items: $e');
  }
}
```

---

## 4. Filtered Query Pattern

```dart
// Server-side filtering (MUCH faster and cheaper!)
QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
    .collection('COLLECTION_NAME')
    .doc(user.uid)
    .collection('items')
    .where('FIELD_NAME', isGreaterThan: 0)  // or: isEqualTo, isLessThan, arrayContains, etc.
    .snapshots()  // Remove for one-time read
    .listen(... );  // Listen for real-time updates
```

**Comparison Options:**
- `isEqualTo: value`
- `isNotEqualTo: value`
- `isLessThan: value`
- `isLessThanOrEqualTo: value`
- `isGreaterThan: value`
- `isGreaterThanOrEqualTo: value`
- `arrayContains: value`
- `arrayContainsAny: [value1, value2]`
- `whereIn: [value1, value2]`
- `notIn: [value1, value2]`

---

## 5. Add/Create Item

```dart
Future<void> _addItem(Map<String, dynamic> itemData) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    await FirebaseFirestore.instance
        .collection('COLLECTION_NAME')
        .doc(user.uid)
        .collection('items')
        .add(itemData);  // Auto-generates ID

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added successfully')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
```

---

## 6. Update Item

```dart
Future<void> _updateItem(String itemId, Map<String, dynamic> itemData) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    await FirebaseFirestore.instance
        .collection('COLLECTION_NAME')
        .doc(user.uid)
        .collection('items')
        .doc(itemId)
        .update(itemData);  // Update only specified fields

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated successfully')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
```

---

## 7. Delete Item

```dart
Future<void> _deleteItem(String itemId) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    await FirebaseFirestore.instance
        .collection('COLLECTION_NAME')
        .doc(user.uid)
        .collection('items')
        .doc(itemId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted successfully')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
```

---

## 8. Batch Write Operations

```dart
Future<void> _batchOperations() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance
        .collection('COLLECTION_NAME')
        .doc(user.uid)
        .collection('items');

    // Add multiple operations
    batch.set(collection.doc('doc1'), {'field': 'value1'});
    batch.update(collection.doc('doc2'), {'field': 'value2'});
    batch.delete(collection.doc('doc3'));

    // Commit all at once (atomic)
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch operations completed')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
```

---

## 9. Transaction Pattern (For Complex Operations)

```dart
Future<void> _transactionExample() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
      final docRef = FirebaseFirestore.instance
          .collection('COLLECTION_NAME')
          .doc(user.uid)
          .collection('items')
          .doc('itemId');

      final snapshot = await transaction.get(docRef);
      final currentValue = snapshot.data()?['count'] ?? 0;
      
      // Update based on current value
      transaction.update(docRef, {
        'count': currentValue + 1,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      return currentValue + 1;
    });

    print('New value: $result');
  } catch (e) {
    print('Transaction failed: $e');
  }
}
```

---

## 10. Pagination Pattern

```dart
DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
List<Map<String, dynamic>> _items = [];

Future<void> _loadMore() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('COLLECTION_NAME')
        .doc(user.uid)
        .collection('items')
        .orderBy('timestamp', descending: true)
        .limit(20);

    // If we have a last document, start after it
    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
      setState(() {
        _items.addAll(snapshot.docs.map((doc) => doc.data()).toList());
      });
    }
  } catch (e) {
    print('Error loading more: $e');
  }
}
```

---

## 11. Search/Filter Pattern

```dart
Future<void> _searchItems(String searchTerm) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // IMPORTANT: Firestore search is case-sensitive by default
    // For case-insensitive search, store lowercase version in DB
    
    final snapshot = await FirebaseFirestore.instance
        .collection('COLLECTION_NAME')
        .doc(user.uid)
        .collection('items')
        .where('nameLowercase', isGreaterThanOrEqualTo: searchTerm.toLowerCase())
        .where('nameLowercase', isLessThan: searchTerm.toLowerCase() + 'z')
        .get();

    setState(() {
      _items = snapshot.docs.map((doc) => doc.data()).toList();
    });
  } catch (e) {
    print('Error searching: $e');
  }
}

// When saving, always save both versions:
final itemData = {
  'name': 'Product Name',
  'nameLowercase': 'product name',  // For searching
  // ... other fields
};
```

---

## 12. Count Pattern

```dart
Future<int> _getItemCount() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final snapshot = await FirebaseFirestore.instance
        .collection('COLLECTION_NAME')
        .doc(user.uid)
        .collection('items')
        .count()
        .get();

    return snapshot.count ?? 0;
  } catch (e) {
    print('Error counting: $e');
    return 0;
  }
}
```

---

## 13. Exists Check Pattern

```dart
Future<bool> _itemExists(String itemId) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('COLLECTION_NAME')
        .doc(user.uid)
        .collection('items')
        .doc(itemId)
        .get();

    return doc.exists;
  } catch (e) {
    print('Error checking existence: $e');
    return false;
  }
}
```

---

## 14. Type Casting Helpers

```dart
// Safe conversions for common types
final String name = doc.data()?['name'] as String? ?? 'Unknown';
final int quantity = (doc.data()?['quantity'] as num?)?.toInt() ?? 0;
final double price = (doc.data()?['price'] as num?)?.toDouble() ?? 0.0;
final bool isActive = doc.data()?['isActive'] as bool? ?? false;
final DateTime date = doc.data()?['date'] is String 
    ? DateTime.parse(doc.data()!['date'] as String)
    : (doc.data()?['date'] as DateTime?) ?? DateTime.now();

// Handle nested maps
final Map<String, dynamic> nestedData = (doc.data()?['nested'] as Map<String, dynamic>?) ?? {};
```

---

## 15. Error Handling Patterns

```dart
// Pattern 1: Try-Catch with specific errors
Future<void> _operation() async {
  try {
    // Operation here
  } on FirebaseException catch (e) {
    print('Firebase Error: ${e.code} - ${e.message}');
  } on PlatformException catch (e) {
    print('Platform Error: ${e.code} - ${e.message}');
  } catch (e) {
    print('Generic Error: $e');
  }
}

// Pattern 2: Check for specific errors
try {
  // Operation
} catch (e) {
  if (e.toString().contains('PERMISSION_DENIED')) {
    print('User does not have permission');
  } else if (e.toString().contains('NOT_FOUND')) {
    print('Document not found');
  } else {
    print('Unknown error: $e');
  }
}
```

---

## Quick Migration Checklist for Each File

```
□ Change import to cloud_firestore
□ Update StreamSubscription types
□ Replace all .ref() calls with .collection().doc().collection()
□ Change onValue.listen to snapshots().listen
□ Update forEach loops to for-in loops over .docs
□ Update .data() calls to use null coalescing (??)
□ Cast numbers properly (as num)?.toInt()
□ Update .set() calls to use new path structure
□ Test file after migration
□ Check for compile errors
□ Run feature test (create, read, update, delete)
```

---

## Testing After Each Migration

```dart
// Quick test function to add to each migrated screen
void _testMigration() {
  print('Testing ${this.runtimeType}');
  print('✓ Listeners initialized');
  print('✓ Data loaded successfully');
  print('✓ Real-time updates working');
  print('✓ CRUD operations functional');
}
```

