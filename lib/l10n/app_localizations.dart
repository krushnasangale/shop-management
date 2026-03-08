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
  String get leastSellingProducts => translate('least_selling_products');
  String get noSalesDataYet => translate('no_sales_data_yet');
  String get dashboard => translate('dashboard');
  String get bills => translate('bills');
  String get products => translate('products');
  String get purchases => translate('purchases');
  String get myExpenses => translate('my_expenses');
  String get expenses => translate('expenses');
  String get addExpense => translate('add_expense');
  String get expenseDetails => translate('expense_details');
  String get category => translate('category');
  String get description => translate('description');
  String get paymentMethod => translate('payment_method');
  String get expenseAddedSuccessfully =>
      translate('expense_added_successfully');
  String get expenseDeleted => translate('expense_deleted');
  String get deleteExpense => translate('delete_expense');
  String get deleteExpenseConfirmation =>
      translate('delete_expense_confirmation');
  String get noExpensesYet => translate('no_expenses_yet');
  String get totalExpenses => translate('total_expenses');
  String get thisMonth => translate('this_month');
  String get topCategories => translate('top_categories');
  String get monthlyTrendLast6Months =>
      translate('monthly_trend_last_6_months');
  String get paymentMethods => translate('payment_methods');
  String get recentActivity => translate('recent_activity');
  String get vsLastMonth => translate('vs_last_month');
  String get vsLast => translate('vs_last');
  String get sameAsLast => translate('same_as_last');
  String get byCategory => translate('by_category');
  String get recent => translate('recent');
  String get pleaseSelectCategory => translate('please_select_category');
  String get pleaseEnterDescription => translate('please_enter_description');
  String get pleaseSelectDate => translate('please_select_date');
  String get pleaseEnterAmount => translate('please_enter_amount');
  String get pleaseEnterValidAmount => translate('please_enter_valid_amount');
  String get searchByCategoryOrAmount =>
      translate('search_by_category_or_amount');
  String get details => translate('details');
  String get createdAt => translate('created_at');
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
  String get closeSearch => translate('close_search');
  String get sort => translate('sort');
  String get supplier => translate('supplier');
  String get customer => translate('customer');
  String get date => translate('date');
  String get total => translate('total');
  String get totalDue => translate('total_due');
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
  String get na => translate('na');
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
  String get all => translate('all');
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
  String get margin => translate('margin');
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
  String get previousDueTracking => translate('previous_due_tracking');
  String get viewAllPreviousDuePayments =>
      translate('view_all_previous_due_payments');
  String get previousDuePayments => translate('previous_due_payments');
  String get noPreviousDuePayments => translate('no_previous_due_payments');
  String get previousDue => translate('previous_due');
  String get collected => translate('collected');
  String get pending => translate('pending');
  String get orderNow => translate('order_now');
  String get noProductsToOrder => translate('no_products_to_order');
  String get stock0 => translate('stock_0');
  String get viewAllPendingPayments => translate('view_all_pending_payments');
  String get viewAll => translate('view_all');
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
  String get customerInformation => translate('customer_information');
  String get paymentDetails => translate('payment_details');
  String get viewBillDetails => translate('view_bill_details');
  String get dueAgainst => translate('due_against');
  String get termsAndConditions => translate('terms_and_conditions');
  String get billFromShop => translate('bill_from_shop');
  String get currencySymbol => translate('currency_symbol');

  // Bill Success Page
  String get billCreated => translate('bill_created');
  String get billCreatedSuccessfully => translate('bill_created_successfully');
  String get billSavedToSystem => translate('bill_saved_to_system');
  String get billStatus => translate('bill_status');
  String get status => translate('status');
  String get completed => translate('completed');
  String get payment => translate('payment');
  String get partial => translate('partial');
  String get full => translate('full');
  String get goToDashboard => translate('go_to_dashboard');
  String get shareBill => translate('share_bill');
  String get createNewBill => translate('create_new_bill');
  String get generatingPdf => translate('generating_pdf');
  String get errorGeneratingBill => translate('error_generating_bill');

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
  String get deliveryCharges => translate('delivery_charges');
  String get enterDeliveryCharges => translate('enter_delivery_charges');
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
  String get noProductsFound => translate('no_products_found');
  String get noUnitsFoundModal => translate('no_units_found_modal');
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

  // Purchase Items List Page
  String get purchasedEntries => translate('purchased_entries');
  String get scanInvoice => translate('scan_invoice');
  String get takePhoto => translate('take_photo');
  String get captureInvoiceWithCamera =>
      translate('capture_invoice_with_camera');
  String get chooseFromGallery => translate('choose_from_gallery');
  String get selectInvoiceFromPhotos => translate('select_invoice_from_photos');
  String get noPurchasedEntriesYet => translate('no_purchased_entries_yet');
  String get searchBySupplierOrAmount =>
      translate('search_by_supplier_or_amount');
  String get noMatchingEntriesFound => translate('no_matching_entries_found');
  String get purchased => translate('purchased');
  String get received => translate('received');
  String get selectPDF => translate('select_pdf');
  String get choosePDFInvoice => translate('choose_pdf_invoice');
  String get retryScan => translate('retry_scan');
  String get continueAnyway => translate('continue_anyway');
  String get limitedDataDetected => translate('limited_data_detected');
  String get pdfNotGivingGoodResults =>
      translate('pdf_not_giving_good_results');
  String get tryDifferentPDF => translate('try_different_pdf');
  String get takeClearPhotoWithGoodLighting =>
      translate('take_clear_photo_with_good_lighting');
  String get usePDFScanForBetterTableExtraction =>
      translate('use_pdf_scan_for_better_table_extraction');
  String get ensureTextIsLargeAndReadableInPhoto =>
      translate('ensure_text_is_large_and_readable_in_photo');
  String get manuallyEnterPurchaseDetails =>
      translate('manually_enter_purchase_details');
  String get tipPDFScanningWorksBestForTableBasedInvoices =>
      translate('tip_pdf_scanning_works_best_for_table_based_invoices');
  String get couldNotAccessPDFFile => translate('could_not_access_pdf_file');
  String get errorSelectingPDF => translate('error_selecting_pdf');
  String get processingInvoice => translate('processing_invoice');
  String get extractingTextFromPDF => translate('extracting_text_from_pdf');
  String get scanningInvoice => translate('scanning_invoice');
  String get analyzingImageWithOCR => translate('analyzing_image_with_ocr');
  String get errorProcessingInvoice => translate('error_processing_invoice');
  String get tooManyRequests => translate('too_many_requests');
  String get quotaExceeded => translate('quota_exceeded');
  String get invoiceScanningOnlyAvailableOnMobile =>
      translate('invoice_scanning_only_available_on_mobile');
  String get pdfScanLimitInfo => translate('pdf_scan_limit_info');
  String get newSupplierAdded => translate('new_supplier_added');

  // Purchase Entry Details
  String get purchaseEntryRemovedLastProductDeleted =>
      translate('purchase_entry_removed_last_product_deleted');
  String get productRemovedSuccessfully =>
      translate('product_removed_successfully');
  String get errorRemovingProduct => translate('error_removing_product');
  String get removeProduct => translate('remove_product');
  String get removeProductConfirmation =>
      translate('remove_product_confirmation');
  String get removeLastProductWarning =>
      translate('remove_last_product_warning');
  String get removeProductFromPurchase =>
      translate('remove_product_from_purchase');
  String get editPurchase => translate('edit_purchase');
  String get purchaseDate => translate('purchase_date');
  String get totalUnits => translate('total_units');
  String get purchasedItems => translate('purchased_items');
  String get batch => translate('batch');
  String get unitLabel => translate('unit_label');
  String get expiryDateLabel => translate('expiry_date_label');
  String get quantityLabel => translate('quantity_label');
  String get profitPerUnit => translate('profit_per_unit');
  String get itemTotal => translate('item_total');
  String get unknownSupplier => translate('unknown_supplier');
  String get unknown => translate('unknown');
  String get removeProductTooltip => translate('remove_product_tooltip');
  String get reviewBoughtEntry => translate('review_bought_entry');
  String get supplierDetails => translate('supplier_details');
  String get back => translate('back');
  String get confirmSave => translate('confirm_save');
  String get savingPurchaseEntry => translate('saving_purchase_entry');
  String get purchaseEntrySavedSuccessfully =>
      translate('purchase_entry_saved_successfully');
  String get purchaseEntryUpdatedSuccessfully =>
      translate('purchase_entry_updated_successfully');
  String get errorOccurred => translate('error_occurred');
  String get editPurchaseEntry => translate('edit_purchase_entry');
  String get addBoughtEntry => translate('add_bought_entry');
  String get selectDate => translate('select_date');
  String get selectSupplier => translate('select_supplier');
  String get selectProductName => translate('select_product_name');
  String get selectProductUnit => translate('select_product_unit');
  String get selectProductsTitle => translate('select_products_title');
  String get selectUnitsTitle => translate('select_units_title');
  String get expiryDateOptional => translate('expiry_date_optional');
  String get productQuantity => translate('product_quantity');
  String get minQty => translate('min_qty');
  String get buyingPricePerItem => translate('buying_price_per_item');
  String get sellingPricePerItem => translate('selling_price_per_item');
  String get purchaseInfoMessage => translate('purchase_info_message');
  String get selectedProducts => translate('selected_products');
  String get saveReview => translate('save_review');
  String get supplierNameRequired => translate('supplier_name_required');
  String get pleaseSelectSupplier => translate('please_select_supplier');
  String get pleaseSelectProduct => translate('please_select_product');
  String get pleaseSelectUnit => translate('please_select_unit');
  String get pleaseEnterQuantity => translate('please_enter_quantity');
  String get enterQuantity => translate('enter_quantity');
  String get pleaseEnterBuyingPrice => translate('please_enter_buying_price');
  String get pleaseEnterSellingPrice => translate('please_enter_selling_price');
  String get pleaseEnterValidValues => translate('please_enter_valid_values');
  String get productAlreadyAdded => translate('product_already_added');
  String get pleaseAddAtLeastOneProduct =>
      translate('please_add_at_least_one_product');
  String get confirmRemoveProduct => translate('confirm_remove_product');
  String get supplierLabel => translate('supplier_label');
  String get initialQuantityBought => translate('initial_quantity_bought');
  String get currentQuantity => translate('current_quantity');
  String get minStock => translate('min_stock');
  String get buyingPriceRupees => translate('buying_price_rupees');
  String get sellingPriceRupees => translate('selling_price_rupees');
  String get addNewSupplier => translate('add_new_supplier');
  String get contactNumber => translate('contact_number');
  String get contactNumberRequired => translate('contact_number_required');
  String get contactMustBeAtLeast10Digits =>
      translate('contact_must_be_at_least_10_digits');
  String get location => translate('location');
  String get locationRequired => translate('location_required');
  String get selectSupplierTitle => translate('select_supplier_title');
  String get searchSupplier => translate('search_supplier');
  String get noProductsAddedYet => translate('no_products_added_yet');
  String get contactLabel => translate('contact_label');
  String get locationLabel => translate('location_label');
  String get supplierAddedSuccessfully =>
      translate('supplier_added_successfully');
  String get productAddedSuccessfully =>
      translate('product_added_successfully');
  String get unitAddedSuccessfully => translate('unit_added_successfully');
  String get supplierAlreadyExists => translate('supplier_already_exists');
  String get errorLoadingPurchaseData =>
      translate('error_loading_purchase_data');
  String get productRemoved => translate('product_removed');
  String get sellingPriceIs0 => translate('selling_price_is_0');
  String get minLimitIs0 => translate('min_limit_is_0');

  // Review Billing Details Page
  String get reviewBill => translate('review_bill');
  String get customerMobileNumber => translate('customer_mobile_number');
  String get each => translate('each');
  String get summary => translate('summary');
  String get amountPaid => translate('amount_paid');
  String get amountDue => translate('amount_due');
  String get nextPaymentDate => translate('next_payment_date');
  String get editBill => translate('edit_bill');
  String get confirmBill => translate('confirm_bill');
  String get updateBill => translate('update_bill');
  String get areYouSureUpdateBill => translate('are_you_sure_update_bill');
  String get areYouSureCreateBill => translate('are_you_sure_create_bill');
  String get updatingBill => translate('updating_bill');
  String get creatingBill => translate('creating_bill');
  String get billUpdatedSuccessfully => translate('bill_updated_successfully');
  String get errorUpdatingBill => translate('error_updating_bill');
  String get errorCreatingBill => translate('error_creating_bill');
  String get cash => translate('cash');
  String get online => translate('online');
  String get customerName => translate('customer_name');

  // View Existing Bill Details Page
  String get paymentAmountMustBeGreaterThan0 =>
      translate('payment_amount_must_be_greater_than_0');
  String get totalPaymentCannotExceed =>
      translate('total_payment_cannot_exceed');
  String get paymentRecordedSuccessfully =>
      translate('payment_recorded_successfully');
  String get recordPayment => translate('record_payment');
  String get amountRemaining => translate('amount_remaining');
  String get paymentAmount => translate('payment_amount');
  String get eg2000 => translate('eg_2000');
  String get max => translate('max');
  String get nA => translate('n_a');
  String get addDiscountLabel => translate('add_discount_label');
  String get finalAmount => translate('final_amount');
  String get profitLoss => translate('profit_loss');
  String get paymentHistory => translate('payment_history');
  String get addPayment => translate('add_payment');
  String get noPaymentsRecorded => translate('no_payments_recorded');
  String get editNextPaymentDate => translate('edit_next_payment_date');
  String get nextPaymentDateLabel => translate('next_payment_date_label');
  String get pleaseSelectADate => translate('please_select_a_date');
  String get nextPaymentDateUpdatedSuccessfully =>
      translate('next_payment_date_updated_successfully');
  String get editMobileNumber => translate('edit_mobile_number');
  String get mobileNumber => translate('mobile_number');
  String get tenDigitMobileNumber => translate('ten_digit_mobile_number');
  String get mobileNumberMustBe10Digits =>
      translate('mobile_number_must_be_10_digits');
  String get mobileNumberUpdatedSuccessfully =>
      translate('mobile_number_updated_successfully');
  String get editVehicleNumber => translate('edit_vehicle_number');
  String get egKa01ab1234Optional => translate('eg_ka01ab1234_optional');
  String get invalidFormatEgKa01ab1234 =>
      translate('invalid_format_eg_ka01ab1234');
  String get vehicleNumberUpdatedSuccessfully =>
      translate('vehicle_number_updated_successfully');
  String get couldNotLaunchPhoneDialer =>
      translate('could_not_launch_phone_dialer');
  String get couldNotLaunchMessagingApp =>
      translate('could_not_launch_messaging_app');
  String get editDiscount => translate('edit_discount');
  String get remainingAmount => translate('remaining_amount');
  String get addDiscount => translate('add_discount');
  String get eg100 => translate('eg_100');
  String get pleaseEnterAValidNumber =>
      translate('please_enter_a_valid_number');
  String get discountCannotBeNegative =>
      translate('discount_cannot_be_negative');
  String get discountCannotExceedRemainingAmount =>
      translate('discount_cannot_exceed_remaining_amount');
  String get discountAddedBillFullyPaid =>
      translate('discount_added_bill_fully_paid');
  String get discountAddedSuccessfully =>
      translate('discount_added_successfully');

  // Amount paid editing
  String get editAmountPaid => translate('edit_amount_paid');
  String get amountUpdatedSuccessfully =>
      translate('amount_updated_successfully');
  String get amountCannotBeNegative => translate('amount_cannot_be_negative');
  String get amountCannotExceedTotalAmount =>
      translate('amount_cannot_exceed_total_amount');

  // Missing getters for view_existing_bill_details
  String get customerVehicleNumber => translate('customer_vehicle_number');

  // Getters for available_products
  String get availableProductsReport => translate('available_products_report');
  String get availableProductsReportCsv =>
      translate('available_products_report_csv');
  String get generateReport => translate('generate_report');
  String get selectFormatToExport => translate('select_format_to_export');
  String get exportAsPdf => translate('export_as_pdf');
  String get exportAsCsvExcel => translate('export_as_csv_excel');
  String get errorGeneratingPdf => translate('error_generating_pdf');
  String get errorGeneratingCsv => translate('error_generating_csv');
  String get availableProducts => translate('available_products');
  String get searchProductOrSupplier => translate('search_product_or_supplier');
  String get reorderNow => translate('reorder_now');
  String get orderSoon => translate('order_soon');
  String get wellStocked => translate('well_stocked');
  String get expiringSoon => translate('expiring_soon');
  String get expired => translate('expired');
  String get sNo => translate('s_no');
  String get buying => translate('buying');
  String get selling => translate('selling');
  String get totalProducts => translate('total_products');
  String get stockStatus => translate('stock_status');
  String get minLimit => translate('min_limit');
  String get filterApplied => translate('filter_applied');
  String get expiredText => translate('expired_text');
  String get expiringToday => translate('expiring_today');
  String get expiringTomorrow => translate('expiring_tomorrow');
  String get expiringInDays => translate('expiring_in_days');
  String get info => translate('info');
  String get sales => translate('sales');
  String get deleteProductConfirmation =>
      translate('delete_product_confirmation');
  String get sellingPriceUpdated => translate('selling_price_updated');
  String get errorUpdatingPrice => translate('error_updating_price');
  String get enterValidQuantity => translate('enter_valid_quantity');
  String get errorUpdatingQuantity => translate('error_updating_quantity');
  String get enterPrice => translate('enter_price');
  String get enterValidPrice => translate('enter_valid_price');
  String get editQuantity => translate('edit_quantity');
  String get editSellingPrice => translate('edit_selling_price');
  String get quantityUpdated => translate('quantity_updated');
  String get minimumLimitUpdated => translate('minimum_limit_updated');
  String get minimumLimit => translate('minimum_limit');
  String get allBatchesFifo => translate('all_batches_fifo');
  String get batchDetails => translate('batch_details');
  String get noBatchesFound => translate('no_batches_found');
  String get oldestSellFirst => translate('oldest_sell_first');
  String get newest => translate('newest');
  String get batchNumber => translate('batch_number');
  String get financialMetricsCurrentStock =>
      translate('financial_metrics_current_stock');
  String get totalPotentialRevenue => translate('total_potential_revenue');
  String get totalPotentialProfit => translate('total_potential_profit');
  String get profitMarginPerUnit => translate('profit_margin_per_unit');
  String get previousDueAmountInfo => translate('previous_due_amount_info');
  String get previousDueAmount => translate('previous_due_amount');
  String get previousPaidAmount => translate('previous_paid_amount');
  String get previousDueDescription => translate('previous_due_description');
  String get enterDescriptionOptional =>
      translate('enter_description_optional');
  String get descriptionRequiredWhenAmountEntered =>
      translate('description_required_when_amount_entered');

  // Bills page specific getters
  String get filterSortOptions => translate('filter_sort_options');
  String get reset => translate('reset');
  String get dateNewestFirst => translate('date_newest_first');
  String get dateOldestFirst => translate('date_oldest_first');
  String get amountHighestFirst => translate('amount_highest_first');
  String get amountLowestFirst => translate('amount_lowest_first');
  String get customerAz => translate('customer_az');
  String get customerZa => translate('customer_za');
  String get to => translate('to');
  String get billsReportFrom => translate('bills_report_from');
  String get billsReportCsv => translate('bills_report_csv');
  String get otherDue => translate('other_due');
  String get paidLabel => translate('paid_label');
  String get selectDateRange => translate('select_date_range');
  String get startDateOptional => translate('start_date_optional');
  String get fromDate => translate('from_date');
  String get endDateOptional => translate('end_date_optional');
  String get clearDates => translate('clear_dates');
  String get allDates => translate('all_dates');
  String get upToDate => translate('up_to_date');
  String get from => translate('from');
  String get billsReport => translate('bills_report');
  String get generatedOn => translate('generated_on');
  String get recentBills => translate('recent_bills');
  String get searchByCustomerName => translate('search_by_customer_name');
  String get filterSort => translate('filter_sort');
  String get noBillsFound => translate('no_bills_found');

  // Additional getters for previous due details page
  String get amountCannotExceed => translate('amount_cannot_exceed');
  String get paymentAddedSuccessfully =>
      translate('payment_added_successfully');
  String get failedToAddPayment => translate('failed_to_add_payment');

  // App settings page getters
  String get vehicleNumberInBills => translate('vehicle_number_in_bills');
  String get enableVehicleNumberOption =>
      translate('enable_vehicle_number_option');
  String get enableDeliveryChargesField =>
      translate('enable_delivery_charges_field');
  String get enablePreviousDueField => translate('enable_previous_due_field');
  String get expiryDateInPurchases => translate('expiry_date_in_purchases');
  String get enableExpiryDateField => translate('enable_expiry_date_field');

  // Purchase items list page getters
  String get bySupplier => translate('by_supplier');
  String get errorProcessingPDF => translate('error_processing_pdf');
  String get appSettings => translate('app_settings');

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
