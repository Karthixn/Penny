import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/api/users_api.dart';

final usersApiProvider = Provider(
  (ref) => UsersApi(ref.read(apiClientProvider)),
);

class UserState {
  final Map<String, dynamic>? profile;
  final bool isLoading;
  final String? error;
  final bool isAuthError;

  const UserState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.isAuthError = false,
  });
}

class UserNotifier extends Notifier<UserState> {
  @override
  UserState build() {
    final auth = ref.watch(authProvider);
    if (auth.status == AuthStatus.authenticated) {
      Future.microtask(() => loadProfile());
      return const UserState(isLoading: true);
    }
    return const UserState(profile: null, isLoading: false);
  }

  Future<void> loadProfile() async {
    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.authenticated) {
      state = const UserState(profile: null, isLoading: false);
      return;
    }
    state = UserState(profile: state.profile, isLoading: true);
    try {
      final result = await ref.read(usersApiProvider).getProfile();
      state = UserState(profile: result, isLoading: false);
    } catch (e) {
      final isAuth = e is DioException && e.response?.statusCode == 401;
      state = UserState(
        profile: state.profile,
        isLoading: false,
        error: _formatError(e),
        isAuthError: isAuth,
      );
    }
  }

  String _formatError(dynamic e) {
    if (e is DioException) {
      if (e.response?.statusCode == 401) {
        return 'Session expired. Please sign in again to continue.';
      }
      final resData = e.response?.data;
      if (resData is Map && resData['message'] != null) {
        final msg = resData['message'];
        if (msg is List && msg.isNotEmpty) return msg.first.toString();
        if (msg is String) return msg;
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Could not connect to server. Check your network.';
      }
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Server took too long to respond. Cloud instance may be waking up.';
      }
    }
    return 'Could not load profile. Please tap retry.';
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await ref.read(usersApiProvider).updateProfile(data);
      await loadProfile();
    } catch (e) {
      state = UserState(
        profile: state.profile,
        error: _formatError(e),
      );
    }
  }

  Future<void> deleteAccount() async {
    try {
      await ref.read(usersApiProvider).deleteAccount();
    } catch (e) {
      state = UserState(
        profile: state.profile,
        error: _formatError(e),
      );
    }
  }
}

final userProvider = NotifierProvider<UserNotifier, UserState>(
  UserNotifier.new,
);
