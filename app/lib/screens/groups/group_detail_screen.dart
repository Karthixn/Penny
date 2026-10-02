import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/groups_provider.dart';
import '../../providers/expenses_provider.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
String _fmt(int paise) => _currencyFormat.format(paise / 100);

final _groupExpensesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  final data = await ref.read(expensesApiProvider).list(groupId: groupId);
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));

    return detailAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (detail) {
        final group = detail.group;

        return Scaffold(
          appBar: AppBar(
            title: Text(group?['name'] ?? 'Group'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                onPressed: _showInviteDialog,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textTertiary,
              tabs: const [
                Tab(text: 'Expenses'),
                Tab(text: 'Balances'),
                Tab(text: 'Members'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _ExpensesTab(groupId: widget.groupId),
              _BalancesTab(balances: detail.balances, groupId: widget.groupId),
              _MembersTab(group: group),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.primary,
            onPressed: () => context.push('/add-expense', extra: widget.groupId),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  void _showInviteDialog() async {
    try {
      final invite = await ref.read(groupsApiProvider).createInvite(widget.groupId);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Invite Code', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share this code:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              SelectableText(
                invite['inviteCode'] as String,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Expires in 7 days', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (_) {}
  }
}

class _ExpensesTab extends ConsumerWidget {
  final String groupId;
  const _ExpensesTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(_groupExpensesProvider(groupId));

    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (groupExpenses) {
        if (groupExpenses.isEmpty) {
          return const Center(
            child: Text('No expenses in this group yet',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupExpenses.length,
          itemBuilder: (context, index) {
            final exp = groupExpenses[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(exp['description'] as String,
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            'by ${(exp['creator'] as Map?)?['displayName'] ?? 'Unknown'}',
                            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _fmt(exp['totalAmount'] as int),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BalancesTab extends StatelessWidget {
  final List<Map<String, dynamic>> balances;
  final String groupId;
  const _BalancesTab({required this.balances, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (balances.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => context.push('/settle/$groupId'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Settle Up', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        Expanded(
          child: balances.isEmpty
              ? const Center(
                  child: Text('No balances to show', style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: balances.length,
                  itemBuilder: (context, index) {
                    final b = balances[index];
                    final user = b['user'] as Map<String, dynamic>;
                    final balance = b['balance'] as int;
                    final isPositive = balance >= 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                ((user['displayName'] as String?) ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['displayName'] as String? ?? user['email'] as String,
                                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    balance == 0
                                        ? 'Settled up'
                                        : isPositive
                                            ? 'Gets back ${_fmt(balance)}'
                                            : 'Owes ${_fmt(-balance)}',
                                    style: TextStyle(
                                      color: balance == 0
                                          ? AppColors.textTertiary
                                          : isPositive
                                              ? AppColors.green
                                              : AppColors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _fmt(balance.abs()),
                              style: TextStyle(
                                color: balance == 0
                                    ? AppColors.textTertiary
                                    : isPositive
                                        ? AppColors.green
                                        : AppColors.red,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MembersTab extends StatelessWidget {
  final Map<String, dynamic>? group;
  const _MembersTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final members = (group?['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final m = members[index];
        final user = m['user'] as Map<String, dynamic>;
        final role = m['role'] as String;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    ((user['displayName'] as String?) ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['displayName'] as String? ?? user['email'] as String,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                      ),
                      Text(user['email'] as String,
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
                if (role == 'admin')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Admin',
                        style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
