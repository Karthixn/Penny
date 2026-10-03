import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/groups_provider.dart';
import 'split_by_amounts_screen.dart';
import 'split_by_shares_dialog.dart';

final _currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateFmt = DateFormat('d MMM yyyy, h:mm a');

String _fmt(int paise) => _currFmt.format(paise / 100);

final _expenseDetailProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final api = ref.read(expensesApiProvider);
    return api.getOne(id);
  },
);

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  ConsumerState<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  bool _isCollapsed = false;
  bool _hasChanges = false;
  bool _isSaving = false;

  String? _payerUserId;
  int _totalAmountPaise = 0;
  final Set<String> _selectedMemberIds = {};
  Map<String, int> _memberAmounts = {}; // memberId -> paise
  final Map<String, double> _memberShares = {};

  void _initFromExpense(Map<String, dynamic> expense) {
    if (_hasChanges) return; // don't overwrite user edits

    _totalAmountPaise = expense['totalAmount'] as int? ?? 0;
    final payers = (expense['payers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (payers.isNotEmpty) {
      _payerUserId = (payers.first['userId'] ?? payers.first['user']?['id']) as String?;
    }

    final splits = (expense['splits'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    _selectedMemberIds.clear();
    _memberAmounts.clear();
    for (final s in splits) {
      final uid = (s['userId'] ?? s['user']?['id'] ?? '') as String;
      final amt = (s['amount'] as num?)?.toInt() ?? 0;
      if (uid.isNotEmpty) {
        _memberAmounts[uid] = amt;
        if (amt > 0) {
          _selectedMemberIds.add(uid);
        }
      }
    }
  }

  String _getMemberId(Map<String, dynamic> m) {
    return (m['id'] ?? m['userId'] ?? m['user']?['id'] ?? '') as String;
  }

  String _getMemberName(Map<String, dynamic> m) {
    return (m['displayName'] ?? m['user']?['displayName'] ?? m['email'] ?? m['user']?['email'] ?? 'Member') as String;
  }

  void _toggleMember(String id, List<Map<String, dynamic>> allMembers) {
    setState(() {
      _hasChanges = true;
      if (_selectedMemberIds.contains(id)) {
        if (_selectedMemberIds.length > 1) {
          _selectedMemberIds.remove(id);
          _memberAmounts[id] = 0;
        }
      } else {
        _selectedMemberIds.add(id);
      }
      _recalculateEqualSplits();
    });
  }

  void _recalculateEqualSplits() {
    final count = _selectedMemberIds.length;
    if (count == 0 || _totalAmountPaise <= 0) return;

    final base = _totalAmountPaise ~/ count;
    var remainder = _totalAmountPaise % count;

    for (final id in _selectedMemberIds) {
      final extra = remainder > 0 ? 1 : 0;
      if (remainder > 0) remainder--;
      _memberAmounts[id] = base + extra;
    }
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
                  setState(() {
                    _payerUserId = id;
                    _hasChanges = true;
                  });
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
    final result = await Navigator.of(context).push<Map<String, int>>(
      MaterialPageRoute(
        builder: (_) => SplitByAmountsScreen(
          totalAmountPaise: _totalAmountPaise,
          members: members,
          initialAmounts: _memberAmounts,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _hasChanges = true;
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
    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SplitBySharesDialog(
        totalAmountPaise: _totalAmountPaise,
        members: members,
        initialShares: _memberShares,
      ),
    );

    if (result != null) {
      setState(() {
        _hasChanges = true;
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

  Future<void> _saveChanges(String? groupId) async {
    setState(() => _isSaving = true);
    try {
      final List<Map<String, dynamic>> splits = [];
      for (final entry in _memberAmounts.entries) {
        if (entry.value > 0) {
          splits.add({
            'userId': entry.key,
            'amount': entry.value,
            'splitMethod': 'custom',
          });
        }
      }

      final payload = <String, dynamic>{
        if (_payerUserId != null)
          'payers': [
            {'userId': _payerUserId, 'amount': _totalAmountPaise}
          ],
        'splits': splits,
      };

      await ref.read(expensesApiProvider).update(widget.expenseId, payload);
      ref.invalidate(_expenseDetailProvider(widget.expenseId));
      if (groupId != null) {
        ref.invalidate(groupDetailProvider(groupId));
      }

      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense updated successfully! 🎉'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteExpense(String? groupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Delete Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this expense? Group balances will be recalculated.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(expenseListProvider.notifier).deleteExpense(widget.expenseId);
        if (groupId != null) {
          ref.invalidate(groupDetailProvider(groupId));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted'), backgroundColor: Color(0xFF4CAF50)),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.red),
          );
        }
      }
    }
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF9C27B0),
      const Color(0xFF3F51B5),
      const Color(0xFF009688),
      const Color(0xFFE65100),
      const Color(0xFF1E88E5),
      const Color(0xFF43A047),
      const Color(0xFF546E7A),
      const Color(0xFFD81B60),
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(_expenseDetailProvider(widget.expenseId));

    return detailAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF141419),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFF2994A))),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFF141419),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
      ),
      data: (expense) {
        _initFromExpense(expense);

        final description = expense['description'] as String? ?? 'Expense';
        final category = expense['category'] as String? ?? 'other';
        final date = DateTime.tryParse(expense['date'] as String? ?? '') ?? DateTime.now();
        final groupId = expense['groupId'] as String?;

        // Extract members from group if available, or construct from payers & splits
        List<Map<String, dynamic>> allMembers = [];
        if (groupId != null) {
          final groupAsync = ref.watch(groupDetailProvider(groupId));
          final group = groupAsync.value?.group;
          if (group != null && group['members'] is List) {
            allMembers = (group['members'] as List).cast<Map<String, dynamic>>();
          }
        }

        // Fallback members from expense payers/splits if group members not yet loaded
        if (allMembers.isEmpty) {
          final splits = (expense['splits'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final s in splits) {
            final u = s['user'] as Map<String, dynamic>?;
            if (u != null) allMembers.add(u);
          }
        }

        // Determine payer name
        String payerName = 'Unknown';
        if (_payerUserId != null) {
          final found = allMembers.where((m) => _getMemberId(m) == _payerUserId).firstOrNull;
          if (found != null) {
            payerName = _getMemberName(found);
          } else {
            final payers = (expense['payers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            if (payers.isNotEmpty) {
              final pUser = payers.first['user'] as Map<String, dynamic>?;
              payerName = pUser?['displayName'] ?? pUser?['email'] ?? 'Member';
            }
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFF141419),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E24),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: const Text('Expense detail', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                tooltip: 'Delete',
                onPressed: () => _deleteExpense(groupId),
              ),
            ],
          ),
          bottomNavigationBar: _hasChanges
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  color: const Color(0xFF1E1E24),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2994A),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : () => _saveChanges(groupId),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Title & Category Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF24242C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFF2994A).withValues(alpha: 0.15),
                      child: Icon(
                        category == 'food'
                            ? Icons.restaurant
                            : category == 'transport'
                                ? Icons.directions_car
                                : category == 'shopping'
                                    ? Icons.shopping_bag
                                    : Icons.receipt_long,
                        color: const Color(0xFFF2994A),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(description, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(category[0].toUpperCase() + category.substring(1), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                    Text(
                      _fmt(_totalAmountPaise),
                      style: const TextStyle(color: Color(0xFFF2994A), fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // "Who paid" section matching Settle Up screenshot
              const Text('Who paid', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF24242C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _getAvatarColor(payerName),
                          child: Text(
                            payerName.isNotEmpty ? payerName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            payerName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          _fmt(_totalAmountPaise),
                          style: const TextStyle(color: Color(0xFFF2994A), fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showPayerPicker(allMembers),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'EDIT',
                          style: TextStyle(color: Color(0xFFF2994A), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // "For whom (6/7)" section matching Settle Up screenshot
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'For whom (${_selectedMemberIds.length}/${allMembers.length})',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                ],
              ),
              const SizedBox(height: 6),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF24242C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (!_isCollapsed) ...[
                      ...allMembers.map((m) {
                        final id = _getMemberId(m);
                        final name = _getMemberName(m);
                        final isChecked = _selectedMemberIds.contains(id);
                        final paise = _memberAmounts[id] ?? 0;

                        return InkWell(
                          onTap: () => _toggleMember(id, allMembers),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isChecked ? _getAvatarColor(name) : Colors.white12,
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: isChecked ? Colors.white : Colors.white38,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        isChecked ? _fmt(paise) : '₹0',
                                        style: TextStyle(
                                          color: isChecked ? const Color(0xFFF2994A) : Colors.white38,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Checkbox(
                                  value: isChecked,
                                  activeColor: const Color(0xFFF2994A),
                                  checkColor: Colors.black,
                                  side: const BorderSide(color: Colors.white38, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (_) => _toggleMember(id, allMembers),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const Divider(color: Colors.white12, height: 1),
                    ],

                    // Collapse toggle
                    InkWell(
                      onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isCollapsed ? 'Expand' : 'Collapse',
                              style: const TextStyle(color: Color(0xFFF2994A), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                              color: const Color(0xFFF2994A),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(color: Colors.white12, height: 1),

                    // "SPLIT BY AMOUNTS" & "SPLIT BY SHARES"
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => _openSplitByAmounts(allMembers),
                            child: const Text('SPLIT BY AMOUNTS', style: TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        Container(width: 1, height: 24, color: Colors.white12),
                        Expanded(
                          child: TextButton(
                            onPressed: () => _openSplitByShares(allMembers),
                            child: const Text('SPLIT BY SHARES', style: TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // "Date & time" section
              const Text('Date & time', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF24242C),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: Color(0xFFF2994A), size: 20),
                    const SizedBox(width: 14),
                    Text(
                      _dateFmt.format(date),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
