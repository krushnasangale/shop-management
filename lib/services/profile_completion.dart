/// Shop-profile fields that count toward 100% completion.
/// Subscription expiry is intentionally excluded.
class ProfileCompletion {
  const ProfileCompletion({required this.filled, required this.total});

  final int filled;
  final int total;

  static const countedKeys = <String>[
    'shopName',
    'ownerName',
    'shopAddress',
    'shopPhone',
    'ownerSignature',
    'countryCode',
    'currencyCode',
  ];

  int get percent =>
      total == 0 ? 0 : ((filled / total) * 100).round().clamp(0, 100);

  bool get isComplete => total > 0 && filled >= total;

  factory ProfileCompletion.from(Map<String, dynamic>? data) {
    var filled = 0;
    for (final key in countedKeys) {
      final value = data?[key];
      if (value is String && value.trim().isNotEmpty) {
        filled++;
      }
    }
    return ProfileCompletion(filled: filled, total: countedKeys.length);
  }
}
