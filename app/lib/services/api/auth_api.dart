import 'api_client.dart';
import '../storage/secure_storage.dart';

class AuthApi {
  final ApiClient _client;

  AuthApi(this._client);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final payload = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (displayName != null) {
      payload['displayName'] = displayName;
    }
    final response = await _client.dio.post('/auth/register', data: payload);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = response.data as Map<String, dynamic>;
    if (data['accessToken'] != null) {
      await SecureStorage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> verifyOtp({
    String? email,
    required String otp,
    String purpose = 'email_verify',
  }) async {
    final payload = <String, dynamic>{
      'otp': otp,
      'purpose': purpose,
    };
    if (email != null && email.trim().isNotEmpty) {
      payload['email'] = email.trim();
    }
    final response = await _client.dio.post('/auth/verify-otp', data: payload);
    final data = response.data as Map<String, dynamic>;
    if (data['accessToken'] != null) {
      await SecureStorage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> sendOtp({
    String? email,
    String purpose = 'email_verify',
  }) async {
    final payload = <String, dynamic>{
      'purpose': purpose,
    };
    if (email != null && email.trim().isNotEmpty) {
      payload['email'] = email.trim();
    }
    final response = await _client.dio.post('/auth/send-otp', data: payload);
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken != null) {
        await _client.dio.post('/auth/logout', data: {
          'refreshToken': refreshToken,
        });
      }
    } finally {
      await SecureStorage.clearTokens();
    }
  }
}
