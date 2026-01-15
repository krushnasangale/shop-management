class UserModel {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String accessLevel; // 'admin' or 'user'
  final bool isActive;
  final DateTime createdAt;
  final SubscriptionModel? subscription;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.phone,
    this.accessLevel = 'user',
    this.isActive = true,
    required this.createdAt,
    this.subscription,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'accessLevel': accessLevel,
      'isActive': isActive,
      'createdAt': createdAt,
      'subscription': subscription?.toMap(),
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime parseCreatedAt(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      // Handle Firestore Timestamp
      if (value.toString().contains('Timestamp')) {
        try {
          return (value as dynamic).toDate();
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      accessLevel: map['accessLevel'] ?? 'user',
      isActive: map['isActive'] ?? true,
      createdAt: parseCreatedAt(map['createdAt']),
      subscription: map['subscription'] != null
          ? SubscriptionModel.fromMap(map['subscription'])
          : null,
    );
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? phone,
    String? accessLevel,
    bool? isActive,
    DateTime? createdAt,
    SubscriptionModel? subscription,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      accessLevel: accessLevel ?? this.accessLevel,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      subscription: subscription ?? this.subscription,
    );
  }
}

class SubscriptionModel {
  final String planType; // 'free', 'basic', 'premium'
  final bool isActive;
  final DateTime startDate;
  final DateTime expiryDate;
  final String? paymentId;
  final double amount;

  SubscriptionModel({
    required this.planType,
    required this.isActive,
    required this.startDate,
    required this.expiryDate,
    this.paymentId,
    this.amount = 0.0,
  });

  // Get subscription status
  bool get isExpired => DateTime.now().isAfter(expiryDate);
  
  // Get days remaining
  int get daysRemaining {
    if (isExpired) return 0;
    return expiryDate.difference(DateTime.now()).inDays;
  }

  // Convert to JSON for Firestore
  Map<String, dynamic> toMap() {
    return {
      'planType': planType,
      'isActive': isActive && !isExpired,
      'startDate': startDate,
      'expiryDate': expiryDate,
      'paymentId': paymentId,
      'amount': amount,
    };
  }

  // Create from Firestore document
  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      // Handle Firestore Timestamp
      if (value.toString().contains('Timestamp')) {
        try {
          return (value as dynamic).toDate();
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    final expiryDate = parseDate(map['expiryDate']);
    
    return SubscriptionModel(
      planType: map['planType'] ?? 'free',
      isActive: (map['isActive'] ?? false) && !DateTime.now().isAfter(expiryDate),
      startDate: parseDate(map['startDate']),
      expiryDate: expiryDate,
      paymentId: map['paymentId'],
      amount: (map['amount'] ?? 0.0).toDouble(),
    );
  }

  // Create a copy with updated fields
  SubscriptionModel copyWith({
    String? planType,
    bool? isActive,
    DateTime? startDate,
    DateTime? expiryDate,
    String? paymentId,
    double? amount,
  }) {
    return SubscriptionModel(
      planType: planType ?? this.planType,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      paymentId: paymentId ?? this.paymentId,
      amount: amount ?? this.amount,
    );
  }
}

// Subscription plans configuration
class SubscriptionPlan {
  final String type; // 'free', 'basic', 'premium'
  final String displayName;
  final String description;
  final double price;
  final int durationDays;
  final List<String> features;

  const SubscriptionPlan({
    required this.type,
    required this.displayName,
    required this.description,
    required this.price,
    required this.durationDays,
    required this.features,
  });

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      type: 'free',
      displayName: 'Free',
      description: 'Basic features',
      price: 0.0,
      durationDays: 0, // No expiry
      features: [
        'Create up to 10 bills',
        'Basic reporting',
        'Customer management',
        'Limited support',
      ],
    ),
    SubscriptionPlan(
      type: 'basic',
      displayName: 'Basic',
      description: 'For small shops',
      price: 299.0,
      durationDays: 30,
      features: [
        'Unlimited bills',
        'Advanced reporting',
        'Customer & product management',
        'Payment tracking',
        'Email support',
      ],
    ),
    SubscriptionPlan(
      type: 'premium',
      displayName: 'Premium',
      description: 'For growing businesses',
      price: 599.0,
      durationDays: 30,
      features: [
        'All Basic features',
        'Advanced analytics',
        'Multi-user support',
        'API access',
        'Priority support',
        'Custom branding',
      ],
    ),
  ];

  static SubscriptionPlan? getPlanByType(String type) {
    try {
      return plans.firstWhere((plan) => plan.type == type);
    } catch (e) {
      return null;
    }
  }
}
