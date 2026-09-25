import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashbill/services/app_currencies.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class CurrencyProvider with ChangeNotifier {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  String countryCode = '';
  String countryName = '';
  String currencyCode = '';
  String symbol = '';

  CurrencyProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
  }

  bool get isSet =>
      countryCode.trim().isNotEmpty && currencyCode.trim().isNotEmpty;

  String format(num amount, {int? decimals}) {
    final value = decimals != null
        ? amount.toStringAsFixed(decimals)
        : (amount is int || amount == amount.roundToDouble())
        ? amount.round().toString()
        : amount.toStringAsFixed(2);
    return '$symbol${_withCommas(value)}';
  }

  String _withCommas(String value) {
    final parts = value.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return parts.length == 1 ? whole : '$whole.${parts[1]}';
  }

  void applyProfile(Map<String, dynamic>? data) {
    final nextCountry = (data?['countryCode'] as String?)?.trim() ?? '';
    final nextName = (data?['countryName'] as String?)?.trim() ?? '';
    final nextCode = (data?['currencyCode'] as String?)?.trim() ?? '';
    final nextSymbol = (data?['currencySymbol'] as String?)?.trim() ?? '';
    final resolved = nextCode.isNotEmpty
        ? AppCurrencies.byCode(nextCode)
        : const AppCurrency(code: '', symbol: '', name: '');
    final country = nextCountry.isNotEmpty
        ? AppCurrencies.countryByCode(nextCountry)
        : null;

    countryCode = nextCountry;
    countryName = nextName.isNotEmpty ? nextName : (country?.name ?? '');
    currencyCode = nextCode;
    symbol = nextSymbol.isNotEmpty ? nextSymbol : resolved.symbol;
    notifyListeners();
  }

  void _onAuth(User? user) {
    _profileSub?.cancel();
    if (user == null) {
      applyProfile(null);
      return;
    }
    _profileSub = FirebaseFirestore.instance
        .collection('shop-profile')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) => applyProfile(snapshot.data()));
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

extension AppMoney on BuildContext {
  CurrencyProvider get currencies =>
      Provider.of<CurrencyProvider>(this, listen: true);

  CurrencyProvider get currenciesRead =>
      Provider.of<CurrencyProvider>(this, listen: false);

  String get currencySymbol => currencies.symbol;

  String money(num amount, {int? decimals}) =>
      currencies.format(amount, decimals: decimals);
}

int parseMoneyInt(String value) {
  final digits = value.replaceAll(RegExp(r'[^\d-]'), '');
  return int.tryParse(digits) ?? 0;
}

double parseMoneyDouble(String value) {
  final normalized = value.replaceAll(RegExp(r'[^\d.-]'), '');
  return double.tryParse(normalized) ?? 0;
}
