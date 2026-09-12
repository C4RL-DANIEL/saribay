import 'package:flutter/material.dart';

/// App localization with English and Tagalog support.
/// Partial Tagalog mode mixes English technical terms with Tagalog sentences.
class AppLocalizations {
  final String languageCode;
  AppLocalizations(this.languageCode);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations('en');
  }

  bool get isTagalog => languageCode == 'tl';
  bool get isPartialTagalog => languageCode == 'tl_partial';

  // ==================== COMMON ====================
  String get appName => isTagalog ? 'SariBay POS' : 'SariBay POS';
  String get loading => isTagalog ? 'Naglo-load...' : 'Loading...';
  String get error => isTagalog ? 'Error' : 'Error';
  String get save => isTagalog ? 'I-save' : 'Save';
  String get cancel => isTagalog ? 'Kanselahin' : 'Cancel';
  String get delete => isTagalog ? 'Tanggalin' : 'Delete';
  String get edit => isTagalog ? 'I-edit' : 'Edit';
  String get add => isTagalog ? 'Magdagdag' : 'Add';
  String get search => isTagalog ? 'Maghanap...' : 'Search...';
  String get confirm => isTagalog ? 'Kumpirmahin' : 'Confirm';
  String get back => isTagalog ? 'Bumalik' : 'Back';
  String get next => isTagalog ? 'Susunod' : 'Next';
  String get yes => isTagalog ? 'Oo' : 'Yes';
  String get no => isTagalog ? 'Hindi' : 'No';
  String get ok => isTagalog ? 'Sige' : 'OK';
  String get all => isTagalog ? 'Lahat' : 'All';
  String get none => isTagalog ? 'Wala' : 'None';
  String get total => isTagalog ? 'Kabuuan' : 'Total';
  String get amount => isTagalog ? 'Halaga' : 'Amount';
  String get date => isTagalog ? 'Petsa' : 'Date';
  String get status => isTagalog ? 'Status' : 'Status';
  String get details => isTagalog ? 'Mga Detalye' : 'Details';
  String get actions => isTagalog ? 'Mga Aksyon' : 'Actions';

  // ==================== AUTH ====================
  String get login => isTagalog ? 'Mag-login' : 'Login';
  String get logout => isTagalog ? 'Mag-logout' : 'Logout';
  String get username => isTagalog ? 'Username' : 'Username';
  String get pin => isTagalog ? 'PIN' : 'PIN';
  String get enterPin => isTagalog ? 'Ilagay ang PIN' : 'Enter PIN';
  String get invalidCredentials => isTagalog ? 'Mali ang username o PIN' : 'Invalid username or PIN';
  String get storeSetup => isTagalog ? 'Setup ng Tindahan' : 'Store Setup';
  String get welcomeMessage => isTagalog ? 'Maligayang pagdating! I-setup ang iyong tindahan at owner account.' : 'Welcome! Set up your store and owner account.';
  String get storeName => isTagalog ? 'Pangalan ng Tindahan' : 'Store Name';
  String get yourName => isTagalog ? 'Pangalan Mo' : 'Your Name';
  String get start => isTagalog ? 'Simulan' : 'Start';
  String get ownerCreated => isTagalog ? 'Owner created! Mag-login na.' : 'Owner created! Please log in.';

  // ==================== NAVIGATION ====================
  String get home => isTagalog ? 'Home' : 'Home';
  String get pos => isTagalog ? 'POS' : 'POS';
  String get products => isTagalog ? 'Mga Produkto' : 'Products';
  String get stock => isTagalog ? 'Stock' : 'Stock';
  String get more => isTagalog ? 'Higit Pa' : 'More';

  // ==================== DASHBOARD ====================
  String get dashboard => isTagalog ? 'Dashboard' : 'Dashboard';
  String get todaysSales => isTagalog ? 'Mga Benta Ngayon' : "Today's Sales";
  String get profit => isTagalog ? 'Kita' : 'Profit';
  String get transactions => isTagalog ? 'Mga Transaksyon' : 'Transactions';
  String get bestSellers => isTagalog ? 'Pinakamabenta (7 araw)' : 'Best Sellers (7 days)';
  String get lowStock => isTagalog ? 'Kulang sa Stock' : 'Low Stock';
  String get outstandingUtang => isTagalog ? 'Hindi Pa Bayad na Utang' : 'Outstanding Utang';
  String get salesHistory => isTagalog ? 'Kasaysayan ng Benta' : 'Sales History';
  String get inventory => isTagalog ? 'Inventory' : 'Inventory';

  // ==================== POS ====================
  String get checkout => isTagalog ? 'Mag-checkout' : 'Checkout';
  String get cart => isTagalog ? 'Kart' : 'Cart';
  String get scanBarcode => isTagalog ? 'Mag-scan ng Barcode' : 'Scan Barcode';
  String get searchProducts => isTagalog ? 'Maghanap ng produkto o mag-scan...' : 'Search products or scan...';
  String get noProducts => isTagalog ? 'Walang produkto. Magdagdag muna.' : 'No products. Add products first.';
  String get added => isTagalog ? 'dinagdag' : 'added';
  String get hold => isTagalog ? 'I-hold' : 'Hold';
  String get heldSales => isTagalog ? 'Mga I-hold na Benta' : 'Held Sales';
  String get selectCustomer => isTagalog ? 'Pumili ng Customer' : 'Select Customer';
  String get noCustomer => isTagalog ? 'Walang customer' : 'No customer';
  String get change => isTagalog ? 'Sukli' : 'Change';
  String get subtotal => isTagalog ? 'Subtotal' : 'Subtotal';
  String get discount => isTagalog ? 'Diskwento' : 'Discount';
  String get cash => isTagalog ? 'Cash' : 'Cash';
  String get utangCredit => isTagalog ? 'Utang / Credit' : 'Utang / Credit';
  String get recordUtang => isTagalog ? 'I-record ang Utang' : 'Record Utang';
  String get processing => isTagalog ? 'Nagpoproseso...' : 'Processing...';
  String get saleCompleted => isTagalog ? 'Natapos na ang benta!' : 'Sale completed!';

  // ==================== PAYMENT ====================
  String get payment => isTagalog ? 'Bayad' : 'Payment';
  String get totalAmount => isTagalog ? 'Kabuuang Halaga' : 'Total Amount';
  String get paymentMethod => isTagalog ? 'Paraan ng Bayad' : 'Payment Method';
  String get amountReceived => isTagalog ? 'Halaga na Natanggap (₱)' : 'Amount Received (₱)';
  String get paymentReference => isTagalog ? 'Payment Reference (opsyonal)' : 'Payment Reference (optional)';
  String get manualConfirmationRequired => isTagalog ? 'Kailangan ng Manual na Kumpirmasyon' : 'Manual Confirmation Required';
  String get confirmPayment => isTagalog ? 'Kumpirmahin ang Bayad' : 'Confirm Payment';
  String get cancelPayment => isTagalog ? 'Kanselahin' : 'Cancel';
  String get scannedQR => isTagalog ? 'I-scan ang QR, magbayad ang customer, tapos kumpirmahin.' : 'Scan QR, customer pays externally, then confirm.';

  // ==================== PRODUCTS ====================
  String get addProduct => isTagalog ? 'Magdagdag ng Produkto' : 'Add Product';
  String get editProduct => isTagalog ? 'I-edit ang Produkto' : 'Edit Product';
  String get productName => isTagalog ? 'Pangalan ng Produkto *' : 'Product Name *';
  String get sku => isTagalog ? 'SKU' : 'SKU';
  String get barcodes => isTagalog ? 'Mga Barcode (comma-separated)' : 'Barcodes (comma-separated)';
  String get category => isTagalog ? 'Kategorya' : 'Category';
  String get unit => isTagalog ? 'Unit' : 'Unit';
  String get description => isTagalog ? 'Paglalarawan' : 'Description';
  String get costPrice => isTagalog ? 'Presyo ng Bili (₱)' : 'Cost Price (₱)';
  String get sellingPrice => isTagalog ? 'Presyo ng Benta (₱)' : 'Selling Price (₱)';
  String get wholesalePrice => isTagalog ? 'Wholesale Price (₱)' : 'Wholesale Price (₱)';
  String get stockQty => isTagalog ? 'Stock Qty' : 'Stock Qty';
  String get minStock => isTagalog ? 'Min Stock' : 'Min Stock';
  String get maxStock => isTagalog ? 'Max Stock' : 'Max Stock';
  String get saveProduct => isTagalog ? 'I-save ang Produkto' : 'Save Product';

  // ==================== INVENTORY ====================
  String get lowStockItems => isTagalog ? 'Mga Kulang sa Stock' : 'Low Stock Items';
  String get movements => isTagalog ? 'Mga Galaw' : 'Movements';
  String get adjust => isTagalog ? 'I-adjust' : 'Adjust';
  String get stockAdjustment => isTagalog ? 'Pag-adjust ng Stock' : 'Stock Adjustment';
  String get currentStock => isTagalog ? 'Kasalukuyang Stock' : 'Current Stock';
  String get physicalCount => isTagalog ? 'Bagong Bilang (Physical)' : 'New Count (Physical)';

  // ==================== CUSTOMERS ====================
  String get customers => isTagalog ? 'Mga Customer' : 'Customers';
  String get addCustomer => isTagalog ? 'Magdagdag ng Customer' : 'Add Customer';
  String get phone => isTagalog ? 'Telepono' : 'Phone';
  String get address => isTagalog ? 'Address' : 'Address';
  String get creditLimit => isTagalog ? 'Credit Limit (₱)' : 'Credit Limit (₱)';
  String get totalSpent => isTagalog ? 'Total Na Ginastos' : 'Total Spent';
  String get loyaltyPoints => isTagalog ? 'Loyalty Points' : 'Loyalty Points';

  // ==================== UTANG ====================
  String get utang => isTagalog ? 'Utang' : 'Utang';
  String get payUtang => isTagalog ? 'Magbayad ng Utang' : 'Pay Utang';
  String get balance => isTagalog ? 'Balance' : 'Balance';

  // ==================== SUPPLIERS ====================
  String get suppliers => isTagalog ? 'Mga Supplier' : 'Suppliers';
  String get addSupplier => isTagalog ? 'Magdagdag ng Supplier' : 'Add Supplier';
  String get contactPerson => isTagalog ? 'Contact Person' : 'Contact Person';
  String get outstandingBalance => isTagalog ? 'Hindi Nabayarang Balance' : 'Outstanding Balance';

  // ==================== PURCHASES ====================
  String get purchases => isTagalog ? 'Mga Bili' : 'Purchases';
  String get newPurchaseOrder => isTagalog ? 'Bagong Purchase Order' : 'New Purchase Order';
  String get addProductLine => isTagalog ? 'Magdagdag ng Produkto' : 'Add Product';
  String get createPO => isTagalog ? 'Gumawa ng PO' : 'Create PO';

  // ==================== EXPENSES ====================
  String get expenses => isTagalog ? 'Mga Gastos' : 'Expenses';
  String get addExpense => isTagalog ? 'Magdagdag ng Gastos' : 'Add Expense';
  String get categoryLabel => isTagalog ? 'Kategorya' : 'Category';

  // ==================== CASH DRAWER ====================
  String get cashDrawer => isTagalog ? 'Cash Drawer' : 'Cash Drawer';
  String get openDrawer => isTagalog ? 'Buksan ang Drawer' : 'Open Drawer';
  String get closeDrawer => isTagalog ? 'Isara ang Drawer' : 'Close Drawer';
  String get openingAmount => isTagalog ? 'Opening Amount (₱)' : 'Opening Amount (₱)';
  String get expectedCash => isTagalog ? 'Expected Cash' : 'Expected Cash';
  String get actualCash => isTagalog ? 'Actual Cash (₱)' : 'Actual Cash (₱)';
  String get varianceReason => isTagalog ? 'Dahilan ng Variance (kung meron)' : 'Variance Reason (if any)';

  // ==================== REPORTS ====================
  String get reports => isTagalog ? 'Mga Ulat' : 'Reports';
  String get salesReport => isTagalog ? 'Ulat ng Benta' : 'Sales Report';
  String get inventoryReport => isTagalog ? 'Ulat ng Inventory' : 'Inventory Report';
  String get financialReport => isTagalog ? 'Ulat ng Pananalapi' : 'Financial Report';
  String get revenue => isTagalog ? 'Revenue' : 'Revenue';
  String get expensesLabel => isTagalog ? 'Gastos' : 'Expenses';

  // ==================== EMPLOYEES ====================
  String get employees => isTagalog ? 'Mga empleyado' : 'Employees';
  String get addEmployee => isTagalog ? 'Magdagdag ng Empleyado' : 'Add Employee';
  String get role => isTagalog ? 'Role' : 'Role';
  String get resetPin => isTagalog ? 'I-reset ang PIN' : 'Reset PIN';

  // ==================== SETTINGS ====================
  String get settings => isTagalog ? 'Mga Setting' : 'Settings';
  String get storeInformation => isTagalog ? 'Impormasyon ng Tindahan' : 'Store Information';
  String get saveSettings => isTagalog ? 'I-save ang mga Setting' : 'Save Settings';
  String get settingsSaved => isTagalog ? 'Na-save ang mga Setting' : 'Settings saved';
  String get language => isTagalog ? 'Wika' : 'Language';
  String get english => isTagalog ? 'Ingles' : 'English';
  String get tagalog => isTagalog ? 'Tagalog' : 'Tagalog';
  String get partialTagalog => isTagalog ? 'Partial Tagalog' : 'Partial Tagalog';
  String get currency => isTagalog ? 'Currency' : 'Currency';
  String get philippinePeso => isTagalog ? 'Piso (₱) — default' : 'PHP (₱) — default';

  // ==================== NOTIFICATIONS ====================
  String get notifications => isTagalog ? 'Mga Notification' : 'Notifications';
  String get markAllRead => isTagalog ? 'Markahan Lahat bilang Nabasa' : 'Mark All Read';

  // ==================== PROMOTIONS ====================
  String get promotions => isTagalog ? 'Mga Promosyon' : 'Promotions';
  String get addPromotion => isTagalog ? 'Magdagdag ng Promosyon' : 'Add Promotion';

  // ==================== AI ASSISTANT ====================
  String get aiAssistant => isTagalog ? 'AI Assistant' : 'AI Assistant';
  String get aiWelcome => isTagalog
      ? 'Kumusta! Ako ang SariBay AI Assistant. 🤖\n\nTanungin mo ako kahit ano tungkol sa iyong tindahan o i-tap ang suggestion sa ibaba:'
      : "Hello! I'm SariBay AI Assistant. 🤖\n\nAsk me anything about your store or tap a suggestion below:";
  String get askAboutStore => isTagalog ? 'Tanungin tungkol sa tindahan...' : 'Ask about your store...';
  String get analyzing => isTagalog ? 'Sinasaliksik...' : 'Analyzing...';
  String get insights => isTagalog ? 'Mga Insights' : 'Insights';
  String get automatedAnalysis => isTagalog ? 'Automated na pagsusuri ng iyong data' : 'Automated analysis of your store data';
  String get localMode => isTagalog ? 'Lokal' : 'Local';
  String get offlineHint => isTagalog ? 'Mag-connect sa internet para sa AI-powered na sagot' : 'Connect to internet for AI-powered answers';

  // ==================== BACKUP ====================
  String get backup => isTagalog ? 'Backup' : 'Backup';
  String get backupRestore => isTagalog ? 'Backup & Restore' : 'Backup & Restore';
  String get backupNow => isTagalog ? 'Mag-backup Ngayon' : 'Backup Now';
  String get backupCreated => isTagalog ? 'Na-create ang backup' : 'Backup created';
  String get backupFailed => isTagalog ? 'Nabigo ang backup' : 'Backup failed';

  // ==================== RECEIPTS ====================
  String get receipt => isTagalog ? 'Resibo' : 'Receipt';
  String get printReceipt => isTagalog ? 'I-print ang Resibo' : 'Print Receipt';
  String get shareReceipt => isTagalog ? 'I-share ang Resibo' : 'Share Receipt';
  String get thankYou => isTagalog ? 'Salamat po!' : 'Thank you!';

  // ==================== ANOMALY ====================
  String get anomalyDetection => isTagalog ? 'Anomaly Detection' : 'Anomaly Detection';
  String get noAnomalies => isTagalog ? 'Walang anomalya na na-detect. Maganda ang takbo ng tindahan!' : 'No anomalies detected. Your store looks healthy!';
  String get highRefundRate => isTagalog ? 'Mataas ang Refund Rate' : 'High Refund Rate';

  // ==================== UNITS ====================
  String get unitPiece => isTagalog ? 'piraso' : 'piece';
  String get unitPack => isTagalog ? 'pack' : 'pack';
  String get unitBox => isTagalog ? 'kahon' : 'box';
  String get unitBottle => isTagalog ? 'bote' : 'bottle';
  String get unitSachet => isTagalog ? 'sachet' : 'sachet';
  String get unitCan => isTagalog ? 'lata' : 'can';
  String get unitKilogram => isTagalog ? 'kilo' : 'kilogram';
  String get unitLiter => isTagalog ? 'litro' : 'liter';

  // ==================== EXPENSE CATEGORIES ====================
  String get expElectricity => isTagalog ? 'Kuryente' : 'Electricity';
  String get expWater => isTagalog ? 'Tubig' : 'Water';
  String get expInternet => isTagalog ? 'Internet' : 'Internet';
  String get expRent => isTagalog ? 'Upa' : 'Rent';
  String get expTransport => isTagalog ? 'Transportasyon' : 'Transportation';
  String get expSalary => isTagalog ? 'Sweldo' : 'Salary';
  String get expSupplies => isTagalog ? 'Mga Kagamitan' : 'Supplies';
  String get expRepairs => isTagalog ? 'Pag-aayos' : 'Repairs';
  String get expOther => isTagalog ? 'Iba pa' : 'Other';

  // ==================== STATUS ====================
  String get completed => isTagalog ? 'Natapos' : 'Completed';
  String get voided => isTagalog ? 'Voided' : 'Voided';
  String get refunded => isTagalog ? 'Refunded' : 'Refunded';
  String get held => isTagalog ? 'Held' : 'Held';
  String get open => isTagalog ? 'Bukas' : 'Open';
  String get closed => isTagalog ? 'Sarado' : 'Closed';
  String get pending => isTagalog ? 'Naghihintay' : 'Pending';
  String get confirmed => isTagalog ? 'Kumpirmado' : 'Confirmed';
  String get received => isTagalog ? 'Natanggap' : 'Received';
  String get ordered => isTagalog ? 'Na-order' : 'Ordered';
}
