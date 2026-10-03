import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settlements_provider.dart';

import '../../providers/groups_provider.dart';

final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

class SettlementScreen extends ConsumerWidget {
  final String groupId;
  const SettlementScreen({super.key, required this.groupId});

  Future<void> _recordSettlement(
    BuildContext context,
    WidgetRef ref,
    String payeeId,
    int amountPaise,
    String? note,
  ) async {
    try {
      await ref.read(settlementsApiProvider).create({
        'groupId': groupId,
        'payeeId': payeeId,
        'amount': amountPaise,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement recorded successfully!')),
        );
      }
      ref.invalidate(settlementOptimizeProvider(groupId));
      ref.invalidate(groupDetailProvider(groupId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record settlement: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _showPartPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> from,
    Map<String, dynamic> to,
    int maxAmountPaise,
  ) {
    final amountController = TextEditingController(text: (maxAmountPaise / 100).toStringAsFixed(2));
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(
          'Part Payment to ${to['displayName'] ?? 'Member'}',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter amount to settle now:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: Color(0xFFF2994A), fontSize: 20, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: const Color(0xFF282830),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Note (optional, e.g. GPay part 1)',
                hintStyle: const TextStyle(color: Colors.white38),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A)),
            onPressed: () {
              final entered = double.tryParse(amountController.text.trim()) ?? 0;
              final enteredPaise = (entered * 100).round();
              if (enteredPaise <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: AppColors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              _recordSettlement(
                context,
                ref,
                (to['id'] ?? to['_id']) as String,
                enteredPaise,
                noteController.text.trim(),
              );
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _recordSettlement(
                              context,
                              ref,
                              (to['id'] ?? to['_id']) as String,
                              amount,
                              null,
                            ),
                            child: const Text('Settle Full', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFF2994A)),
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _showPartPaymentDialog(context, ref, from, to, amount),
                            child: const Text('Part Pay', style: TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
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
