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
  String get myProfile => translate('my_profile');
  String get viewAndEditProfile => translate('view_and_edit_profile');
  String get add => translate('add');
  String get suppliers => translate('suppliers');
  String get units => translate('units');
  String get productNames => translate('product_names');
  String get customers => translate('customers');
  String get privacy => translate('privacy');
  String get loggedInDevices => translate('logged_in_devices');
  String get changePassword => translate('change_password');
  String get privacyPolicy => translate('privacy_policy');
  String get general => translate('general');
  String get logOut => translate('log_out');
  String get loggingOut => translate('logging_out');
  String get dark => translate('dark');
  String get light => translate('light');
  String get apply => translate('apply');
  String get clear => translate('clear');
  String get welcomeBack => translate('welcome_back');
  String get signInToContinue => translate('sign_in_to_continue');
  String get enterEmailOrUsername => translate('enter_email_or_username');
  String get enterPassword => translate('enter_password');
  String get signIn => translate('sign_in');
  String get pleaseEnterEmailOrUsername =>
      translate('please_enter_email_or_username');
  String get pleaseEnterPassword => translate('please_enter_password');
  String get loginFailed => translate('login_failed');
  String get userNotFound => translate('user_not_found');
  String get incorrectPassword => translate('incorrect_password');
  String get invalidEmail => translate('invalid_email');
  String get salesProfitAnalysis => translate('sales_profit_analysis');
  String get allData => translate('all_data');
  String get dateRange => translate('date_range');
  String get day => translate('day');
  String get month => translate('month');
  String get year => translate('year');
  String get selectRange => translate('select_range');
  String get items => translate('items');
  String get totalPurchase => translate('total_purchase');
  String get orders => translate('orders');
  String get qtyLabel => translate('qty_label');
  String get profitLabel => translate('profit_label');
  String get loss => translate('loss');
  String get inventoryPayments => translate('inventory_payments');
  String get liveStatus => translate('live_status');
  String get availability => translate('availability');
  String get currentStockOverview => translate('current_stock_overview');
  String get availableProductsCount => translate('available_products_count');
  String get totalQuantity => translate('total_quantity');
  String get itemsInStock => translate('items_in_stock');
  String get totalAmount => translate('total_amount');
  String get stockValue => translate('stock_value');
  String get upcomingPayments => translate('upcoming_payments');
  String get due => translate('due');
  String get noUpcomingPayments => translate('no_upcoming_payments');
  String get pendingPayments => translate('pending_payments');
  String get noPendingPayments => translate('no_pending_payments');
  String get orderNow => translate('order_now');
  String get noProductsToOrder => translate('no_products_to_order');
  String get stock0 => translate('stock_0');
  String get viewAllPendingPayments => translate('view_all_pending_payments');
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
