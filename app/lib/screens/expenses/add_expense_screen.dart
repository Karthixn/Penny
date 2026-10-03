import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/category_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/user_provider.dart';
import 'split_by_amounts_screen.dart';
import 'split_by_shares_dialog.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? groupId;

  const AddExpenseScreen({super.key, this.groupId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  String _amount = '0';
  String _selectedCategory = 'food';
  final _descController = TextEditingController();
  bool _saving = false;

  // Group split state
  String? _payerUserId;
  String _splitMethod = 'equal'; // 'equal' | 'exact' | 'shares'
  final Set<String> _selectedMemberIds = {};
  Map<String, int> _memberAmounts = {}; // memberId -> paise
  final Map<String, double> _memberShares = {}; // memberId -> shares

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
      _recalculateSplits();
    });
  }

  void _initGroupMembers(List<Map<String, dynamic>> members, String currentUserId) {
    if (_selectedMemberIds.isNotEmpty) return; // already initialized

    // Set default payer to current user if member, or first member
    final currentUserInGroup = members.any((m) => _getMemberId(m) == currentUserId);
    if (currentUserInGroup) {
      _payerUserId ??= currentUserId;
    } else if (members.isNotEmpty) {
      _payerUserId ??= _getMemberId(members.first);
    } else {
      _payerUserId ??= currentUserId;
    }

    // Default: select all members for equal split
    for (final m in members) {
      final id = _getMemberId(m);
      if (id.isNotEmpty) {
        _selectedMemberIds.add(id);
        _memberShares[id] = 1.0;
      }
    }
    _recalculateSplits();
  }

  String _getMemberId(Map<String, dynamic> m) {
    return (m['userId'] ?? m['user']?['id'] ?? m['id'] ?? '') as String;
  }

  String _getMemberName(Map<String, dynamic> m) {
    return (m['displayName'] ?? m['user']?['displayName'] ?? m['name'] ?? m['email'] ?? m['user']?['email'] ?? 'Member') as String;
  }

  void _recalculateSplits() {
    final amountVal = double.tryParse(_amount) ?? 0;
    final totalPaise = (amountVal * 100).round();

    if (_splitMethod == 'equal') {
      final selectedCount = _selectedMemberIds.length;
      if (selectedCount == 0 || totalPaise <= 0) {
        _memberAmounts = {for (final id in _selectedMemberIds) id: 0};
        return;
      }
      final base = totalPaise ~/ selectedCount;
      var remainder = totalPaise % selectedCount;

      final Map<String, int> newAmounts = {};
      for (final id in _selectedMemberIds) {
        final extra = remainder > 0 ? 1 : 0;
        if (remainder > 0) remainder--;
        newAmounts[id] = base + extra;
      }
      _memberAmounts = newAmounts;
    } else if (_splitMethod == 'shares') {
      final totalShares = _selectedMemberIds.fold<double>(0.0, (prev, id) => prev + (_memberShares[id] ?? 1.0));
      if (totalShares <= 0 || totalPaise <= 0) return;

      var sum = 0;
      final Map<String, int> newAmounts = {};
      for (final id in _selectedMemberIds) {
        final share = _memberShares[id] ?? 1.0;
        final paise = (totalPaise * (share / totalShares)).round();
        newAmounts[id] = paise;
        sum += paise;
      }
      final diff = totalPaise - sum;
      if (diff != 0 && _selectedMemberIds.isNotEmpty) {
        final firstId = _selectedMemberIds.first;
        newAmounts[firstId] = (newAmounts[firstId] ?? 0) + diff;
      }
      _memberAmounts = newAmounts;
    }
  }

  void _toggleMember(String id) {
    setState(() {
      if (_selectedMemberIds.contains(id)) {
        if (_selectedMemberIds.length > 1) {
          _selectedMemberIds.remove(id);
          _memberAmounts.remove(id);
        }
      } else {
        _selectedMemberIds.add(id);
      }
      _splitMethod = 'equal';
      _recalculateSplits();
    });
  }

  void _showPayerPicker(List<Map<String, dynamic>> members) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Who paid?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ...members.map((m) {
              final id = _getMemberId(m);
              final name = _getMemberName(m);
              final isSelected = id == _payerUserId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? const Color(0xFFF2994A) : const Color(0xFF2C2C34),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFF2994A)) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  setState(() => _payerUserId = id);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _openSplitByAmounts(List<Map<String, dynamic>> members) async {
    final amountVal = double.tryParse(_amount) ?? 0;
    final totalPaise = (amountVal * 100).round();
    if (totalPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter total amount first'), backgroundColor: AppColors.red),
      );
      return;
    }

    final result = await Navigator.of(context).push<Map<String, int>>(
      MaterialPageRoute(
        builder: (_) => SplitByAmountsScreen(
          totalAmountPaise: totalPaise,
          members: members,
          initialAmounts: _memberAmounts,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _splitMethod = 'exact';
        _memberAmounts = result;
        _selectedMemberIds.clear();
        for (final entry in result.entries) {
          if (entry.value > 0) {
            _selectedMemberIds.add(entry.key);
          }
        }
      });
    }
  }

  Future<void> _openSplitByShares(List<Map<String, dynamic>> members) async {
    final amountVal = double.tryParse(_amount) ?? 0;
    final totalPaise = (amountVal * 100).round();
    if (totalPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter total amount first'), backgroundColor: AppColors.red),
      );
      return;
    }

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SplitBySharesDialog(
        totalAmountPaise: totalPaise,
        members: members,
        initialShares: _memberShares,
      ),
    );

    if (result != null) {
      setState(() {
        _splitMethod = 'shares';
        _memberAmounts = result;
        _selectedMemberIds.clear();
        for (final entry in result.entries) {
          if (entry.value > 0) {
            _selectedMemberIds.add(entry.key);
          }
        }
      });
    }
  }

  Future<void> _save() async {
    final amountVal = double.tryParse(_amount) ?? 0;
    if (amountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount'), backgroundColor: AppColors.red),
      );
      return;
    }

    final totalPaise = (amountVal * 100).round();
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a description'), backgroundColor: AppColors.red),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final userState = ref.read(userProvider);
      var currentUserId = userState.profile?['id'] as String?;
      if (currentUserId == null) {
        await ref.read(userProvider.notifier).loadProfile();
        currentUserId = ref.read(userProvider).profile?['id'] as String?;
      }
      if (currentUserId == null) throw Exception('User not logged in');

      final expenseData = <String, dynamic>{
        'description': desc,
        'totalAmount': totalPaise,
        'category': _selectedCategory,
      };

      if (widget.groupId != null) {
        expenseData['groupId'] = widget.groupId;
        final payer = (_payerUserId != null && _payerUserId!.isNotEmpty) ? _payerUserId! : currentUserId;
        expenseData['payers'] = [
          {'userId': payer, 'amount': totalPaise}
        ];

        if (_splitMethod == 'equal') {
          _recalculateSplits();
        }

        final List<Map<String, dynamic>> splits = [];
        for (final id in _selectedMemberIds) {
          final amt = _memberAmounts[id] ?? 0;
          if (amt > 0) {
            splits.add({
              'userId': id,
              'amount': amt,
              'splitMethod': _splitMethod,
            });
          }
        }

        // Fallback: If splits list is empty, split equally across selected or payer
        if (splits.isEmpty) {
          final targetIds = _selectedMemberIds.isNotEmpty ? _selectedMemberIds.toList() : [payer];
          final base = totalPaise ~/ targetIds.length;
          var rem = totalPaise % targetIds.length;
          for (final id in targetIds) {
            splits.add({
              'userId': id,
              'amount': base + (rem > 0 ? 1 : 0),
              'splitMethod': 'equal',
            });
            if (rem > 0) rem--;
          }
        }

        // Validate splits match total amount
        final splitSum = splits.fold<int>(0, (prev, s) => prev + (s['amount'] as int));
        if (splitSum != totalPaise && splits.isNotEmpty) {
          splits.first['amount'] = (splits.first['amount'] as int) + (totalPaise - splitSum);
        }

        expenseData['splits'] = splits;
      } else {
        // Personal expense
        expenseData['payers'] = [
          {'userId': currentUserId, 'amount': totalPaise}
        ];
        expenseData['splits'] = [
          {'userId': currentUserId, 'amount': totalPaise, 'splitMethod': 'equal'}
        ];
      }

      await ref.read(expenseListProvider.notifier).addExpense(expenseData);

      if (widget.groupId != null) {
        ref.invalidate(groupDetailProvider(widget.groupId!));
      }

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

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final currentUserId = userState.profile?['id'] as String? ?? '';
    final isGroup = widget.groupId != null;

    AsyncValue<GroupDetailState>? groupDetailAsync;
    List<Map<String, dynamic>> members = [];
    if (isGroup) {
      groupDetailAsync = ref.watch(groupDetailProvider(widget.groupId!));
      final group = groupDetailAsync?.value?.group;
      if (group != null && group['members'] is List) {
        members = (group['members'] as List).cast<Map<String, dynamic>>();
        _initGroupMembers(members, currentUserId);
      }
    }

    final payerName = members.isEmpty
        ? 'You'
        : _getMemberName(members.firstWhere(
            (m) => _getMemberId(m) == _payerUserId,
            orElse: () => {'displayName': 'You'},
          ));

    return Scaffold(
      backgroundColor: const Color(0xFF141419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E24),
        elevation: 0,
        title: Text(isGroup ? 'Add Group Expense' : 'Add Expense',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF2994A)))
                  : const Text('Save', style: TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount display card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              color: const Color(0xFF1E1E24),
              child: Column(
                children: [
                  Text(
                    '₹$_amount',
                    style: const TextStyle(
                      color: Color(0xFFF2994A),
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'What was this expense for?',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.edit_note, color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF282830),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Category picker
            Container(
              height: 48,
              margin: const EdgeInsets.only(top: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: CategoryConstants.all.map((c) {
                  final isSel = c.id == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSel,
                      showCheckmark: false,
                      avatar: Icon(
                        c.icon,
                        size: 16,
                        color: isSel ? Colors.white : c.color,
                      ),
                      label: Text(
                        c.label,
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: const Color(0xFF24242C),
                      selectedColor: c.color,
                      onSelected: (_) => setState(() => _selectedCategory = c.id),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSel ? c.color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            if (isGroup && members.isNotEmpty) ...[
              const SizedBox(height: 16),

              // "Who paid" section matching Settle Up screenshot
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Who paid', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF24242C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFF2994A).withValues(alpha: 0.2),
                      child: Text(payerName.isNotEmpty ? payerName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(payerName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          Text('₹$_amount', style: const TextStyle(color: Color(0xFFF2994A), fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF2994A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      onPressed: () => _showPayerPicker(members),
                      child: const Text('EDIT', style: TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // "For whom (X/Y)" section matching Settle Up screenshot
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'For whom (${_selectedMemberIds.length}/${members.length})',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _splitMethod == 'equal' ? 'Split equally' : _splitMethod == 'exact' ? 'By amounts' : 'By shares',
                      style: const TextStyle(color: Color(0xFFF2994A), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Members split list
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF24242C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ...members.map((m) {
                      final id = _getMemberId(m);
                      final name = _getMemberName(m);
                      final isChecked = _selectedMemberIds.contains(id);
                      final paise = _memberAmounts[id] ?? 0;
                      final inrStr = (paise / 100).toStringAsFixed(2);

                      return InkWell(
                        onTap: () => _toggleMember(id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isChecked ? const Color(0xFF3F51B5) : Colors.white12,
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: TextStyle(color: isChecked ? Colors.white : Colors.white38, fontSize: 15, fontWeight: FontWeight.w500)),
                                    if (isChecked)
                                      Text('₹$inrStr', style: const TextStyle(color: Color(0xFFF2994A), fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Checkbox(
                                value: isChecked,
                                activeColor: const Color(0xFFF2994A),
                                checkColor: Colors.black,
                                side: const BorderSide(color: Colors.white38, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (_) => _toggleMember(id),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const Divider(color: Colors.white12, height: 1),

                    // Buttons: "SPLIT BY AMOUNTS" & "SPLIT BY SHARES"
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => _openSplitByAmounts(members),
                            child: const Text('SPLIT BY AMOUNTS', style: TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        Container(width: 1, height: 24, color: Colors.white12),
                        Expanded(
                          child: TextButton(
                            onPressed: () => _openSplitByShares(members),
                            child: const Text('SPLIT BY SHARES', style: TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Number pad
            Container(
              color: const Color(0xFF1E1E24),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(
                children: [
                  _numPadRow(['1', '2', '3']),
                  _numPadRow(['4', '5', '6']),
                  _numPadRow(['7', '8', '9']),
                  _numPadRow(['.', '0', '⌫']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numPadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Material(
              color: const Color(0xFF24242C),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _onNumPad(key),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  child: Text(
                    key,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
