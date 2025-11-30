# Firestore Migration Guide

## Migration Status
- ✅ Pubspec.yaml updated with cloud_firestore ^6.1.0
- ✅ Firestore security rules created
- ✅ main.dart migrated
- ✅ dashboard.dart migrated
- ✅ my_profile.dart migrated
- ⏳ Remaining files to migrate: 17 files

## Database Path Mapping (Realtime → Firestore)

### Single Value Fields
| Old Path | New Path | Collection Structure |
|----------|----------|---------------------|
| `shop-profile/{userId}/shopName` | `shop-profile/{userId}` → `shopName` field | Document |
| `shop-profile/{userId}/...` | `shop-profile/{userId}` → All fields in document | Document |

### Collections with Subcollections
| Old Path | New Path | Collection Structure |
|----------|----------|---------------------|
| `bills/{userId}/{billId}` | `bills/{userId}/items/{billId}` | Subcollection |
| `purchases/{userId}/{purchaseId}` | `purchases/{userId}/items/{purchaseId}` | Subcollection |
| `purchased-products/{userId}/{productId}` | `purchased-products/{userId}/items/{productId}` | Subcollection |
| `customers/{userId}/{customerId}` | `customers/{userId}/items/{customerId}` | Subcollection |
| `units/{userId}/items/{unitId}` | `units/{userId}/items/{unitId}` | Subcollection (no change needed) |
| `suppliers/{userId}/{supplierId}` | `suppliers/{userId}/items/{supplierId}` | Subcollection |
| `product-names/{userId}/{productId}` | `product-names/{userId}/items/{productId}` | Subcollection |
| `product-purchase-history/{userId}/{historyId}` | `product-purchase-history/{userId}/items/{historyId}` | Subcollection |

## Code Migration Patterns

### Pattern 1: Simple Listener (Old → New)

**Before (Realtime Database):**
```dart
import 'package:firebase_database/firebase_database.dart';

StreamSubscription<DatabaseEvent>? _subscription;

void _listen() {
  _subscription = FirebaseDatabase.instance
      .ref('shop-profile/${user.uid}/shopName')
      .onValue
      .listen((DatabaseEvent event) {
        if (event.snapshot.exists) {
          final value = event.snapshot.value as String?;
        }
      });
}

@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

**After (Firestore):**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

void _listen() {
  _subscription = FirebaseFirestore.instance
      .collection('shop-profile')
      .doc(user.uid)
      .snapshots()
      .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.exists) {
          final value = snapshot.data()?['shopName'] as String?;
        }
      });
}

@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

### Pattern 2: Collection Listener

**Before (Realtime Database):**
```dart
final billsRef = FirebaseDatabase.instance.ref('bills/$userId');
billsRef.onValue.listen((event) {
  if (event.snapshot.exists) {
    final data = event.snapshot.value as Map<dynamic, dynamic>;
    data.forEach((key, value) {
      // Process each bill
    });
  }
});
```

**After (Firestore):**
```dart
FirebaseFirestore.instance
    .collection('bills')
    .doc(userId)
    .collection('items')
    .snapshots()
    .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (var doc in snapshot.docs) {
        final billData = doc.data();
        // Process each bill
      }
    });
```

### Pattern 3: One-time Read

**Before (Realtime Database):**
```dart
final snapshot = await FirebaseDatabase.instance.ref('bills/$userId').get();
if (snapshot.exists) {
  final data = snapshot.value as Map<dynamic, dynamic>;
  data.forEach((key, value) { ... });
}
```

**After (Firestore):**
```dart
final snapshot = await FirebaseFirestore.instance
    .collection('bills')
    .doc(userId)
    .collection('items')
    .get();
for (var doc in snapshot.docs) {
  final data = doc.data();
  ...
}
```

### Pattern 4: Query with Filter

**Before (Realtime Database - manual filtering):**
```dart
final snapshot = await database.ref('purchased-products/$userId').get();
if (snapshot.exists) {
  final data = snapshot.value as Map<dynamic, dynamic>;
  data.forEach((key, value) {
    if (value is Map) {
      final quantity = value['quantity'] as int? ?? 0;
      if (quantity > 0) { // Manual filter
        count++;
      }
    }
  });
}
```

**After (Firestore - server-side filtering):**
```dart
final snapshot = await FirebaseFirestore.instance
    .collection('purchased-products')
    .doc(userId)
    .collection('items')
    .where('quantity', isGreaterThan: 0) // Server-side filter
    .get();
count = snapshot.size; // Direct count
```

### Pattern 5: Write/Update

**Before (Realtime Database):**
```dart
await FirebaseDatabase.instance
    .ref('customers/$userId/$customerId')
    .set(customerData);
```

**After (Firestore):**
```dart
await FirebaseFirestore.instance
    .collection('customers')
    .doc(userId)
    .collection('items')
    .doc(customerId)
    .set(customerData);
```

## Files to Migrate (Priority Order)

### High Priority (Core Features)
1. ✅ lib/main.dart
2. ✅ lib/pages/dashboard.dart
3. ✅ lib/pages/profile/my_profile.dart
4. lib/pages/billing/bills.dart
5. lib/pages/profile/edit_profile.dart
6. lib/pages/profile/customer/customers.dart

### Medium Priority
7. lib/pages/billing/create_new_bill.dart
8. lib/pages/purchase/add_purchase_entry.dart
9. lib/pages/products/available_products.dart
10. lib/pages/profile/products/product.dart
11. lib/pages/profile/units/units.dart
12. lib/pages/profile/supplier/suppliers.dart

### Lower Priority (Detail/History Views)
13. lib/pages/products/available_product_item_detail.dart
14. lib/pages/billing/bill_success_page.dart
15. lib/pages/billing/review_billing_details.dart
16. lib/pages/billing/view_existing_bill_details.dart
17. lib/pages/purchase/purchase_items_list.dart
18. lib/pages/purchase/purchase_entry_details.dart
19. lib/pages/profile/customer/customer_history.dart
20. lib/pages/profile/supplier/supplier_history.dart

## Key Differences to Remember

1. **Type Changes:**
   - `DatabaseEvent` → `DocumentSnapshot` or `QuerySnapshot`
   - `Map<dynamic, dynamic>` → `Map<String, dynamic>`
   - `onValue` → `snapshots()`

2. **Accessing Data:**
   - Realtime: `event.snapshot.value as Type`
   - Firestore: `snapshot.data()` or `doc.data()`

3. **Collection Access:**
   - Loop: `data.forEach((key, value)` → `for (var doc in snapshot.docs)`
   - Single doc: `ref('path/id')` → `collection().doc(id)`

4. **Advantages Gained:**
   - Server-side querying and filtering
   - Better offline support
   - Automatic indexing for common queries
   - Better cost efficiency for read/write patterns

## Next Steps

1. Migrate remaining high-priority files
2. Run comprehensive tests
3. Export old Realtime Database data (backup)
4. Deploy to Firebase
5. Verify all features work correctly
6. Consider keeping Realtime Database for a transition period

## Testing Checklist

- [ ] Shop name updates in real-time on AppBar
- [ ] Dashboard calculations are accurate
- [ ] Bills can be created and viewed
- [ ] Customer list loads and updates
- [ ] Products show correct quantities
- [ ] Suppliers and units can be managed
- [ ] Purchase entries work correctly
- [ ] Offline mode works (data syncs when online)
- [ ] Batch operations complete successfully
