import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../services/api/api_client.dart';
import '../services/api/auth_api.dart';
import '../services/storage/secure_storage.dart';

final apiClientProvider = Provider((ref) {
  final client = ApiClient();
  client.onUnauthenticated = () {
    ref.read(authProvider.notifier).forceLogout();
  };
  return client;
});
final authApiProvider = Provider((ref) => AuthApi(ref.read(apiClientProvider)));

enum AuthStatus { initial, authenticated, unauthenticated, awaitingVerification, loading }

class AuthState {
  final AuthStatus status;
  final String? error;
  final String? pendingEmail;
  final String? message;

  const AuthState({
    this.status = AuthStatus.initial,
    this.error,
    this.pendingEmail,
    this.message,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? error,
    String? pendingEmail,
    String? message,
  }) =>
      AuthState(
        status: status ?? this.status,
        error: error,
        pendingEmail: pendingEmail ?? this.pendingEmail,
        message: message ?? this.message,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final token = ref.read(initialAuthTokenProvider);
    return AuthState(
      status: token != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final res = await ref.read(authApiProvider).register(
            email: email,
            password: password,
            displayName: displayName,
          );
      if (res['requiresVerification'] == true) {
        state = AuthState(
          status: AuthStatus.awaitingVerification,
          pendingEmail: email,
          message: res['message'] as String?,
        );
        return true;
      }
      state = const AuthState(status: AuthStatus.authenticated);
      return true;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _parseError(e),
      );
      return false;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final res = await ref.read(authApiProvider).login(email: email, password: password);
      if (res['requiresVerification'] == true) {
        state = AuthState(
          status: AuthStatus.awaitingVerification,
          pendingEmail: email,
          message: res['message'] as String?,
        );
        return;
      }
      state = const AuthState(status: AuthStatus.authenticated);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: _parseError(e),
      );
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String otp,
  }) async {
    state = AuthState(status: AuthStatus.loading, pendingEmail: email);
    try {
      await ref.read(authApiProvider).verifyOtp(email: email, otp: otp);
      state = const AuthState(status: AuthStatus.authenticated);
      return true;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.awaitingVerification,
        pendingEmail: email,
        error: _parseError(e),
      );
      return false;
    }
  }

  Future<bool> resendOtp(String email) async {
    try {
      await ref.read(authApiProvider).sendOtp(email: email);
      return true;
    } catch (e) {
      state = state.copyWith(error: _parseError(e));
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(authApiProvider).logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void forceLogout() {
    SecureStorage.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      final resData = e.response?.data;
      if (resData is Map && resData['message'] != null) {
        final msg = resData['message'];
        if (msg is String) return msg;
        if (msg is List && msg.isNotEmpty) return msg.first.toString();
      }
      if (e.response?.statusCode == 409) return 'Email already registered';
      if (e.response?.statusCode == 401) return 'Invalid email or password';
      if (e.response?.statusCode == 400) return 'Invalid request';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Could not connect to server. Check your network connection.';
      }
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Server took too long to respond. Cloud instance may be waking up, please tap again.';
      }
    }
    if (e is Exception) {
      final str = e.toString();
      if (str.contains('SocketException')) return 'No internet connection';
    }
    return 'Something went wrong. Please try again.';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
