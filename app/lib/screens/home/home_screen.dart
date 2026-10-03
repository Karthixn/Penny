import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/category_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/user_provider.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

String _formatPaise(int paise) => _currencyFormat.format(paise / 100);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseListProvider);
    final stats = ref.watch(monthlyStatsProvider);
    final userState = ref.watch(userProvider);
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);
    final userName = userState.profile?['displayName'] as String? ?? 'User';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(expenseListProvider.notifier).loadExpenses();
            await ref.read(monthlyStatsProvider.notifier).loadStats(now.year, now.month);
            await ref.read(userProvider.notifier).loadProfile();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(monthLabel, style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 4),
                              Text('Hello, $userName', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.primary)),
                              const SizedBox(height: 4),
                              Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
                            ],
                          ),
                          IconButton(
                            onPressed: () => ref.read(authProvider.notifier).logout(),
                            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Stats card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Spent this month', style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 8),
                            stats.isLoading
                                ? const SizedBox(
                                    height: 36,
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : Text(
                                    _formatPaise(stats.totalSpent),
                                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                            if (stats.byCategory.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: stats.byCategory.entries.map((e) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${e.key}: ${_formatPaise(e.value)}',
                                      style: const TextStyle(color: AppColors.primaryLight, fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text('Recent Expenses', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Expense list
              if (expenses.isLoading && expenses.expenses.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (expenses.expenses.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long, size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        const Text('No expenses yet',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text('Tap + to add your first expense',
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final exp = expenses.expenses[index];
                      final amount = exp['totalAmount'] as int;
                      final category = exp['category'] as String? ?? 'other';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        child: Dismissible(
                          key: Key(exp['id'] as String),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.red,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            ref.read(expenseListProvider.notifier).deleteExpense(exp['id'] as String);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Expense deleted')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: CategoryConstants.getColor(category).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    CategoryConstants.getIcon(category),
                                    color: CategoryConstants.getColor(category),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exp['description'] as String,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CategoryConstants.getLabel(category),
                                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatPaise(amount),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: expenses.expenses.length,
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/add-expense'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
