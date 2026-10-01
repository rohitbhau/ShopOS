import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  SupabaseAuthService(this.client);
  final SupabaseClient client;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
  Session? get currentSession => client.auth.currentSession;
  User? get currentUser => client.auth.currentUser;

  Future<void> sendOtp(String phone) async {
    final normalized = _normalizePhone(phone);
    await client.auth.signInWithOtp(phone: normalized);
  }

  Future<AuthResponse> verifyOtp(
          {required String phone, required String token}) =>
      client.auth.verifyOTP(
        phone: _normalizePhone(phone),
        token: token.trim(),
        type: OtpType.sms,
      );

  Future<void> signOut() => client.auth.signOut();

  Future<FunctionResponse> createTenant({
    required String name,
    required String shopType,
    required String templateKey,
    String? phone,
    Map<String, dynamic>? address,
    String? gstin,
  }) =>
      client.functions.invoke(
        'create-tenant',
        body: {
          'name': name.trim(),
          'shop_type': shopType,
          'template_key': templateKey,
          if (phone != null && phone.trim().isNotEmpty)
            'phone': _normalizePhone(phone),
          if (address != null) 'address': address,
          if (gstin != null && gstin.trim().isNotEmpty) 'gstin': gstin.trim(),
        },
      );

  static String _normalizePhone(String phone) {
    final value = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (value.startsWith('+')) return value;
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(value)) return '+91$value';
    throw FormatException('Enter a valid Indian mobile number');
  }
}
