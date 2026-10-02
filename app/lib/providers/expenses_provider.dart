import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/api/expenses_api.dart';

final expensesApiProvider = Provider(
  (ref) => ExpensesApi(ref.read(apiClientProvider)),
);

class ExpenseListState {
  final List<Map<String, dynamic>> expenses;
  final bool isLoading;
  final String? error;

  const ExpenseListState({
    this.expenses = const [],
    this.isLoading = false,
    this.error,
  });
}

class ExpenseListNotifier extends Notifier<ExpenseListState> {
  @override
  ExpenseListState build() {
    Future.microtask(() => loadExpenses());
    return const ExpenseListState(isLoading: true);
  }

  Future<void> loadExpenses({int page = 1}) async {
    state = ExpenseListState(expenses: state.expenses, isLoading: true);
    try {
      final result = await ref.read(expensesApiProvider).list(page: page);
      final rawData = result['data'];
      final List<Map<String, dynamic>> list = [];
      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
      }
      state = ExpenseListState(expenses: list, isLoading: false);
    } catch (e) {
      state = ExpenseListState(
        expenses: state.expenses,
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> addExpense(Map<String, dynamic> data) async {
    await ref.read(expensesApiProvider).create(data);
    await loadExpenses();
  }

  Future<void> deleteExpense(String id) async {
    await ref.read(expensesApiProvider).delete(id);
    await loadExpenses();
  }
}

final expenseListProvider =
    NotifierProvider<ExpenseListNotifier, ExpenseListState>(
  ExpenseListNotifier.new,
);

class MonthlyStatsState {
  final int totalSpent;
  final Map<String, int> byCategory;
  final bool isLoading;

  const MonthlyStatsState({
    this.totalSpent = 0,
    this.byCategory = const {},
    this.isLoading = false,
  });
}

class MonthlyStatsNotifier extends Notifier<MonthlyStatsState> {
  @override
  MonthlyStatsState build() {
    final now = DateTime.now();
    Future.microtask(() => loadStats(now.year, now.month));
    return const MonthlyStatsState(isLoading: true);
  }

  Future<void> loadStats(int year, int month) async {
    state = MonthlyStatsState(
      totalSpent: state.totalSpent,
      byCategory: state.byCategory,
      isLoading: true,
    );
    try {
      final result = await ref.read(expensesApiProvider).getStats(year, month);
      final rawSpent = result['totalSpent'];
      final totalSpent = rawSpent is num ? rawSpent.toInt() : 0;
      final rawCategories = result['byCategory'];
      final Map<String, int> categories = {};
      if (rawCategories is Map) {
        for (final entry in rawCategories.entries) {
          if (entry.value is num) {
            categories[entry.key.toString()] = (entry.value as num).toInt();
          }
        }
      }
      state = MonthlyStatsState(
        totalSpent: totalSpent,
        byCategory: categories,
        isLoading: false,
      );
    } catch (_) {
      state = MonthlyStatsState(
        totalSpent: state.totalSpent,
        byCategory: state.byCategory,
        isLoading: false,
      );
    }
  }
}

final monthlyStatsProvider =
    NotifierProvider<MonthlyStatsNotifier, MonthlyStatsState>(
  MonthlyStatsNotifier.new,
);
