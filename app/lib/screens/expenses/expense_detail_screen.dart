import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/expenses_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateFmt = DateFormat('MMM d, yyyy');

String _fmt(int paise) => _currFmt.format(paise / 100);

final _expenseDetailProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final api = ref.read(expensesApiProvider);
    return api.getOne(id);
  },
);

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_expenseDetailProvider(expenseId));

    return detailAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Expense')),
        body: Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.red))),
      ),
      data: (expense) {
        final amount = expense['totalAmount'] as int;
        final category = expense['category'] as String? ?? 'other';
        final description = expense['description'] as String;
        final date = DateTime.tryParse(expense['date'] as String? ?? '') ?? DateTime.now();
        final creator = expense['creator'] as Map<String, dynamic>?;
        final payers = (expense['payers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final splits = (expense['splits'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final items = (expense['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final groupId = expense['groupId'] as String?;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Expense Details'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                color: AppColors.surface,
                onSelected: (action) async {
                  if (action == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Delete Expense', style: TextStyle(color: AppColors.textPrimary)),
                        content: const Text('Are you sure you want to delete this expense?',
                            style: TextStyle(color: AppColors.textSecondary)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      try {
                        await ref.read(expenseListProvider.notifier).deleteExpense(expenseId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Expense deleted'), backgroundColor: AppColors.green),
                          );
                          context.pop();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.red),
                          );
                        }
                      }
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppColors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppColors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Amount card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF5B4FCF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      _fmt(amount),
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(description,
                        style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Details
              _DetailSection(children: [
                _DetailRow(
                  icon: Icons.category,
                  label: 'Category',
                  value: category[0].toUpperCase() + category.substring(1),
                ),
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: _dateFmt.format(date),
                ),
                if (creator != null)
                  _DetailRow(
                    icon: Icons.person,
                    label: 'Created by',
                    value: creator['displayName'] as String? ?? creator['email'] as String? ?? 'Unknown',
                  ),
                if (groupId != null)
                  _DetailRow(
                    icon: Icons.group,
                    label: 'Group',
                    value: 'Group expense',
                  ),
              ]),

              // Payers section
              if (payers.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Paid by', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _DetailSection(children: [
                  for (final payer in payers)
                    _UserAmountRow(
                      user: payer['user'] as Map<String, dynamic>?,
                      amount: payer['amount'] as int,
                    ),
                ]),
              ],

              // Splits section
              if (splits.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Split between', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _DetailSection(children: [
                  for (final split in splits)
                    _UserAmountRow(
                      user: split['user'] as Map<String, dynamic>?,
                      amount: split['amount'] as int,
                      subtitle: split['splitMethod'] as String?,
                    ),
                ]),
              ],

              // Items section
              if (items.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Items', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _DetailSection(children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item['name'] as String? ?? 'Item',
                                style: const TextStyle(color: AppColors.textPrimary)),
                          ),
                          Text(_fmt(item['amount'] as int),
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  final List<Widget> children;
  const _DetailSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _UserAmountRow extends StatelessWidget {
  final Map<String, dynamic>? user;
  final int amount;
  final String? subtitle;

  const _UserAmountRow({required this.user, required this.amount, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final name = user?['displayName'] as String? ?? user?['email'] as String? ?? 'Unknown';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(name[0].toUpperCase(),
                style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          Text(_fmt(amount),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
