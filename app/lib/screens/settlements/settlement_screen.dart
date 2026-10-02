import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settlements_provider.dart';

final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

class SettlementScreen extends ConsumerWidget {
  final String groupId;
  const SettlementScreen({super.key, required this.groupId});

  Future<void> _recordSettlement(BuildContext context, WidgetRef ref, Map<String, dynamic> from, Map<String, dynamic> to, int amount) async {
    try {
      await ref.read(settlementsApiProvider).create({
        'groupId': groupId,
        'payeeId': to['id'] ?? to['_id'],
        'amount': amount,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement recorded successfully!')),
        );
      }
      ref.invalidate(settlementOptimizeProvider(groupId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record settlement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSettlements = ref.watch(settlementOptimizeProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Settle Up')),
      body: asyncSettlements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settlements) {
          if (settlements.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 72, color: AppColors.green),
                  SizedBox(height: 16),
                  Text('All settled up!',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('No pending payments',
                      style: TextStyle(color: AppColors.textTertiary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: settlements.length,
            itemBuilder: (context, index) {
              final s = settlements[index];
              final from = s['from'] as Map<String, dynamic>;
              final to = s['to'] as Map<String, dynamic>;
              final amount = s['amount'] as int;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _Avatar(name: from['displayName'] ?? 'U'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(from['displayName'] ?? from['email'] ?? '',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                              const Text('pays', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward, color: AppColors.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(to['displayName'] ?? to['email'] ?? '',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                              const Text('receives', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _Avatar(name: to['displayName'] ?? 'U'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _fmt.format(amount / 100),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _recordSettlement(context, ref, from, to, amount),
                      child: const Text('Record Settlement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: Text(
        name[0].toUpperCase(),
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}
