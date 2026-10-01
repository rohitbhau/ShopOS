// Environment variables
// In production, load from .env file or build-time constants

class Env {
  // Supabase
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dmqsutuniayqtfsaxjuq.supabase.co',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Na2Ql0HkKp9enLLBWYTOsQ_sJx9GnIr',
  );
  
  // Razorpay
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_xxxxx',
  );
  
  static bool get configured => supabaseUrl.startsWith('http') &&
      !supabaseUrl.contains('your-project') && supabaseAnonKey != 'your-anon-key';
  
  // App
  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );
  
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
}
