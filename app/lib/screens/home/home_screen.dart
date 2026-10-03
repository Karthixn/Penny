import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/category_constants.dart';
import '../../core/constants/payment_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/user_provider.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String _formatPaise(int paise) => _currencyFormat.format(paise / 100);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _viewMode = 'personal'; // 'personal' | 'groups' | 'all'
  String _personalFilter = 'all'; // 'all' | 'expense' | 'income'

  void _showSetBudgetDialog(BuildContext context, int currentBudgetPaise) {
    final controller = TextEditingController(
      text: currentBudgetPaise > 0 ? (currentBudgetPaise / 100).toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Monthly Budget Target',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a spending limit for your personal monthly expenses to keep your finances healthy.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: Color(0xFFF2994A), fontSize: 22, fontWeight: FontWeight.bold),
                hintText: 'e.g. 20000',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 16),
                filled: true,
                fillColor: const Color(0xFF282830),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF2994A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final val = double.tryParse(controller.text.trim());
              final paise = val != null ? (val * 100).round() : 0;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await ref.read(userProvider.notifier).updateProfile({'monthlyBudget': paise});
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Monthly budget updated successfully!')),
                );
              }
            },
            child: const Text('Save Budget', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expenseListProvider);
    final stats = ref.watch(monthlyStatsProvider);
    final userState = ref.watch(userProvider);
    final groupsState = ref.watch(groupListProvider);

    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);
    final userName = userState.profile?['displayName'] as String? ?? 'User';
    final monthlyBudget = (userState.profile?['monthlyBudget'] as num?)?.toInt() ?? 0;

    final allItems = expensesState.expenses;

    // Filter personal vs group transactions
    final personalItems = allItems.where((e) => e['groupId'] == null).toList();
    final groupItems = allItems.where((e) => e['groupId'] != null).toList();

    // Personal Cashflow calculations
    int personalSpent = 0;
    int personalIncome = 0;
    for (final e in personalItems) {
      final amt = (e['totalAmount'] as num?)?.toInt() ?? 0;
      final type = e['type'] as String? ?? 'expense';
      if (type == 'income') {
        personalIncome += amt;
      } else {
        personalSpent += amt;
      }
    }
    final personalNetSavings = personalIncome - personalSpent;

    // Group total spend
    int groupTotalSpent = 0;
    for (final e in groupItems) {
      final amt = (e['totalAmount'] as num?)?.toInt() ?? 0;
      groupTotalSpent += amt;
    }

    // List to display according to viewMode
    final List<Map<String, dynamic>> displayedItems;
    if (_viewMode == 'personal') {
      if (_personalFilter == 'expense') {
        displayedItems = personalItems.where((e) => (e['type'] as String? ?? 'expense') == 'expense').toList();
      } else if (_personalFilter == 'income') {
        displayedItems = personalItems.where((e) => (e['type'] as String? ?? 'expense') == 'income').toList();
      } else {
        displayedItems = personalItems;
      }
    } else if (_viewMode == 'groups') {
      displayedItems = groupItems;
    } else {
      displayedItems = allItems;
    }

    // Budget Calculations
    final budgetRemaining = monthlyBudget - personalSpent;
    final budgetProgress = monthlyBudget > 0 ? (personalSpent / monthlyBudget).clamp(0.0, 1.0) : 0.0;
    final isBudgetExceeded = monthlyBudget > 0 && personalSpent > monthlyBudget;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(expenseListProvider.notifier).loadExpenses();
            await ref.read(monthlyStatsProvider.notifier).loadStats(now.year, now.month);
            await ref.read(userProvider.notifier).loadProfile();
            await ref.read(groupListProvider.notifier).loadGroups();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(monthLabel, style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 2),
                              Text('Hello, $userName',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      )),
                              const SizedBox(height: 2),
                              Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
                            ],
                          ),
                          IconButton(
                            onPressed: () => ref.read(authProvider.notifier).logout(),
                            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                            tooltip: 'Log out',
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Segmented Mode Selector: Personal | Groups | All
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2C2C34)),
                        ),
                        child: Row(
                          children: [
                            _buildSegmentTab(
                              id: 'personal',
                              title: 'Personal Tracker',
                              icon: Icons.person_outline,
                              count: personalItems.length,
                            ),
                            _buildSegmentTab(
                              id: 'groups',
                              title: 'Groups',
                              icon: Icons.group_outlined,
                              count: groupItems.length,
                            ),
                            _buildSegmentTab(
                              id: 'all',
                              title: 'Overview',
                              icon: Icons.grid_view,
                              count: allItems.length,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // VIEW 1: DEDICATED PERSONAL TRACKER
                      if (_viewMode == 'personal') ...[
                        // Personal Monthly Budget Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isBudgetExceeded ? const Color(0xFFEF4444).withValues(alpha: 0.6) : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.savings_outlined,
                                        size: 20,
                                        color: isBudgetExceeded ? const Color(0xFFEF4444) : const Color(0xFF00D68F),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Personal Monthly Budget',
                                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                    tooltip: 'Set / Edit Monthly Budget',
                                    onPressed: () => _showSetBudgetDialog(context, monthlyBudget),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (monthlyBudget > 0) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Spent so far', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatPaise(personalSpent),
                                          style: TextStyle(
                                            color: isBudgetExceeded ? const Color(0xFFEF4444) : Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          isBudgetExceeded ? 'Exceeded by' : 'Remaining',
                                          style: TextStyle(
                                            color: isBudgetExceeded ? const Color(0xFFEF4444) : Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatPaise(budgetRemaining.abs()),
                                          style: TextStyle(
                                            color: isBudgetExceeded ? const Color(0xFFEF4444) : const Color(0xFF00D68F),
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: budgetProgress,
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFF2C2C34),
                                    valueColor: AlwaysStoppedAnimation(
                                      isBudgetExceeded
                                          ? const Color(0xFFEF4444)
                                          : (budgetProgress > 0.8 ? const Color(0xFFF2994A) : const Color(0xFF00D68F)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Target: ${_formatPaise(monthlyBudget)}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                    Text(
                                      '${(budgetProgress * 100).toStringAsFixed(0)}% used',
                                      style: TextStyle(
                                        color: isBudgetExceeded ? const Color(0xFFEF4444) : Colors.white60,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Spent: ${_formatPaise(personalSpent)}',
                                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              'Set a budget target to monitor your monthly limit',
                                              style: TextStyle(color: Colors.white54, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        onPressed: () => _showSetBudgetDialog(context, monthlyBudget),
                                        child: const Text('Set Budget',
                                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Personal Cashflow Summary Cards
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E24),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2C2C34)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.arrow_downward, size: 14, color: const Color(0xFF00D68F)),
                                        const SizedBox(width: 4),
                                        const Text('Income', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatPaise(personalIncome),
                                      style: const TextStyle(color: Color(0xFF00D68F), fontSize: 17, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E24),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2C2C34)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.arrow_upward, size: 14, color: const Color(0xFFEF4444)),
                                        const SizedBox(width: 4),
                                        const Text('Expense', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatPaise(personalSpent),
                                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 17, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E24),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2C2C34)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.account_balance_wallet_outlined, size: 14, color: const Color(0xFFF2994A)),
                                        const SizedBox(width: 4),
                                        const Text('Savings', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatPaise(personalNetSavings),
                                      style: TextStyle(
                                        color: personalNetSavings >= 0 ? const Color(0xFF00D68F) : const Color(0xFFEF4444),
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Filter Chips (All | Expenses | Income)
                        Row(
                          children: [
                            _buildPersonalFilterChip('all', 'All (${personalItems.length})'),
                            const SizedBox(width: 8),
                            _buildPersonalFilterChip(
                                'expense',
                                'Expenses (${personalItems.where((e) => (e['type'] as String? ?? 'expense') == 'expense').length})'),
                            const SizedBox(width: 8),
                            _buildPersonalFilterChip(
                                'income',
                                'Income (${personalItems.where((e) => (e['type'] as String? ?? 'expense') == 'income').length})'),
                          ],
                        ),
                      ],

                      // VIEW 2: GROUP EXPENSES VIEW
                      if (_viewMode == 'groups') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Group Spendings',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9B51E0).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${groupsState.groups.length} Groups Active',
                                      style: const TextStyle(color: Color(0xFFBB6BD9), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _formatPaise(groupTotalSpent),
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text('Total expenses recorded across your groups',
                                  style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],

                      // VIEW 3: OVERVIEW (ALL)
                      if (_viewMode == 'all') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Spent this month',
                                  style: TextStyle(color: Colors.white54, fontSize: 14)),
                              const SizedBox(height: 8),
                              stats.isLoading
                                  ? const SizedBox(
                                      height: 36,
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    )
                                  : Text(
                                      _formatPaise(stats.totalSpent),
                                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                              if (stats.byCategory.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: stats.byCategory.entries.map((e) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      ],

                      const SizedBox(height: 22),

                      // Section Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _viewMode == 'personal'
                                ? 'Personal Transactions'
                                : (_viewMode == 'groups' ? 'Group Transactions' : 'All Transactions'),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${displayedItems.length} items',
                            style: const TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // TRANSACTIONS LIST
              if (expensesState.isLoading && displayedItems.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (displayedItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _viewMode == 'personal'
                                ? Icons.account_balance_wallet_outlined
                                : (_viewMode == 'groups' ? Icons.group_outlined : Icons.receipt_long),
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _viewMode == 'personal'
                                ? 'No personal transactions yet'
                                : (_viewMode == 'groups' ? 'No group expenses yet' : 'No expenses recorded'),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _viewMode == 'personal'
                                ? 'Tap + to record your daily spending or income'
                                : (_viewMode == 'groups'
                                    ? 'Tap + to split bills with friends & roommates'
                                    : 'Tap + to add your first expense'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final exp = displayedItems[index];
                      final amount = (exp['totalAmount'] as num?)?.toInt() ?? 0;
                      final category = exp['category'] as String? ?? 'other';
                      final type = exp['type'] as String? ?? 'expense';
                      final isIncome = type == 'income';
                      final isGroupExp = exp['groupId'] != null;
                      final catMeta = CategoryConstants.get(category);
                      final payMethod = exp['paymentMethod'] as String? ?? 'upi';
                      final payMeta = PaymentConstants.get(payMethod);

                      final rawDate = exp['date'] as String?;
                      String formattedDate = '';
                      if (rawDate != null) {
                        try {
                          formattedDate = DateFormat('dd MMM').format(DateTime.parse(rawDate).toLocal());
                        } catch (_) {}
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Dismissible(
                          key: Key(exp['id'] as String),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.red,
                              borderRadius: BorderRadius.circular(16),
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
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF24242C)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => context.push('/expenses/${exp['id']}'),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Category Icon Avatar
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: catMeta.color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          catMeta.icon,
                                          color: catMeta.color,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exp['description'] as String? ?? 'Expense',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (formattedDate.isNotEmpty) ...[
                                                  Text(
                                                    formattedDate,
                                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text('•', style: TextStyle(color: Colors.white24, fontSize: 10)),
                                                  const SizedBox(width: 6),
                                                ],
                                                Text(
                                                  catMeta.label,
                                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                ),
                                                const SizedBox(width: 8),
                                                // Group vs Personal badge (in All tab)
                                                if (_viewMode == 'all') ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: (isGroupExp ? const Color(0xFF9B51E0) : const Color(0xFF2F80ED))
                                                          .withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      isGroupExp ? '👥 Group' : '👤 Personal',
                                                      style: TextStyle(
                                                        color: isGroupExp ? const Color(0xFF9B51E0) : const Color(0xFF2F80ED),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                // Payment Mode chip
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF282830),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(payMeta.icon, size: 9, color: Colors.white54),
                                                      const SizedBox(width: 3),
                                                      Text(payMeta.label,
                                                          style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      // Amount
                                      Text(
                                        '${isIncome ? '+' : '-'} ${_formatPaise(amount)}',
                                        style: TextStyle(
                                          color: isIncome ? const Color(0xFF00D68F) : Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: displayedItems.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/add-expense'),
        icon: const Icon(Icons.add, color: Colors.black),
        label: Text(
          _viewMode == 'personal' ? 'Add Personal' : (_viewMode == 'groups' ? 'Add Group' : 'Add Expense'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSegmentTab({
    required String id,
    required String title,
    required IconData icon,
    required int count,
  }) {
    final isSel = _viewMode == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSel ? Colors.black : Colors.white60),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSel ? Colors.black : Colors.white60,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalFilterChip(String filter, String label) {
    final isSel = _personalFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _personalFilter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFF2994A).withValues(alpha: 0.15) : const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? const Color(0xFFF2994A) : const Color(0xFF2C2C34),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSel ? const Color(0xFFF2994A) : Colors.white54,
              fontSize: 11,
              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
