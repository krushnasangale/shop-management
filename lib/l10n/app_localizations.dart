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
  String get topSellingProducts => translate('top_selling_products');
  String get noSalesDataYet => translate('no_sales_data_yet');
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
  String get qty => translate('qty');
  String get revenue => translate('revenue');
  String get profit => translate('profit');
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
  String get bill => translate('bill');
  String get remaining => translate('remaining');
  String get select => translate('select');
  String get allTime => translate('all_time');
  String get selectYear => translate('select_year');
  String get selectMonthYear => translate('select_month_year');
  String get monthJan => translate('month_jan');
  String get monthFeb => translate('month_feb');
  String get monthMar => translate('month_mar');
  String get monthApr => translate('month_apr');
  String get monthMay => translate('month_may');
  String get monthJun => translate('month_jun');
  String get monthJul => translate('month_jul');
  String get monthAug => translate('month_aug');
  String get monthSep => translate('month_sep');
  String get monthOct => translate('month_oct');
  String get monthNov => translate('month_nov');
  String get monthDec => translate('month_dec');

  // Full month names
  String get monthJanuary => translate('month_january');
  String get monthFebruary => translate('month_february');
  String get monthMarch => translate('month_march');
  String get monthApril => translate('month_april');
  String get monthMayFull => translate('month_may_full');
  String get monthJune => translate('month_june');
  String get monthJuly => translate('month_july');
  String get monthAugust => translate('month_august');
  String get monthSeptember => translate('month_september');
  String get monthOctober => translate('month_october');
  String get monthNovember => translate('month_november');
  String get monthDecember => translate('month_december');

  // Currency abbreviations
  String get currencyLakh => translate('currency_lakh');
  String get currencyThousand => translate('currency_thousand');

  // Change Password Dialog
  String get currentPassword => translate('current_password');
  String get enterCurrentPassword => translate('enter_current_password');
  String get newPassword => translate('new_password');
  String get enterNewPassword => translate('enter_new_password');
  String get passwordMinLength => translate('password_min_length');
  String get confirmNewPassword => translate('confirm_new_password');
  String get reEnterNewPassword => translate('re_enter_new_password');
  String get updatingPassword => translate('updating_password');
  String get userNotAuthenticated => translate('user_not_authenticated');
  String get passwordChangedSuccessfully =>
      translate('password_changed_successfully');
  String get currentPasswordIncorrect =>
      translate('current_password_incorrect');
  String get newPasswordTooWeak => translate('new_password_too_weak');
  String get reauthenticateRequired => translate('reauthenticate_required');
  String get currentPasswordRequired => translate('current_password_required');
  String get newPasswordRequired => translate('new_password_required');
  String get confirmPasswordRequired => translate('confirm_password_required');
  String get passwordsDoNotMatch => translate('passwords_do_not_match');
  String get failedToChangePassword => translate('failed_to_change_password');

  // Customers Page
  String get searchCustomers => translate('search_customers');
  String get noCustomersAddedYet => translate('no_customers_added_yet');
  String get noCustomersFound => translate('no_customers_found');
  String get customerDeletedSuccessfully =>
      translate('customer_deleted_successfully');
  String get errorDeletingCustomer => translate('error_deleting_customer');
  String get noVehicle => translate('no_vehicle');
  String get history => translate('history');
  String get deleteCustomer => translate('delete_customer');
  String get confirmDeleteCustomer => translate('confirm_delete_customer');
  String get editCustomer => translate('edit_customer');
  String get addCustomer => translate('add_customer');
  String get nameRequired => translate('name_required');
  String get enterCustomerName => translate('enter_customer_name');
  String get nameIsRequired => translate('name_is_required');
  String get mobileNumberRequired => translate('mobile_number_required');
  String get enterMobileNumber => translate('enter_mobile_number');
  String get mobileNumberIsRequired => translate('mobile_number_is_required');
  String get mobileNumberMinLength => translate('mobile_number_min_length');
  String get vehicleNumber => translate('vehicle_number');
  String get enterVehicleNumber => translate('enter_vehicle_number');
  String get update => translate('update');
  String get customerUpdatedSuccessfully =>
      translate('customer_updated_successfully');
  String get customerAddedSuccessfully =>
      translate('customer_added_successfully');
  String get errorSavingCustomer => translate('error_saving_customer');

  // Customer History Page
  String get errorLoadingCustomerBills =>
      translate('error_loading_customer_bills');
  String get item => translate('item');
  String get noBillsForThisCustomer => translate('no_bills_for_this_customer');
  String get totalBills => translate('total_bills');
  String get totalPaid => translate('total_paid');
  String get totalRemaining => translate('total_remaining');
  String get billDate => translate('bill_date');
  String get paidAmount => translate('paid_amount');

  // Product Names Page
  String get searchProducts => translate('search_products');
  String get addProductName => translate('add_product_name');
  String get enterProductName => translate('enter_product_name');
  String get editProductName => translate('edit_product_name');
  String get deleteProduct => translate('delete_product');
  String get confirmDeleteProduct => translate('confirm_delete_product');
  String get errorAddingProduct => translate('error_adding_product');
  String get errorUpdatingProduct => translate('error_updating_product');
  String get errorDeletingProduct => translate('error_deleting_product');

  // Units Page
  String get measurementUnits => translate('measurement_units');
  String get searchUnits => translate('search_units');
  String get addNewUnit => translate('add_new_unit');
  String get unitNameExample => translate('unit_name_example');
  String get enterUnitName => translate('enter_unit_name');
  String get noUnitsYet => translate('no_units_yet');
  String get noUnitsFound => translate('no_units_found');
  String get editUnit => translate('edit_unit');
  String get deleteUnit => translate('delete_unit');
  String get confirmDeleteUnit => translate('confirm_delete_unit');
  String get errorAddingUnit => translate('error_adding_unit');
  String get errorUpdatingUnit => translate('error_updating_unit');
  String get errorDeletingUnit => translate('error_deleting_unit');

  // Suppliers Page
  String get searchSuppliers => translate('search_suppliers');
  String get noSuppliersYet => translate('no_suppliers_yet');
  String get noSuppliersFound => translate('no_suppliers_found');
  String get addSupplier => translate('add_supplier');
  String get supplierName => translate('supplier_name');
  String get enterSupplierName => translate('enter_supplier_name');
  String get supplierContact => translate('supplier_contact');
  String get enterContactNumber => translate('enter_contact_number');
  String get supplierLocation => translate('supplier_location');
  String get enterLocation => translate('enter_location');
  String get editSupplier => translate('edit_supplier');
  String get deleteSupplier => translate('delete_supplier');
  String get confirmDeleteSupplier => translate('confirm_delete_supplier');

  // Supplier History Page
  String get supplierHistory => translate('supplier_history');
  String get recentFirst => translate('recent_first');
  String get oldestFirst => translate('oldest_first');
  String get amountHighToLow => translate('amount_high_to_low');
  String get amountLowToHigh => translate('amount_low_to_high');
  String get high => translate('high');
  String get noPurchaseHistory => translate('no_purchase_history');
  String get noTransactionsWithSupplier =>
      translate('no_transactions_with_supplier');
  String get errorLoadingHistory => translate('error_loading_history');
  String get sortBy => translate('sort_by');

  // Edit Profile Page
  String get editProfile => translate('edit_profile');
  String get shopName => translate('shop_name');
  String get ownerName => translate('owner_name');
  String get shopAddress => translate('shop_address');
  String get shopPhone => translate('shop_phone');
  String get shopEmail => translate('shop_email');
  String get ownerSignature => translate('owner_signature');
  String get saveChanges => translate('save_changes');
  String get addUpdateSignature => translate('add_update_signature');
  String get chooseSignatureMethod => translate('choose_signature_method');
  String get drawSignature => translate('draw_signature');
  String get upload => translate('upload');
  String get camera => translate('camera');
  String get drawYourSignature => translate('draw_your_signature');
  String get noSignatureAdded => translate('no_signature_added');
  String get updateSignature => translate('update_signature');
  String get addSignature => translate('add_signature');
  String get notSet => translate('not_set');
  String get enterShopName => translate('enter_shop_name');
  String get enterOwnerName => translate('enter_owner_name');
  String get enterCompleteShopAddress =>
      translate('enter_complete_shop_address');
  String get enterPhoneNumber => translate('enter_phone_number');
  String get enterEmailAddress => translate('enter_email_address');
  String get pleaseEnterShopName => translate('please_enter_shop_name');
  String get pleaseEnterOwnerName => translate('please_enter_owner_name');
  String get pleaseEnterShopAddress => translate('please_enter_shop_address');
  String get pleaseEnterPhoneNumber => translate('please_enter_phone_number');
  String get pleaseEnterValidPhoneNumber =>
      translate('please_enter_valid_phone_number');
  String get pleaseEnterValidEmail => translate('please_enter_valid_email');
  String get profileSavedSuccessfully =>
      translate('profile_saved_successfully');
  String get errorSavingProfile => translate('error_saving_profile');
  String get signatureCleared => translate('signature_cleared');
  String get signatureUploadedSuccessfully =>
      translate('signature_uploaded_successfully');
  String get signatureCapturedSuccessfully =>
      translate('signature_captured_successfully');
  String get signatureSaved => translate('signature_saved');
  String get pleaseDrawSignature => translate('please_draw_signature');
  String get saveSignature => translate('save_signature');
  String get subscriptionExpiry => translate('subscription_expiry');
  String get pleaseLoginToViewDevices =>
      translate('please_login_to_view_devices');
  String get deviceRemovedSuccessfully =>
      translate('device_removed_successfully');
  String get errorRemovingDevice => translate('error_removing_device');
  String get removeDevice => translate('remove_device');
  String get removeDeviceFromLoggedIn =>
      translate('remove_device_from_logged_in');
  String get noDevicesLoggedIn => translate('no_devices_logged_in');
  String get currentDevice => translate('current_device');
  String get logoutFailed => translate('logout_failed');
  String get deviceLoggedOutRemotely => translate('device_logged_out_remotely');
  String get addItem => translate('add_item');
  String get sortByAmount => translate('sort_by_amount');
  String get sortByDate => translate('sort_by_date');
  String get sortByName => translate('sort_by_name');
  String get totalPending => translate('total_pending');
  String get searchByNameMobile => translate('search_by_name_mobile');
  String get noResultsFound => translate('no_results_found');
  String get paymentProgress => translate('payment_progress');

  // Helper method to get localized full month name
  String getFullMonthName(int monthIndex) {
    switch (monthIndex) {
      case 1:
        return monthJanuary;
      case 2:
        return monthFebruary;
      case 3:
        return monthMarch;
      case 4:
        return monthApril;
      case 5:
        return monthMayFull;
      case 6:
        return monthJune;
      case 7:
        return monthJuly;
      case 8:
        return monthAugust;
      case 9:
        return monthSeptember;
      case 10:
        return monthOctober;
      case 11:
        return monthNovember;
      case 12:
        return monthDecember;
      default:
        return '';
    }
  }
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
