import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/category_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'widgets/interactive_pie_chart.dart';

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
  String? _selectedCategory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _selectedCategory = null;
    });
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

      // Batch all requests with Future.wait
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
    if (mounted) setState(() => _loading = false);
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

    final rawByCategory = _stats?['byCategory'];
    final Map<String, int> byCategory;
    if (rawByCategory is Map<String, dynamic>) {
      byCategory = rawByCategory.map((k, v) => MapEntry(k, (v as num).toInt()));
    } else if (rawByCategory is List) {
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

    // Sorted categories descending
    final sortedEntries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                children: [
                  // Month selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                        ),
                        Text(
                          monthLabel,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (totalSpent > 0 && byCategory.isNotEmpty) ...[
                    // Interactive Pie Chart Card
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Spending Breakdown',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_selectedCategory != null)
                                TextButton(
                                  onPressed: () => setState(() => _selectedCategory = null),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 24),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Reset', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          InteractivePieChart(
                            byCategory: byCategory,
                            totalSpent: totalSpent,
                            selectedCategory: _selectedCategory,
                            onCategorySelected: (cat) {
                              setState(() => _selectedCategory = cat);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Category Breakdown List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'By Category',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${sortedEntries.length} categories',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ...sortedEntries.map((entry) {
                      final pct = totalSpent > 0 ? entry.value / totalSpent : 0.0;
                      final isSelected = _selectedCategory?.toLowerCase() == entry.key.toLowerCase();
                      return _CategoryRow(
                        category: entry.key,
                        amount: entry.value,
                        percentage: pct,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedCategory = isSelected ? null : entry.key;
                          });
                        },
                      );
                    }),

                    const SizedBox(height: 24),
                  ],

                  // 6-month bar chart
                  if (_monthlyTrend.isNotEmpty) ...[
                    const Text(
                      'Monthly Trend',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _BarChart(data: _monthlyTrend),
                    const SizedBox(height: 24),
                  ],

                  if (totalSpent == 0 && byCategory.isEmpty) ...[
                    const SizedBox(height: 50),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.pie_chart_outline, size: 72, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            'No expenses recorded',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add expenses this month to see your spending breakdown',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          ),
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

class _CategoryRow extends StatelessWidget {
  final String category;
  final int amount;
  final double percentage;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = CategoryConstants.get(category);
    final color = meta.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? color : AppColors.border,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Category Icon Badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(meta.icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                // Category details and progress bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            meta.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _currFmt.format(amount / 100),
                            style: TextStyle(
                              color: isSelected ? color : AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage.clamp(0.0, 1.0),
                                backgroundColor: AppColors.border,
                                valueColor: AlwaysStoppedAnimation(color),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(percentage * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: max(4.0, 100 * heightFrac),
                        decoration: BoxDecoration(
                          color: heightFrac > 0.7
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    d['month'] as String,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
