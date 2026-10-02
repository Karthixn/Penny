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

  const UserState({
    this.profile,
    this.isLoading = false,
    this.error,
  });
}

class UserNotifier extends Notifier<UserState> {
  @override
  UserState build() {
    loadProfile();
    return const UserState(isLoading: true);
  }

  Future<void> loadProfile() async {
    state = UserState(profile: state.profile, isLoading: true);
    try {
      final result = await ref.read(usersApiProvider).getProfile();
      state = UserState(profile: result);
    } catch (e) {
      state = UserState(
        profile: state.profile,
        error: e.toString(),
      );
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await ref.read(usersApiProvider).updateProfile(data);
      await loadProfile();
    } catch (e) {
      state = UserState(
        profile: state.profile,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteAccount() async {
    try {
      await ref.read(usersApiProvider).deleteAccount();
    } catch (e) {
      state = UserState(
        profile: state.profile,
        error: e.toString(),
      );
    }
  }
}

final userProvider = NotifierProvider<UserNotifier, UserState>(
  UserNotifier.new,
);
