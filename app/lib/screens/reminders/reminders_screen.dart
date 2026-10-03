import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/penny_loading.dart';
import '../../providers/reminders_provider.dart';

final _dateFmt = DateFormat('MMM d, yyyy');
final _currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final titleCtl = TextEditingController();
    final amountCtl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    bool isRecurring = false;
    String recurrence = 'monthly';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('New Reminder', style: TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Title (e.g. Pay rent)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Amount (optional)'),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.textTertiary, size: 18),
                        const SizedBox(width: 10),
                        Text(_dateFmt.format(selectedDate),
                            style: const TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: isRecurring,
                  onChanged: (v) => setDialogState(() => isRecurring = v),
                  title: const Text('Recurring', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  activeTrackColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                if (isRecurring)
                  DropdownButton<String>(
                    value: recurrence,
                    dropdownColor: AppColors.surface,
                    isExpanded: true,
                    items: ['daily', 'weekly', 'monthly', 'yearly']
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r[0].toUpperCase() + r.substring(1),
                                  style: const TextStyle(color: AppColors.textPrimary)),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => recurrence = v!),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtl.text.trim();
                if (title.isEmpty) return;
                final amountVal = double.tryParse(amountCtl.text);
                
                await ref.read(reminderListProvider.notifier).addReminder({
                  'title': title,
                  if (amountVal != null) 'amount': (amountVal * 100).round(),
                  'dueDate': selectedDate.toIso8601String(),
                  'isRecurring': isRecurring,
                  if (isRecurring) 'recurrenceRule': recurrence,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderState = ref.watch(reminderListProvider);
    final reminders = reminderState.reminders;

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: reminderState.isLoading && reminders.isEmpty
          ? const Center(child: PennyLoadingIndicator(size: 48, message: 'Loading reminders...'))
          : reminders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: AppColors.textTertiary),
                      SizedBox(height: 16),
                      Text('No reminders', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(reminderListProvider.notifier).loadReminders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: reminders.length,
                    itemBuilder: (context, index) {
                      final r = reminders[index];
                      final dueDate = DateTime.parse(r['dueDate'] as String);
                      final isOverdue = dueDate.isBefore(DateTime.now());
                      final amount = r['amount'] as int?;

                      return Dismissible(
                        key: Key(r['id'] as String),
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
                        onDismissed: (_) => ref.read(reminderListProvider.notifier).deleteReminder(r['id'] as String),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isOverdue ? AppColors.red.withValues(alpha: 0.5) : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => ref.read(reminderListProvider.notifier).completeReminder(r['id'] as String),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 2),
                                  ),
                                  child: const Icon(Icons.check, color: AppColors.primary, size: 16),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r['title'] as String,
                                        style: const TextStyle(
                                            color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today,
                                            size: 12, color: isOverdue ? AppColors.red : AppColors.textTertiary),
                                        const SizedBox(width: 4),
                                        Text(
                                          _dateFmt.format(dueDate),
                                          style: TextStyle(
                                            color: isOverdue ? AppColors.red : AppColors.textTertiary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (r['isRecurring'] == true) ...[
                                          const SizedBox(width: 8),
                                          const Icon(Icons.repeat, size: 12, color: AppColors.accent),
                                          const SizedBox(width: 2),
                                          Text(
                                            r['recurrenceRule'] as String? ?? '',
                                            style: const TextStyle(color: AppColors.accent, fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (amount != null)
                                Text(
                                  _currFmt.format(amount / 100),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
