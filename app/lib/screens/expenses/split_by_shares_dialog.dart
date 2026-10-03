import 'package:flutter/material.dart';

class SplitBySharesDialog extends StatefulWidget {
  final int totalAmountPaise;
  final List<Map<String, dynamic>> members;
  final Map<String, double> initialShares;

  const SplitBySharesDialog({
    super.key,
    required this.totalAmountPaise,
    required this.members,
    required this.initialShares,
  });

  @override
  State<SplitBySharesDialog> createState() => _SplitBySharesDialogState();
}

class _SplitBySharesDialogState extends State<SplitBySharesDialog> {
  late Map<String, double> _shares;

  @override
  void initState() {
    super.initState();
    _shares = Map<String, double>.from(widget.initialShares);
    for (final m in widget.members) {
      final id = _getMemberId(m);
      _shares.putIfAbsent(id, () => 1.0);
    }
  }

  String _getMemberId(Map<String, dynamic> m) {
    return (m['userId'] ?? m['user']?['id'] ?? m['id'] ?? '') as String;
  }

  String _getMemberName(Map<String, dynamic> m) {
    return (m['displayName'] ?? m['user']?['displayName'] ?? m['name'] ?? m['email'] ?? m['user']?['email'] ?? 'Member') as String;
  }

  double get _totalShares {
    return _shares.values.fold<double>(0.0, (prev, val) => prev + val);
  }

  Map<String, int> _calculatePaise() {
    final total = _totalShares;
    final Map<String, int> result = {};
    if (total <= 0) return result;

    var sum = 0;
    for (final m in widget.members) {
      final id = _getMemberId(m);
      final share = _shares[id] ?? 0.0;
      final paise = (widget.totalAmountPaise * (share / total)).round();
      result[id] = paise;
      sum += paise;
    }

    // Adjust any rounding discrepancy to the member with largest share
    final diff = widget.totalAmountPaise - sum;
    if (diff != 0 && widget.members.isNotEmpty) {
      final firstId = _getMemberId(widget.members.first);
      result[firstId] = (result[firstId] ?? 0) + diff;
    }

    return result;
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
    final calculatedAmounts = _calculatePaise();
    final totalSharesVal = _totalShares;
    final totalINR = (widget.totalAmountPaise / 100).toStringAsFixed(widget.totalAmountPaise % 100 == 0 ? 0 : 2);

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Split by shares', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Total: $totalINR INR • ${totalSharesVal.toStringAsFixed(totalSharesVal % 1 == 0 ? 0 : 1)} shares',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final m in widget.members) {
                        _shares[_getMemberId(m)] = 1.0;
                      }
                    });
                  },
                  child: const Text('Reset', style: TextStyle(color: Color(0xFFF2994A))),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),

          // Members list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: widget.members.length,
              itemBuilder: (context, index) {
                final m = widget.members[index];
                final id = _getMemberId(m);
                final name = _getMemberName(m);
                final share = _shares[id] ?? 1.0;
                final paise = calculatedAmounts[id] ?? 0;
                final inrStr = (paise / 100).toStringAsFixed(2);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF24242C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _getAvatarColor(name),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                            Text('₹$inrStr', style: const TextStyle(color: Color(0xFFF2994A), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),

                      // Share weight stepper
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                if (share > 0) {
                                  setState(() => _shares[id] = (share - 1).clamp(0.0, 99.0));
                                }
                              },
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 28),
                              alignment: Alignment.center,
                              child: Text(
                                share.toStringAsFixed(share % 1 == 0 ? 0 : 1),
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() => _shares[id] = share + 1);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF2994A),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final results = _calculatePaise();
                Navigator.of(context).pop(results);
              },
              child: const Text('Apply Shares', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
