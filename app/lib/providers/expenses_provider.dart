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
    loadExpenses();
    return const ExpenseListState(isLoading: true);
  }

  Future<void> loadExpenses({int page = 1}) async {
    state = ExpenseListState(expenses: state.expenses, isLoading: true);
    try {
      final result = await ref.read(expensesApiProvider).list(page: page);
      final data = (result['data'] as List).cast<Map<String, dynamic>>();
      state = ExpenseListState(expenses: data);
    } catch (e) {
      state = ExpenseListState(
        expenses: state.expenses,
        error: e.toString(),
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
    loadStats(now.year, now.month);
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
      state = MonthlyStatsState(
        totalSpent: result['totalSpent'] as int,
        byCategory: (result['byCategory'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
      );
    } catch (_) {
      state = MonthlyStatsState(
        totalSpent: state.totalSpent,
        byCategory: state.byCategory,
      );
    }
  }
}

final monthlyStatsProvider =
    NotifierProvider<MonthlyStatsNotifier, MonthlyStatsState>(
  MonthlyStatsNotifier.new,
);
