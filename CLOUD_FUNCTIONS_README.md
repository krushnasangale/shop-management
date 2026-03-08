# Firebase Cloud Functions - Automated Daily Notifications

## 🎯 What This Does
- **Daily 9:30 AM IST**: Sends good morning messages to all users
- **🟡 Order Soon Alerts**: When products have ≤5 units (but >0)
- **🔴 Order Now Alerts**: When products have 0 units (out of stock)
- **Multi-device Support**: Sends to all user's registered devices

## � Alert Types

### 🟡 Order Soon (Quantity ≤ 5, but > 0)
- **Trigger**: When product quantity drops to 5 or below
- **Message**: "🟡 Order Soon Alert"
- **Purpose**: Early warning to restock before running out

### 🔴 Order Now (Quantity = 0)
- **Trigger**: When product quantity reaches exactly 0
- **Message**: "🔴 Order Now Alert"
- **Purpose**: Immediate action required - completely out of stock

## �🚀 Quick Deploy
```bash
# 1. Install dependencies
cd functions && npm install

# 2. Deploy functions
firebase deploy --only functions
```

## 🧪 Testing
```dart
// In your Flutter app
import 'package:cloud_functions/cloud_functions.dart';

final functions = FirebaseFunctions.instance;

// Test good morning
await functions.httpsCallable('sendTestNotification').call({
  'userId': 'your-user-id',
  'type': 'good_morning'
});

// Test low stock
await functions.httpsCallable('sendTestNotification').call({
  'userId': 'your-user-id',
  'type': 'low_stock'
});
```

## 📊 Cost: FREE (within Firebase limits)

## 🔧 Configuration
- **Schedule**: 9:30 AM IST daily (3:00 AM UTC)
- **Low Stock Threshold**: 5 units
- **Timezone**: Asia/Kolkata

## 📋 Files Structure
```
functions/
├── index.js          # Main functions code
├── package.json      # Dependencies
└── node_modules/     # Auto-generated
```

## 🎉 Status: ✅ DEPLOYED & ACTIVE