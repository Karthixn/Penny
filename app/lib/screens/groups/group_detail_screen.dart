import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/groups_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/settlements_provider.dart';
import '../../providers/user_provider.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
String _fmt(int paise) => _currencyFormat.format(paise / 100);

final _groupExpensesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  final data = await ref.read(expensesApiProvider).list(groupId: groupId, limit: 100);
  return (data['data'] as List).cast<Map<String, dynamic>>();
});

final _groupSettlementsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  final list = await ref.read(settlementsApiProvider).list(groupId);
  return list.cast<Map<String, dynamic>>();
});

Color _getAvatarColor(String seed) {
  final colors = [
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF3F51B5), // Indigo
    const Color(0xFF009688), // Teal
    const Color(0xFFE65100), // Deep Orange
    const Color(0xFF1E88E5), // Blue
    const Color(0xFF43A047), // Green
    const Color(0xFF6D4C41), // Brown
    const Color(0xFF546E7A), // Blue Grey
    const Color(0xFFD81B60), // Pink
  ];
  if (seed.isEmpty) return colors[0];
  final hash = seed.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
  return colors[hash % colors.length];
}

String _getInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return parts[0][0].toUpperCase();
}

String _formatActivityDate(dynamic rawDate) {
  if (rawDate == null) return '';
  final dt = rawDate is DateTime ? rawDate : DateTime.tryParse(rawDate.toString())?.toLocal();
  if (dt == null) return '';

  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'min' : 'mins'} ago';
  } else if (diff.inHours < 24 && dt.day == now.day) {
    return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
  } else if (diff.inHours < 48 && dt.day == now.subtract(const Duration(days: 1)).day) {
    return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
  } else if (diff.inDays < 7) {
    return '${DateFormat('EEEE').format(dt)}, ${DateFormat('h:mm a').format(dt)}';
  } else {
    return DateFormat('dd MMM, h:mm a').format(dt);
  }
}

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

  void _refreshAll() {
    ref.invalidate(groupDetailProvider(widget.groupId));
    ref.invalidate(_groupExpensesProvider(widget.groupId));
    ref.invalidate(_groupSettlementsProvider(widget.groupId));
    ref.invalidate(settlementOptimizeProvider(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));
    final currentUser = ref.watch(userProvider).profile;
    final currentUserId = currentUser?['id'] as String?;

    return detailAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF141419),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF2994A))),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFF141419),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _refreshAll,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (detail) {
        final group = detail.group;
        final balances = detail.balances;

        // Calculate current user's balance
        int myBalance = 0;
        if (currentUserId != null) {
          final myRecord = balances.where((b) => b['userId'] == currentUserId || b['user']?['id'] == currentUserId).firstOrNull;
          if (myRecord != null) {
            myBalance = (myRecord['balance'] as num?)?.toInt() ?? 0;
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFF141419),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E24),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  group?['name'] ?? 'Group',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  myBalance > 0
                      ? 'You are owed ${_fmt(myBalance)}'
                      : myBalance < 0
                          ? 'You owe ${_fmt(-myBalance)}'
                          : 'You are all settled up',
                  style: TextStyle(
                    color: myBalance > 0
                        ? const Color(0xFF4CAF50)
                        : myBalance < 0
                            ? const Color(0xFFEF5350)
                            : Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                tooltip: 'Invite Members',
                onPressed: _showInviteDialog,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                color: const Color(0xFF242736),
                onSelected: (value) {
                  if (value == 'invite') {
                    _showInviteDialog();
                  } else if (value == 'settle') {
                    context.push('/settle/${widget.groupId}');
                  } else if (value == 'refresh') {
                    _refreshAll();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'invite',
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_rounded, color: Color(0xFFF2994A), size: 18),
                        SizedBox(width: 8),
                        Text('Invite Code', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settle',
                    child: Row(
                      children: [
                        Icon(Icons.payments_outlined, color: Colors.greenAccent, size: 18),
                        SizedBox(width: 8),
                        Text('Settle Up', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Refresh Data', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: const Color(0xFF1E1E24),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFF2994A),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFFF2994A),
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Expenses'),
                    Tab(text: 'Members'),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(
                groupId: widget.groupId,
                onShowAllExpenses: () => _tabController.animateTo(1),
                onRefresh: _refreshAll,
              ),
              _ExpensesTab(
                groupId: widget.groupId,
                onRefresh: _refreshAll,
              ),
              _MembersTab(
                group: group,
                balances: balances,
                onInviteTap: _showInviteDialog,
                onRefresh: _refreshAll,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFFF2994A),
            elevation: 4,
            shape: const CircleBorder(),
            onPressed: () async {
              await context.push('/add-expense', extra: widget.groupId);
              _refreshAll();
            },
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }

  void _showInviteDialog() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF2994A)),
        ),
      );

      final invite = await ref.read(groupsApiProvider).createInvite(widget.groupId);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss spinner

      final code = (invite['inviteCode'] ?? invite['code'] ?? '').toString();

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E24),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Invite to Group',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share this code with friends so they can join your group on Penny.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C34),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF2994A).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        color: Color(0xFFF2994A),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.white),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invite code "$code" copied to clipboard!'),
                            backgroundColor: const Color(0xFF4CAF50),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Code expires in 7 days',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy_rounded, color: Colors.black, size: 20),
                label: const Text('Copy Invite Code', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2994A),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invite code "$code" copied to clipboard!'),
                      backgroundColor: const Color(0xFF4CAF50),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate invite: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}

// ==========================================
// 1. OVERVIEW TAB (Activity Feed + Debts Breakdown - Screenshot 3)
// ==========================================
class _OverviewTab extends ConsumerWidget {
  final String groupId;
  final VoidCallback onShowAllExpenses;
  final VoidCallback onRefresh;

  const _OverviewTab({
    required this.groupId,
    required this.onShowAllExpenses,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(_groupExpensesProvider(groupId));
    final settlementsAsync = ref.watch(_groupSettlementsProvider(groupId));
    final debtsAsync = ref.watch(settlementOptimizeProvider(groupId));
    final detailAsync = ref.watch(groupDetailProvider(groupId));
    final balances = detailAsync.value?.balances ?? [];

    return RefreshIndicator(
      color: const Color(0xFFF2994A),
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Visual Member Debt Circles (matching Settle Up screenshot)
          _GroupCirclesWidget(balances: balances),

          // Group Switcher Tabs (matching Settle Up screenshot: e.g. "3 IDIOTS", "HSTL", "+")
          _GroupSwitcherBar(currentGroupId: groupId),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 10),
                  child: Text(
                    'Transactions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Section 1: Recent Expenses & Settlements List
                expensesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: Color(0xFFF2994A)),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Could not load activity: $e', style: const TextStyle(color: Colors.redAccent)),
            ),
            data: (expenses) {
              final settlements = settlementsAsync.asData?.value ?? [];

              // Merge expenses & settlements into a combined recent activity stream
              final activityItems = <_ActivityItem>[];
              for (final exp in expenses) {
                activityItems.add(_ActivityItem.expense(exp));
              }
              for (final st in settlements) {
                activityItems.add(_ActivityItem.settlement(st));
              }

              activityItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

              if (activityItems.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, color: Colors.white38, size: 40),
                        SizedBox(height: 10),
                        Text(
                          'No expenses in this group yet',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap + below to add the first expense',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Display top 3 recent activities
              final displayed = activityItems.take(3).toList();

              return Column(
                children: [
                  ...displayed.map((item) {
                    if (item.isExpense) {
                      return _buildExpenseCard(context, item.raw);
                    } else {
                      return _buildSettlementCard(context, item.raw);
                    }
                  }),
                  if (activityItems.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 4),
                      child: TextButton(
                        onPressed: onShowAllExpenses,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFF2994A),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('SHOW ALL'),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Section 2: "Debts" Header & List (Screenshot 3)
          debtsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: Color(0xFFF2994A)),
              ),
            ),
            error: (e, _) => Text('Could not load debts: $e', style: const TextStyle(color: Colors.redAccent)),
            data: (debts) {
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Debts',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
                          onPressed: () {
                            context.push('/settle/$groupId');
                          },
                          tooltip: 'Settle Debts',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (debts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4CAF50), size: 36),
                              SizedBox(height: 8),
                              Text(
                                'All debts are settled! 🎉',
                                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: debts.length,
                        separatorBuilder: (_, index) => const Divider(color: Color(0xFF2C2C34), height: 16),
                        itemBuilder: (context, idx) {
                          final d = debts[idx];
                          final fromUser = d['from'] as Map<String, dynamic>? ?? {};
                          final toUser = d['to'] as Map<String, dynamic>? ?? {};
                          final fromName = fromUser['displayName'] ?? fromUser['email'] ?? 'User';
                          final toName = toUser['displayName'] ?? toUser['email'] ?? 'User';
                          final amountPaise = (d['amount'] as num?)?.toInt() ?? 0;

                          return InkWell(
                            onTap: () => _promptSettleDebt(context, ref, fromUser, toUser, amountPaise),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: Row(
                                children: [
                                  // Debtor Avatar
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _getAvatarColor(fromName),
                                    child: Text(
                                      _getInitials(fromName),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Debtor Name & Amount
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fromName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _fmt(amountPaise),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Orange Forward Arrow
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Color(0xFFF2994A),
                                      size: 22,
                                    ),
                                  ),
                                  // Creditor Name
                                  Expanded(
                                    child: Text(
                                      toName,
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Creditor Avatar
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _getAvatarColor(toName),
                                    child: Text(
                                      _getInitials(toName),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
    const SizedBox(height: 80), // Extra space for FAB
  ],
),
);
  }

  Widget _buildExpenseCard(BuildContext context, Map<String, dynamic> exp) {
    final creator = exp['creator'] as Map<String, dynamic>?;
    final payers = (exp['payers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final splits = (exp['splits'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final payerName = payers.isNotEmpty
        ? (payers.first['user']?['displayName'] ?? 'Someone')
        : (creator?['displayName'] ?? 'Someone');

    final title = (exp['description'] as String?)?.isNotEmpty == true
        ? exp['description'] as String
        : 'Expense';

    final totalAmount = (exp['totalAmount'] as num?)?.toInt() ?? 0;
    final dateStr = _formatActivityDate(exp['date'] ?? exp['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: () {
          if (exp['id'] != null) {
            context.push('/expenses/${exp['id']}');
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _getAvatarColor(payerName),
              child: Text(
                _getInitials(payerName),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Text(
                    '$payerName paid for',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmt(totalAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _buildParticipantChips(splits),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementCard(BuildContext context, Map<String, dynamic> st) {
    final payer = st['payer'] as Map<String, dynamic>?;
    final payee = st['payee'] as Map<String, dynamic>?;
    final payerName = payer?['displayName'] ?? 'Someone';
    final payeeName = payee?['displayName'] ?? 'Someone';
    final amount = (st['amount'] as num?)?.toInt() ?? 0;
    final dateStr = _formatActivityDate(st['settledAt'] ?? st['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF2C2C34),
            child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFF2994A), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Debt settlement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                Text(
                  'From $payerName to',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(amount),
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              CircleAvatar(
                radius: 11,
                backgroundColor: _getAvatarColor(payeeName),
                child: Text(
                  _getInitials(payeeName),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantChips(List<Map<String, dynamic>> splits) {
    if (splits.isEmpty) return const SizedBox.shrink();
    final displayed = splits.take(4).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < displayed.length; i++)
          Container(
            margin: const EdgeInsets.only(left: 3),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _getAvatarColor(displayed[i]['user']?['displayName'] ?? '$i'),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1E1E24), width: 1.5),
            ),
            child: Center(
              child: Text(
                _getInitials(displayed[i]['user']?['displayName']),
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (splits.length > 4)
          Container(
            margin: const EdgeInsets.only(left: 3),
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFF383842),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+${splits.length - 4}',
                style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  void _promptSettleDebt(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> fromUser,
    Map<String, dynamic> toUser,
    int amountPaise,
  ) {
    final fromName = fromUser['displayName'] ?? 'User';
    final toName = toUser['displayName'] ?? 'User';
    final payeeId = toUser['id'] as String?;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            const Text(
              'Record Debt Settlement',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C34),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getAvatarColor(fromName),
                    child: Text(_getInitials(fromName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$fromName pays $toName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(_fmt(amountPaise), style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getAvatarColor(toName),
                    child: Text(_getInitials(toName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF2994A),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                if (payeeId == null) return;
                try {
                  await ref.read(settlementsApiProvider).create({
                    'groupId': groupId,
                    'payeeId': payeeId,
                    'amount': amountPaise,
                  });
                  onRefresh();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Settlement of ${_fmt(amountPaise)} recorded!'),
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                    );
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $err'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text('Confirm Settlement', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper model to blend expenses and settlements
class _ActivityItem {
  final bool isExpense;
  final DateTime timestamp;
  final Map<String, dynamic> raw;

  _ActivityItem._(this.isExpense, this.timestamp, this.raw);

  factory _ActivityItem.expense(Map<String, dynamic> exp) {
    final rawDate = exp['date'] ?? exp['createdAt'];
    final dt = rawDate is DateTime ? rawDate : DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now();
    return _ActivityItem._(true, dt, exp);
  }

  factory _ActivityItem.settlement(Map<String, dynamic> st) {
    final rawDate = st['settledAt'] ?? st['createdAt'];
    final dt = rawDate is DateTime ? rawDate : DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now();
    return _ActivityItem._(false, dt, st);
  }
}

// ==========================================
// 2. EXPENSES TAB (Full List of Expenses)
// ==========================================
class _ExpensesTab extends ConsumerWidget {
  final String groupId;
  final VoidCallback onRefresh;

  const _ExpensesTab({
    required this.groupId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(_groupExpensesProvider(groupId));

    return RefreshIndicator(
      color: const Color(0xFFF2994A),
      onRefresh: () async => onRefresh(),
      child: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF2994A))),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onRefresh,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (groupExpenses) {
          if (groupExpenses.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_outlined, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text('No expenses in this group yet', style: TextStyle(color: Colors.white60, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('Tap the + button to add one', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: groupExpenses.length,
            itemBuilder: (context, index) {
              final exp = groupExpenses[index];
              final creator = exp['creator'] as Map<String, dynamic>?;
              final payers = (exp['payers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              final splits = (exp['splits'] as List?)?.cast<Map<String, dynamic>>() ?? [];

              final payerName = payers.isNotEmpty
                  ? (payers.first['user']?['displayName'] ?? 'Someone')
                  : (creator?['displayName'] ?? 'Someone');

              final totalAmount = (exp['totalAmount'] as num?)?.toInt() ?? 0;
              final dateStr = _formatActivityDate(exp['date'] ?? exp['createdAt']);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  onTap: () {
                    if (exp['id'] != null) {
                      context.push('/expenses/${exp['id']}');
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _getAvatarColor(payerName),
                        child: Text(
                          _getInitials(payerName),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exp['description'] as String? ?? 'Expense',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$dateStr • by $payerName',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fmt(totalAmount),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${splits.length} split',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 3. MEMBERS TAB (Screenshot 2 Match)
// ==========================================
class _MembersTab extends StatelessWidget {
  final Map<String, dynamic>? group;
  final List<Map<String, dynamic>> balances;
  final VoidCallback onInviteTap;
  final VoidCallback onRefresh;

  const _MembersTab({
    required this.group,
    required this.balances,
    required this.onInviteTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final members = (group?['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Map each userId to their balance and spent amounts
    final balanceMap = <String, Map<String, dynamic>>{};
    for (final b in balances) {
      final uid = b['userId'] ?? b['user']?['id'];
      if (uid != null) {
        balanceMap[uid.toString()] = b;
      }
    }

    return RefreshIndicator(
      color: const Color(0xFFF2994A),
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: members.length + 1, // +1 for "New member" button at bottom
        itemBuilder: (context, index) {
          // Bottom item is "New member" button (matching Screenshot 2)
          if (index == members.length) {
            return InkWell(
              onTap: onInviteTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(top: 4, bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C34),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFFF2994A),
                      child: Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.black, // Dark icon inside orange circle like Screenshot 2
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 14),
                    Text(
                      'New member',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final m = members[index];
          final user = m['user'] as Map<String, dynamic>? ?? {};
          final uid = user['id']?.toString() ?? m['userId']?.toString() ?? '';
          final displayName = user['displayName'] ?? user['email'] ?? 'Member';

          // Retrieve balance & spent calculated from backend
          final balInfo = balanceMap[uid];
          final balancePaise = (balInfo?['balance'] as num?)?.toInt() ?? 0;
          final spentPaise = (balInfo?['spent'] as num?)?.toInt() ?? 0;

          final isPositive = balancePaise > 0;
          final isNegative = balancePaise < 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C34), // Dark grey card matching Screenshot 2
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Initials circle avatar with distinctive pastel/material background
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _getAvatarColor(displayName),
                  child: Text(
                    _getInitials(displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Name & Total Spent
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Spent: ${_fmt(spentPaise)}',
                        style: const TextStyle(
                          color: Color(0xFFA0A0A8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Net Balance (+green / -red / ₹0.00 grey)
                Text(
                  isPositive
                      ? _fmt(balancePaise)
                      : isNegative
                          ? '-${_fmt(-balancePaise)}'
                          : _fmt(0),
                  style: TextStyle(
                    color: isPositive
                        ? const Color(0xFF4CAF50) // Soft vibrant green
                        : isNegative
                            ? const Color(0xFFEF5350) // Soft vibrant red
                            : Colors.white38,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 4. VISUAL GROUP CIRCLES WIDGET (Settle Up Style)
// ==========================================
class _GroupCirclesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> balances;

  const _GroupCirclesWidget({required this.balances});

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        color: Colors.black,
        child: const Text('Add group expenses to see debt circles', style: TextStyle(color: Colors.white38)),
      );
    }

    // Sort balances ascending: most negative first (biggest debtor)
    final sorted = List<Map<String, dynamic>>.from(balances)
      ..sort((a, b) => ((a['balance'] as num?)?.toInt() ?? 0).compareTo((b['balance'] as num?)?.toInt() ?? 0));

    final primaryDebtor = sorted.first;
    final primaryBalance = (primaryDebtor['balance'] as num?)?.toInt() ?? 0;
    final hasDebts = primaryBalance < 0;

    final otherMembers = sorted.sublist(1);

    return Container(
      height: 270,
      width: double.infinity,
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;
          const centerY = 135.0;

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Surrounding member bubbles
              for (int i = 0; i < otherMembers.length; i++)
                _buildSurroundingBubble(otherMembers[i], i, otherMembers.length, centerX, centerY),

              // Center primary debtor bubble (or all settled up bubble)
              _buildCenterBubble(primaryDebtor, primaryBalance, hasDebts, centerX, centerY),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSurroundingBubble(Map<String, dynamic> item, int index, int total, double cx, double cy) {
    final balancePaise = (item['balance'] as num?)?.toInt() ?? 0;
    final user = item['user'] as Map<String, dynamic>? ?? {};
    final name = (user['displayName'] ?? user['email'] ?? 'Member').toString();

    final absPaise = balancePaise.abs();
    final double radius = (38.0 + (absPaise / 100000.0) * 14.0).clamp(34.0, 52.0);

    final double angle = -math.pi / 2 + (2 * math.pi * index / total) + 0.35;
    final double dist = 94.0;
    final double x = cx + dist * math.cos(angle) - radius;
    final double y = cy + dist * math.sin(angle) - radius;

    final isNegative = balancePaise < 0;
    final isPositive = balancePaise > 0;

    final bubbleColor = isNegative
        ? const Color(0xFFD35400).withValues(alpha: 0.85)
        : isPositive
            ? const Color(0xFF4E342E).withValues(alpha: 0.88)
            : const Color(0xFF2C2C34);

    final borderColor = isNegative
        ? const Color(0xFFE67E22).withValues(alpha: 0.6)
        : isPositive
            ? const Color(0xFF8D6E63).withValues(alpha: 0.6)
            : Colors.white12;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: bubbleColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: bubbleColor.withValues(alpha: 0.25),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              isNegative
                  ? '-₹${(-balancePaise / 100).toStringAsFixed(balancePaise % 100 == 0 ? 0 : 2)}'
                  : isPositive
                      ? '+₹${(balancePaise / 100).toStringAsFixed(balancePaise % 100 == 0 ? 0 : 2)}'
                      : '₹0',
              style: TextStyle(
                color: isNegative ? const Color(0xFFFFCC80) : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterBubble(Map<String, dynamic> item, int balancePaise, bool hasDebts, double cx, double cy) {
    final user = item['user'] as Map<String, dynamic>? ?? {};
    final name = (user['displayName'] ?? user['email'] ?? 'Member').toString();
    const double radius = 56.0;

    return Positioned(
      left: cx - radius,
      top: cy - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: hasDebts ? const Color(0xFFE67E22).withValues(alpha: 0.95) : const Color(0xFF4CAF50).withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE67E22).withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 3,
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              balancePaise < 0
                  ? '-₹${(-balancePaise / 100).toStringAsFixed(2)}'
                  : '₹${(balancePaise / 100).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
            if (hasDebts) ...[
              const SizedBox(height: 1),
              const Text(
                'should pay',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. GROUP SWITCHER BAR (Tabs for switching groups)
// ==========================================
class _GroupSwitcherBar extends ConsumerWidget {
  final String currentGroupId;

  const _GroupSwitcherBar({required this.currentGroupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupList = ref.watch(groupListProvider);
    final groups = groupList.groups;

    return Container(
      height: 44,
      color: Colors.black,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final g in groups) ...[
            Builder(builder: (ctx) {
              final gid = (g['id'] ?? '') as String;
              final gname = (g['name'] ?? 'Group').toString().toUpperCase();
              final isCurrent = gid == currentGroupId;

              return InkWell(
                onTap: () {
                  if (!isCurrent && gid.isNotEmpty) {
                    context.pushReplacement('/groups/$gid');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isCurrent ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    gname,
                    style: TextStyle(
                      color: isCurrent ? Colors.white : Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }),
          ],
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white70, size: 20),
            tooltip: 'All Groups',
            onPressed: () {
              context.push('/groups');
            },
          ),
        ],
      ),
    );
  }
}

