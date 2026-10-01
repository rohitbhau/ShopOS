// App constants
class AppConstants {
  // App info
  static const String appName = 'ShopOS';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Manage your shop from your phone';
  
  // Phone validation
  static const int phoneLength = 10;
  static const int otpLength = 6;
  
  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;
  
  // Sync
  static const Duration syncInterval = Duration(seconds: 30);
  static const int maxRetryCount = 5;
  
  // Cache
  static const Duration cacheExpiry = Duration(hours: 24);
  
  // Invoice
  static const String invoicePrefix = 'INV';
  static const int invoiceNumberLength = 10;
  
  // GST rates
  static const List<String> gstRates = ['0', '5', '12', '18', '28'];
  
  // Payment modes
  static const List<String> paymentModes = ['cash', 'upi', 'card', 'credit'];
  
  // Shop types
  static const Map<String, String> shopTypes = {
    'retail': 'Retail / Kirana',
    'pharmacy': 'Pharmacy',
    'salon': 'Salon',
    'restaurant': 'Restaurant',
    'boutique': 'Boutique',
    'repair': 'Repair Shop',
  };
  
  // Locale codes
  static const List<String> supportedLocales = ['en', 'hi', 'mr', 'ta', 'te'];
  
  // External URLs
  static const String termsUrl = 'https://shopos.app/terms';
  static const String privacyUrl = 'https://shopos.app/privacy';
  static const String supportUrl = 'https://support.shopos.app';
  static const String docsUrl = 'https://docs.shopos.app';
}
