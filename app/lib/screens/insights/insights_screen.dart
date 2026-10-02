import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _monthlyTrend = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);

      // Fetch current month stats and 6-month trend in parallel
      final trendMonths = <Map<String, int>>[];
      for (int i = 5; i >= 0; i--) {
        int m = _month - i;
        int y = _year;
        while (m <= 0) {
          m += 12;
          y--;
        }
        trendMonths.add({'year': y, 'month': m});
      }

      // Batch all requests with Future.wait instead of sequential calls
      final futures = trendMonths.map((ym) async {
        try {
          return await api.dio.get('/expenses/stats', queryParameters: {
            'year': ym['year'],
            'month': ym['month'],
          });
        } catch (_) {
          return null;
        }
      });

      final results = await Future.wait(futures);

      final trend = <Map<String, dynamic>>[];
      for (int i = 0; i < results.length; i++) {
        final ym = trendMonths[i];
        final r = results[i];
        if (r != null) {
          final data = r.data as Map<String, dynamic>;
          trend.add({
            'month': DateFormat('MMM').format(DateTime(ym['year']!, ym['month']!)),
            'total': data['totalSpent'] ?? 0,
          });
        } else {
          trend.add({
            'month': DateFormat('MMM').format(DateTime(ym['year']!, ym['month']!)),
            'total': 0,
          });
        }
      }

      // Current month stats is the last result
      final currentStats = results.last;
      if (currentStats != null) {
        _stats = currentStats.data as Map<String, dynamic>;
      }

      _monthlyTrend = trend;
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) {
        _month = 1;
        _year++;
      } else if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(_year, _month));
    final totalSpent = (_stats?['totalSpent'] as int?) ?? 0;

    // byCategory comes from server as Map<String, dynamic> e.g. {"food": 5000, "transport": 3000}
    final rawByCategory = _stats?['byCategory'];
    final Map<String, int> byCategory;
    if (rawByCategory is Map<String, dynamic>) {
      byCategory = rawByCategory.map((k, v) => MapEntry(k, (v as num).toInt()));
    } else if (rawByCategory is List) {
      // Handle Prisma groupBy format: [{category: "food", _sum: {totalAmount: 5000}}, ...]
      byCategory = {};
      for (final item in rawByCategory) {
        final catMap = item as Map<String, dynamic>;
        final cat = catMap['category'] as String? ?? 'other';
        final amount = (catMap['_sum']?['totalAmount'] as num?)?.toInt() ?? 0;
        byCategory[cat] = amount;
      }
    } else {
      byCategory = {};
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Month selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                      ),
                      Text(monthLabel,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Total spent card
                  Container(
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
                        const Text('Total Spent', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          _currFmt.format(totalSpent / 100),
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 6-month bar chart
                  if (_monthlyTrend.isNotEmpty) ...[
                    const Text('Spending Trend', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    _BarChart(data: _monthlyTrend),
                    const SizedBox(height: 24),
                  ],

                  // Category breakdown
                  if (byCategory.isNotEmpty) ...[
                    const Text('By Category', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ...byCategory.entries.map((entry) {
                      final pct = totalSpent > 0 ? entry.value / totalSpent : 0.0;
                      return _CategoryRow(
                        category: entry.key,
                        amount: entry.value,
                        percentage: pct,
                      );
                    }),
                  ],

                  if (totalSpent == 0 && byCategory.isEmpty) ...[
                    const SizedBox(height: 40),
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.bar_chart, size: 64, color: AppColors.textTertiary),
                          SizedBox(height: 16),
                          Text('No expenses this month',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                          SizedBox(height: 8),
                          Text('Add expenses to see your insights',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<int>(0, (m, d) => max(m, d['total'] as int));
    final chartMax = maxVal > 0 ? maxVal : 1;

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          final total = d['total'] as int;
          final heightFrac = total / chartMax;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (total > 0)
                    Text(
                      _currFmt.format(total / 100),
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: max(4, heightFrac * 80),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(d['month'] as String,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

const _catIcons = {
  'food': Icons.restaurant,
  'transport': Icons.directions_car,
  'shopping': Icons.shopping_bag,
  'entertainment': Icons.movie,
  'bills': Icons.receipt_long,
  'health': Icons.favorite,
  'education': Icons.school,
  'other': Icons.more_horiz,
};

const _catColors = {
  'food': Color(0xFFFF8C42),
  'transport': Color(0xFF4FC3F7),
  'shopping': Color(0xFFE040FB),
  'entertainment': Color(0xFFFFD54F),
  'bills': Color(0xFF7C6FF7),
  'health': Color(0xFFFF5757),
  'education': Color(0xFF00D68F),
  'other': Color(0xFF8E91A4),
};

class _CategoryRow extends StatelessWidget {
  final String category;
  final int amount;
  final double percentage;

  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final lc = category.toLowerCase();
    final icon = _catIcons[lc] ?? Icons.more_horiz;
    final color = _catColors[lc] ?? AppColors.textTertiary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category[0].toUpperCase() + category.substring(1),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_currFmt.format(amount / 100),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${(percentage * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
