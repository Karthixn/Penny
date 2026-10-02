import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/user_provider.dart';

const _categories = [
  ('food', Icons.restaurant, 'Food'),
  ('transport', Icons.directions_car, 'Transport'),
  ('shopping', Icons.shopping_bag, 'Shopping'),
  ('entertainment', Icons.movie, 'Entertainment'),
  ('bills', Icons.receipt_long, 'Bills'),
  ('health', Icons.favorite, 'Health'),
  ('education', Icons.school, 'Education'),
  ('other', Icons.more_horiz, 'Other'),
];

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? groupId;

  const AddExpenseScreen({super.key, this.groupId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  String _amount = '0';
  String _selectedCategory = 'other';
  final _descController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _onNumPad(String key) {
    setState(() {
      if (key == 'C') {
        _amount = '0';
      } else if (key == '⌫') {
        _amount = _amount.length > 1 ? _amount.substring(0, _amount.length - 1) : '0';
      } else if (key == '.') {
        if (!_amount.contains('.')) _amount += '.';
      } else {
        if (_amount == '0' && key != '.') {
          _amount = key;
        } else {
          if (_amount.contains('.') && _amount.split('.')[1].length >= 2) return;
          _amount += key;
        }
      }
    });
  }

  Future<void> _save() async {
    final amountVal = double.tryParse(_amount) ?? 0;
    if (amountVal <= 0) return;

    final paise = (amountVal * 100).round();
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a description'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Get userId from the cached user profile provider
      final userState = ref.read(userProvider);
      String? userId = userState.profile?['id'] as String?;

      // If profile not loaded yet, fetch it
      if (userId == null) {
        await ref.read(userProvider.notifier).loadProfile();
        userId = ref.read(userProvider).profile?['id'] as String?;
      }

      if (userId == null) {
        throw Exception('Could not load user profile');
      }

      final expenseData = <String, dynamic>{
        'description': desc,
        'totalAmount': paise,
        'category': _selectedCategory,
        'payers': [
          {'userId': userId, 'amount': paise}
        ],
        'splits': [
          {'userId': userId, 'amount': paise, 'splitMethod': 'equal'}
        ],
      };

      // Include groupId if this is a group expense
      if (widget.groupId != null) {
        expenseData['groupId'] = widget.groupId;
      }

      await ref.read(expenseListProvider.notifier).addExpense(expenseData);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _displayAmount {
    return '₹$_amount';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.groupId != null ? 'Add Group Expense' : 'Add Expense'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Text('Save', style: TextStyle(color: AppColors.primary, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Amount display
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _displayAmount,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Description field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _descController,
              style: const TextStyle(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'What was this for?',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Category selector
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final (id, icon, label) = _categories[i];
                final selected = _selectedCategory == id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = id),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: selected ? null : Border.all(color: AppColors.border),
                        ),
                        child: Icon(icon, color: selected ? Colors.white : AppColors.textSecondary, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? AppColors.primary : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Spacer(),

          // Numpad
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              children: [
                for (final row in [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['.', '0', '⌫'],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: row.map((key) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Material(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _onNumPad(key),
                                child: Container(
                                  height: 56,
                                  alignment: Alignment.center,
                                  child: key == '⌫'
                                      ? const Icon(Icons.backspace_outlined,
                                          color: AppColors.textPrimary, size: 22)
                                      : Text(
                                          key,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
