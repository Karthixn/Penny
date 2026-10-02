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
    required String email,
    required String otp,
    String purpose = 'email_verify',
  }) async {
    final response = await _client.dio.post('/auth/verify-otp', data: {
      'email': email,
      'otp': otp,
      'purpose': purpose,
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

  Future<Map<String, dynamic>> sendOtp({
    required String email,
    String purpose = 'email_verify',
  }) async {
    final response = await _client.dio.post('/auth/send-otp', data: {
      'email': email,
      'purpose': purpose,
    });
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
