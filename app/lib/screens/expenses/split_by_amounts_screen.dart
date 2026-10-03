import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SplitByAmountsScreen extends StatefulWidget {
  final int totalAmountPaise;
  final List<Map<String, dynamic>> members;
  final Map<String, int> initialAmounts; // memberId -> paise

  const SplitByAmountsScreen({
    super.key,
    required this.totalAmountPaise,
    required this.members,
    required this.initialAmounts,
  });

  @override
  State<SplitByAmountsScreen> createState() => _SplitByAmountsScreenState();
}

class _SplitByAmountsScreenState extends State<SplitByAmountsScreen> {
  late Map<String, int> _amounts; // memberId -> paise
  String? _selectedMemberId;
  String _inputBuffer = '';

  @override
  void initState() {
    super.initState();
    _amounts = Map<String, int>.from(widget.initialAmounts);
    // Ensure all members have an entry
    for (final m in widget.members) {
      final id = _getMemberId(m);
      _amounts.putIfAbsent(id, () => 0);
    }
    if (widget.members.isNotEmpty) {
      _selectedMemberId = _getMemberId(widget.members.first);
      final currentPaise = _amounts[_selectedMemberId] ?? 0;
      _inputBuffer = currentPaise > 0 ? (currentPaise / 100).toStringAsFixed(currentPaise % 100 == 0 ? 0 : 2) : '';
    }
  }

  String _getMemberId(Map<String, dynamic> m) {
    return (m['userId'] ?? m['user']?['id'] ?? m['id'] ?? '') as String;
  }

  String _getMemberName(Map<String, dynamic> m) {
    return (m['displayName'] ?? m['user']?['displayName'] ?? m['name'] ?? m['email'] ?? m['user']?['email'] ?? 'Member') as String;
  }

  int get _allocatedPaise {
    return _amounts.values.fold<int>(0, (prev, val) => prev + val);
  }

  int get _remainingPaise {
    return widget.totalAmountPaise - _allocatedPaise;
  }

  void _selectMember(String id) {
    setState(() {
      _selectedMemberId = id;
      final currentPaise = _amounts[id] ?? 0;
      _inputBuffer = currentPaise > 0 ? (currentPaise / 100).toStringAsFixed(currentPaise % 100 == 0 ? 0 : 2) : '';
    });
  }

  void _onKeypadPress(String key) {
    if (_selectedMemberId == null) return;

    setState(() {
      if (key == 'C') {
        _inputBuffer = '';
      } else if (key == '⌫') {
        if (_inputBuffer.isNotEmpty) {
          _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
        }
      } else if (key == '.') {
        if (!_inputBuffer.contains('.')) {
          _inputBuffer = _inputBuffer.isEmpty ? '0.' : '$_inputBuffer.';
        }
      } else {
        // Digits
        if (_inputBuffer == '0') {
          _inputBuffer = key;
        } else {
          // Check decimal places
          if (_inputBuffer.contains('.')) {
            final parts = _inputBuffer.split('.');
            if (parts.length > 1 && parts[1].length >= 2) return;
          }
          _inputBuffer += key;
        }
      }

      final enteredVal = double.tryParse(_inputBuffer) ?? 0.0;
      _amounts[_selectedMemberId!] = (enteredVal * 100).round();
    });
  }

  void _splitRemainingEqually() {
    final remaining = _remainingPaise;
    if (remaining <= 0) return;

    // Find members with 0 allocation, or all if none
    final zeroMembers = widget.members.where((m) => (_amounts[_getMemberId(m)] ?? 0) == 0).toList();
    final targetMembers = zeroMembers.isNotEmpty ? zeroMembers : widget.members;

    final count = targetMembers.length;
    if (count == 0) return;

    final basePerMember = remaining ~/ count;
    var remainder = remaining % count;

    setState(() {
      for (final m in targetMembers) {
        final id = _getMemberId(m);
        final extra = remainder > 0 ? 1 : 0;
        if (remainder > 0) remainder--;
        _amounts[id] = (_amounts[id] ?? 0) + basePerMember + extra;
      }
      if (_selectedMemberId != null) {
        final currentPaise = _amounts[_selectedMemberId] ?? 0;
        _inputBuffer = currentPaise > 0 ? (currentPaise / 100).toStringAsFixed(currentPaise % 100 == 0 ? 0 : 2) : '';
      }
    });
  }

  void _confirm() {
    final diff = _remainingPaise;
    if (diff != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(diff > 0
              ? 'Remaining ₹${(diff / 100).toStringAsFixed(2)} not allocated yet.'
              : 'Allocated exceeds total by ₹${((-diff) / 100).toStringAsFixed(2)}.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    Navigator.of(context).pop(_amounts);
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
    final totalINR = (widget.totalAmountPaise / 100).toStringAsFixed(widget.totalAmountPaise % 100 == 0 ? 0 : 2);
    final remainingVal = _remainingPaise;
    final isBalanced = remainingVal == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF141419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E24),
        elevation: 0,
        title: const Text('Split by amounts', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: isBalanced ? const Color(0xFFF2994A) : Colors.white38),
            onPressed: _confirm,
          ),
        ],
      ),
      body: Column(
        children: [
          // Total bar matching screenshot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFF1E1E24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total amount:',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                Text(
                  '$totalINR INR',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Remaining status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: isBalanced
                ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                : const Color(0xFFF2994A).withValues(alpha: 0.15),
            child: Row(
              children: [
                Icon(
                  isBalanced ? Icons.check_circle : Icons.info_outline,
                  color: isBalanced ? const Color(0xFF4CAF50) : const Color(0xFFF2994A),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBalanced
                        ? 'Total allocated: $totalINR INR (Balanced)'
                        : remainingVal > 0
                            ? 'Remaining to allocate: ₹${(remainingVal / 100).toStringAsFixed(2)}'
                            : 'Overallocated by: ₹${((-remainingVal) / 100).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isBalanced ? const Color(0xFF4CAF50) : const Color(0xFFF2994A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (remainingVal > 0)
                  InkWell(
                    onTap: _splitRemainingEqually,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Split remaining',
                        style: TextStyle(color: Color(0xFFF2994A), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Member list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.members.length,
              itemBuilder: (context, index) {
                final m = widget.members[index];
                final id = _getMemberId(m);
                final name = _getMemberName(m);
                final paise = _amounts[id] ?? 0;
                final inrStr = (paise / 100).toStringAsFixed(paise % 100 == 0 ? 0 : 2);
                final isSelected = id == _selectedMemberId;

                return GestureDetector(
                  onTap: () => _selectMember(id),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24242C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF2994A) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _getAvatarColor(name),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$inrStr INR',
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFF2994A) : (paise > 0 ? const Color(0xFFF2994A) : Colors.white38),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // In-App Keypad (matching screenshot: 7 8 9 /, 4 5 6 *, 1 2 3 -, . 0 ⌫ +)
          Container(
            color: const Color(0xFF1E1E24),
            padding: const EdgeInsets.only(top: 8, bottom: 16, left: 8, right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildKeypadRow(['7', '8', '9', 'C']),
                _buildKeypadRow(['4', '5', '6', '00']),
                _buildKeypadRow(['1', '2', '3', '⌫']),
                _buildKeypadRow(['.', '0', '000', '✓']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        final isDone = key == '✓';
        final isAction = key == 'C' || key == '⌫' || key == '00' || key == '000';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Material(
              color: isDone
                  ? const Color(0xFFF2994A)
                  : isAction
                      ? const Color(0xFF2C2C34)
                      : const Color(0xFF24242C),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (key == '✓') {
                    _confirm();
                  } else if (key == '00') {
                    _onKeypadPress('0');
                    _onKeypadPress('0');
                  } else if (key == '000') {
                    _onKeypadPress('0');
                    _onKeypadPress('0');
                    _onKeypadPress('0');
                  } else {
                    _onKeypadPress(key);
                  }
                },
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  child: Text(
                    key,
                    style: TextStyle(
                      color: isDone ? Colors.black : Colors.white,
                      fontSize: 20,
                      fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                    ),
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
