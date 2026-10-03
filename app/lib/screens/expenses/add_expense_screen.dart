import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/category_constants.dart';
import '../../core/constants/payment_constants.dart';
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
  late String? _selectedGroupId = widget.groupId;
  String _amount = '0';
  String _type = 'expense'; // 'expense' | 'income'
  String _selectedCategory = 'food';
  String _selectedPaymentMethod = 'upi';
  final Set<String> _tags = {};
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

  void _showAddTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Add Tag', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. online, swiggy, trip',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixText: '#',
            prefixStyle: const TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.bold),
            filled: true,
            fillColor: const Color(0xFF282830),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A)),
            onPressed: () {
              final text = controller.text.trim().replaceAll('#', '').toLowerCase();
              if (text.isNotEmpty) {
                setState(() => _tags.add(text));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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

      final currentGroupId = _selectedGroupId;
      final isGroup = currentGroupId != null;

      final expenseData = <String, dynamic>{
        'description': desc,
        'totalAmount': totalPaise,
        'category': _selectedCategory,
        'type': isGroup ? 'expense' : _type,
        'paymentMethod': _selectedPaymentMethod,
        'tags': _tags.toList(),
      };

      if (isGroup) {
        expenseData['groupId'] = currentGroupId;
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

      if (currentGroupId != null) {
        ref.invalidate(groupDetailProvider(currentGroupId));
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
    final currentGroupId = _selectedGroupId;
    final isGroup = currentGroupId != null;

    AsyncValue<GroupDetailState>? groupDetailAsync;
    List<Map<String, dynamic>> members = [];
    if (isGroup) {
      groupDetailAsync = ref.watch(groupDetailProvider(currentGroupId));
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

            // Destination Switcher (Personal vs Group)
            if (widget.groupId == null) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedGroupId = null;
                          _selectedMemberIds.clear();
                          _memberAmounts.clear();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !isGroup ? const Color(0xFF2F80ED) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person, size: 15, color: !isGroup ? Colors.white : Colors.white54),
                              const SizedBox(width: 6),
                              Text(
                                'Personal',
                                style: TextStyle(
                                  color: !isGroup ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final availableGroups = ref.read(groupListProvider).groups;
                          if (availableGroups.isNotEmpty) {
                            setState(() {
                              _selectedGroupId = availableGroups.first['id'] as String;
                              _selectedMemberIds.clear();
                              _payerUserId = null;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No groups found. Create a group first!')),
                            );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isGroup ? const Color(0xFF9B51E0) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group, size: 15, color: isGroup ? Colors.white : Colors.white54),
                              const SizedBox(width: 6),
                              Text(
                                'Group Split',
                                style: TextStyle(
                                  color: isGroup ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (isGroup && ref.watch(groupListProvider).groups.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF9B51E0).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.group, size: 16, color: Color(0xFFBB6BD9)),
                      const SizedBox(width: 8),
                      const Text('Split in Group:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGroupId,
                          dropdownColor: const Color(0xFF24242C),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFBB6BD9)),
                          items: ref.watch(groupListProvider).groups.map((g) {
                            return DropdownMenuItem<String>(
                              value: g['id'] as String,
                              child: Text(
                                g['name'] as String? ?? 'Group',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: (newId) {
                            if (newId != null) {
                              setState(() {
                                _selectedGroupId = newId;
                                _selectedMemberIds.clear();
                                _payerUserId = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // Transaction Type Toggle (Expense vs Income for personal transactions)
            if (!isGroup) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _type = 'expense';
                            if (!CategoryConstants.expenseCategories.any((c) => c.id == _selectedCategory)) {
                              _selectedCategory = 'food';
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _type == 'expense' ? const Color(0xFFEF4444).withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _type == 'expense' ? const Color(0xFFEF4444) : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_upward, size: 16, color: _type == 'expense' ? const Color(0xFFEF4444) : Colors.white54),
                              const SizedBox(width: 6),
                              Text(
                                'Expense',
                                style: TextStyle(
                                  color: _type == 'expense' ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _type = 'income';
                            if (!CategoryConstants.incomeCategories.any((c) => c.id == _selectedCategory)) {
                              _selectedCategory = 'salary';
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _type == 'income' ? const Color(0xFF00D68F).withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _type == 'income' ? const Color(0xFF00D68F) : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_downward, size: 16, color: _type == 'income' ? const Color(0xFF00D68F) : Colors.white54),
                              const SizedBox(width: 6),
                              Text(
                                'Income',
                                style: TextStyle(
                                  color: _type == 'income' ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Category picker
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
              child: Text(
                _type == 'income' ? 'Income Category' : 'Category',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              height: 44,
              margin: const EdgeInsets.only(top: 4),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: (_type == 'income' ? CategoryConstants.incomeCategories : CategoryConstants.expenseCategories).map((c) {
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

            // Payment Method selector
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
              child: const Text(
                'Payment Method',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              height: 44,
              margin: const EdgeInsets.only(top: 4),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: PaymentConstants.all.map((p) {
                  final isSel = p.id == _selectedPaymentMethod;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSel,
                      showCheckmark: false,
                      avatar: Icon(
                        p.icon,
                        size: 16,
                        color: isSel ? Colors.white : p.color,
                      ),
                      label: Text(
                        p.label,
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: const Color(0xFF24242C),
                      selectedColor: const Color(0xFF7C6FF7),
                      onSelected: (_) => setState(() => _selectedPaymentMethod = p.id),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSel ? const Color(0xFF7C6FF7) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Tags Section
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tags',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _showAddTagDialog,
                    icon: const Icon(Icons.add, size: 16, color: Color(0xFFF2994A)),
                    label: const Text('Add Tag', style: TextStyle(color: Color(0xFFF2994A), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ..._tags.map((tag) => Chip(
                        backgroundColor: const Color(0xFFF2994A).withValues(alpha: 0.2),
                        side: const BorderSide(color: Color(0xFFF2994A)),
                        label: Text('#$tag', style: const TextStyle(color: Color(0xFFF2994A), fontSize: 12, fontWeight: FontWeight.w600)),
                        deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFFF2994A)),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      )),
                  ...['online', 'swiggy', 'trip', 'fuel', 'groceries']
                      .where((suggested) => !_tags.contains(suggested))
                      .map((suggested) => ActionChip(
                            backgroundColor: const Color(0xFF24242C),
                            side: BorderSide.none,
                            label: Text('+$suggested', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            onPressed: () => setState(() => _tags.add(suggested)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          )),
                ],
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
