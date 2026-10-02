import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/api/reminders_api.dart';

final remindersApiProvider = Provider(
  (ref) => RemindersApi(ref.read(apiClientProvider)),
);

class ReminderListState {
  final List<Map<String, dynamic>> reminders;
  final bool isLoading;
  final String? error;

  const ReminderListState({
    this.reminders = const [],
    this.isLoading = false,
    this.error,
  });
}

class ReminderListNotifier extends Notifier<ReminderListState> {
  @override
  ReminderListState build() {
    Future.microtask(() => loadReminders());
    return const ReminderListState(isLoading: true);
  }

  Future<void> loadReminders() async {
    state = ReminderListState(reminders: state.reminders, isLoading: true);
    try {
      final result = await ref.read(remindersApiProvider).list();
      final data = result.cast<Map<String, dynamic>>();
      state = ReminderListState(reminders: data);
    } catch (e) {
      state = ReminderListState(
        reminders: state.reminders,
        error: e.toString(),
      );
    }
  }

  Future<void> addReminder(Map<String, dynamic> data) async {
    try {
      await ref.read(remindersApiProvider).create(data);
      await loadReminders();
    } catch (e) {
      state = ReminderListState(
        reminders: state.reminders,
        error: e.toString(),
      );
    }
  }

  Future<void> completeReminder(String id) async {
    try {
      await ref.read(remindersApiProvider).complete(id);
      await loadReminders();
    } catch (e) {
      state = ReminderListState(
        reminders: state.reminders,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      await ref.read(remindersApiProvider).delete(id);
      await loadReminders();
    } catch (e) {
      state = ReminderListState(
        reminders: state.reminders,
        error: e.toString(),
      );
    }
  }
}

final reminderListProvider = NotifierProvider<ReminderListNotifier, ReminderListState>(
  ReminderListNotifier.new,
);
