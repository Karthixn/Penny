import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  // In-memory token cache to completely eliminate concurrent Android Keystore deadlocks
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (_) {}
  }

  static Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;
    try {
      _cachedAccessToken = await _storage.read(key: _accessTokenKey);
    } catch (_) {}
    return _cachedAccessToken;
  }

  static Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    try {
      _cachedRefreshToken = await _storage.read(key: _refreshTokenKey);
    } catch (_) {}
    return _cachedRefreshToken;
  }

  static Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
    } catch (_) {}
  }
}
