import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  late Map<String, String> _localizedStrings;

  AppLocalizations(this.locale);

  // Helper method to get the localized text
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  // Static member to have a simple access to the delegate
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Load the language JSON file from the "assets/languages" folder
  Future<bool> load() async {
    String jsonString = await rootBundle.loadString(
      'assets/languages/${locale.languageCode}.json',
    );
    Map<String, dynamic> jsonMap = json.decode(jsonString);

    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });

    return true;
  }

  // Called from every widget to get the translated text
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  // Common translations getters for easy access
  String get appName => translate('app_name');
  String get dashboard => translate('dashboard');
  String get bills => translate('bills');
  String get products => translate('products');
  String get purchases => translate('purchases');
  String get profile => translate('profile');
  String get settings => translate('settings');
  String get logout => translate('logout');
  String get login => translate('login');
  String get email => translate('email');
  String get password => translate('password');
  String get forgotPassword => translate('forgot_password');
  String get signUp => translate('sign_up');
  String get createAccount => translate('create_account');
  String get totalSales => translate('total_sales');
  String get totalPurchases => translate('total_purchases');
  String get totalProfit => translate('total_profit');
  String get lowStock => translate('low_stock');
  String get createBill => translate('create_bill');
  String get viewBills => translate('view_bills');
  String get addProduct => translate('add_product');
  String get productName => translate('product_name');
  String get quantity => translate('quantity');
  String get price => translate('price');
  String get buyingPrice => translate('buying_price');
  String get sellingPrice => translate('selling_price');
  String get save => translate('save');
  String get cancel => translate('cancel');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get search => translate('search');
  String get supplier => translate('supplier');
  String get customer => translate('customer');
  String get date => translate('date');
  String get total => translate('total');
  String get amount => translate('amount');
  String get unit => translate('unit');
  String get expiryDate => translate('expiry_date');
  String get addPurchase => translate('add_purchase');
  String get purchaseHistory => translate('purchase_history');
  String get salesHistory => translate('sales_history');
  String get viewDetails => translate('view_details');
  String get confirm => translate('confirm');
  String get yes => translate('yes');
  String get no => translate('no');
  String get ok => translate('ok');
  String get error => translate('error');
  String get success => translate('success');
  String get warning => translate('warning');
  String get loading => translate('loading');
  String get noDataFound => translate('no_data_found');
  String get language => translate('language');
  String get selectLanguage => translate('select_language');
  String get darkMode => translate('dark_mode');
  String get lightMode => translate('light_mode');
  String get theme => translate('theme');
  String get productDetails => translate('product_details');
  String get billDetails => translate('bill_details');
  String get purchaseDetails => translate('purchase_details');
  String get totalItems => translate('total_items');
  String get discount => translate('discount');
  String get grandTotal => translate('grand_total');
  String get paid => translate('paid');
  String get unpaid => translate('unpaid');
  String get partiallyPaid => translate('partially_paid');
  String get paymentStatus => translate('payment_status');
  String get my_profile => translate('my_profile');
  String get view_and_edit_profile => translate('view_and_edit_profile');
  String get add => translate('add');
  String get suppliers => translate('suppliers');
  String get units => translate('units');
  String get product_names => translate('product_names');
  String get customers => translate('customers');
  String get privacy => translate('privacy');
  String get logged_in_devices => translate('logged_in_devices');
  String get change_password => translate('change_password');
  String get privacy_policy => translate('privacy_policy');
  String get general => translate('general');
  String get log_out => translate('log_out');
  String get logging_out => translate('logging_out');
  String get dark => translate('dark');
  String get light => translate('light');
  String get apply => translate('apply');
  String get clear => translate('clear');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Support English, Hindi, and Marathi
    return ['en', 'hi', 'mr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
