import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/category_constants.dart';
import '../../core/constants/payment_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/export_dialog.dart';
import '../../core/widgets/penny_loading.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../services/export_service.dart';
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
  List<Map<String, dynamic>>? _categoryTransactions;
  bool _loadingCategoryDetails = false;
  String _activeView = 'category'; // 'category' | 'payment_method' | 'tags'
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
      _categoryTransactions = null;
      _loadingCategoryDetails = false;
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

  Future<void> _selectCategory(String? cat) async {
    if (cat == null || _selectedCategory?.toLowerCase() == cat.toLowerCase()) {
      setState(() {
        _selectedCategory = null;
        _categoryTransactions = null;
        _loadingCategoryDetails = false;
      });
      return;
    }

    setState(() {
      _selectedCategory = cat;
      _loadingCategoryDetails = true;
      _categoryTransactions = null;
    });

    try {
      final res = await ref.read(expensesApiProvider).list(
        category: cat,
        year: _year,
        month: _month,
        limit: 50,
      );
      final rawList = res['data'];
      List<Map<String, dynamic>> items = [];
      if (rawList is List) {
        items = rawList.cast<Map<String, dynamic>>();
      }
      if (mounted && _selectedCategory?.toLowerCase() == cat.toLowerCase()) {
        setState(() {
          _categoryTransactions = items;
          _loadingCategoryDetails = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingCategoryDetails = false;
        });
      }
    }
  }

  Future<void> _exportMonthlyReport() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: PennyLoadingIndicator(size: 44, message: 'Preparing monthly statement...')),
      );

      final startDate = DateTime(_year, _month, 1).toIso8601String();
      final endDate = DateTime(_year, _month + 1, 0, 23, 59, 59).toIso8601String();

      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/expenses', queryParameters: {
        'startDate': startDate,
        'endDate': endDate,
        'limit': 200,
      });

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final rawData = res.data['data'];
      final List<Map<String, dynamic>> items = [];
      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map) items.add(Map<String, dynamic>.from(item));
        }
      }

      final monthStr = DateFormat('MMMM yyyy').format(DateTime(_year, _month));

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No expenses recorded in $monthStr to export!')),
        );
        return;
      }

      final csv = ExportService.generatePersonalCsv(expenses: items, userName: 'Monthly Spending');
      final whatsAppText = ExportService.generateWhatsAppGroupSummary(
        group: {'name': 'Monthly Financial Report ($monthStr)'},
        expenses: items,
      );

      int totalPaise = 0;
      for (final e in items) {
        totalPaise += (e['amount'] as int? ?? 0);
      }

      ExportBottomSheet.show(
        context: context,
        title: 'Monthly Statement',
        subtitle: '$monthStr • Excel / CSV',
        csvContent: csv,
        fileName: 'penny_statement_${_year}_${_month}_${DateTime.now().millisecondsSinceEpoch}.csv',
        whatsAppSummary: whatsAppText,
        itemCount: items.length,
        totalFormatted: '₹${(totalPaise / 100).toStringAsFixed(2)}',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(_year, _month));
    final totalSpent = (_stats?['totalSpent'] as num?)?.toInt() ?? 0;
    final totalIncome = (_stats?['totalIncome'] as num?)?.toInt() ?? 0;
    final netSavings = (_stats?['netSavings'] as num?)?.toInt() ?? (totalIncome - totalSpent);
    final savingsRate = (_stats?['savingsRate'] as num?)?.toDouble() ??
        (totalIncome > 0 ? ((netSavings / totalIncome) * 100).clamp(0.0, 100.0) : 0.0);

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

    // Payment methods map
    final rawByPayment = _stats?['byPaymentMethod'];
    final Map<String, int> byPaymentMethod = {};
    if (rawByPayment is Map<String, dynamic>) {
      rawByPayment.forEach((k, v) => byPaymentMethod[k] = (v as num).toInt());
    }
    final sortedPayments = byPaymentMethod.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Tags map
    final rawByTags = _stats?['byTags'];
    final Map<String, int> byTags = {};
    if (rawByTags is Map<String, dynamic>) {
      rawByTags.forEach((k, v) => byTags[k] = (v as num).toInt());
    }
    final sortedTags = byTags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, color: Color(0xFF00D68F)),
            tooltip: 'Export Monthly Statement (Excel / WhatsApp)',
            onPressed: _exportMonthlyReport,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: PennyLoadingIndicator(size: 48, message: 'Analyzing spending...'))
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

                  const SizedBox(height: 16),

                  // Net Cashflow & Savings Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF2C2C34)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Cashflow & Savings',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (netSavings >= 0 ? const Color(0xFF00D68F) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${savingsRate.toStringAsFixed(0)}% saved',
                                style: TextStyle(
                                  color: netSavings >= 0 ? const Color(0xFF00D68F) : const Color(0xFFEF4444),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Income', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currFmt.format(totalIncome / 100),
                                    style: const TextStyle(color: Color(0xFF00D68F), fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: Colors.white12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Spent', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _currFmt.format(totalSpent / 100),
                                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 17, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(width: 1, height: 32, color: Colors.white12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Net Savings', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _currFmt.format(netSavings / 100),
                                      style: TextStyle(
                                        color: netSavings >= 0 ? const Color(0xFF00D68F) : const Color(0xFFEF4444),
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // View Switcher (Category vs Payment Method vs Tags)
                  Row(
                    children: [
                      _buildViewChip('category', 'Category', Icons.category_outlined),
                      const SizedBox(width: 8),
                      _buildViewChip('payment_method', 'Payment Mode', Icons.payment_outlined),
                      const SizedBox(width: 8),
                      _buildViewChip('tags', 'Tags', Icons.tag),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // VIEW 1: CATEGORY BREAKDOWN
                  if (_activeView == 'category') ...[
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
                                    onPressed: () => _selectCategory(null),
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
                              onCategorySelected: (cat) => _selectCategory(cat),
                            ),
                          ],
                        ),
                      ),

                      // Category Drill-Down Details Card
                      if (_selectedCategory != null) ...[
                        const SizedBox(height: 16),
                        _buildCategoryDrillDown(
                          context: context,
                          category: _selectedCategory!,
                          categoryTotal: byCategory[_selectedCategory!.toLowerCase()] ?? byCategory[_selectedCategory!] ?? 0,
                          totalSpent: totalSpent,
                        ),
                      ],

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
                          onTap: () => _selectCategory(entry.key),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ],

                  // VIEW 2: PAYMENT METHOD BREAKDOWN
                  if (_activeView == 'payment_method') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Methods',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${sortedPayments.length} methods used',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (sortedPayments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No payment method data recorded', style: TextStyle(color: Colors.white38))),
                      )
                    else
                      ...sortedPayments.map((entry) {
                        final pct = totalSpent > 0 ? entry.value / totalSpent : 0.0;
                        return _PaymentMethodRow(
                          methodId: entry.key,
                          amount: entry.value,
                          percentage: pct,
                        );
                      }),
                    const SizedBox(height: 24),
                  ],

                  // VIEW 3: TAGS BREAKDOWN
                  if (_activeView == 'tags') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Spending by Tags',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${sortedTags.length} tags',
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (sortedTags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No tags used in expenses yet', style: TextStyle(color: Colors.white38))),
                      )
                    else
                      ...sortedTags.map((entry) {
                        final pct = totalSpent > 0 ? entry.value / totalSpent : 0.0;
                        return _TagRow(
                          tag: entry.key,
                          amount: entry.value,
                          percentage: pct,
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

                  if (totalSpent == 0 && byCategory.isEmpty && totalIncome == 0) ...[
                    const SizedBox(height: 50),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.pie_chart_outline, size: 72, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            'No transactions recorded',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add income or expenses this month to see your breakdown',
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

  Widget _buildViewChip(String view, String label, IconData icon) {
    final isSel = _activeView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeView = view),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFF2994A).withValues(alpha: 0.15) : const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? const Color(0xFFF2994A) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSel ? const Color(0xFFF2994A) : Colors.white54),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSel ? Colors.white : Colors.white54,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDrillDown({
    required BuildContext context,
    required String category,
    required int categoryTotal,
    required int totalSpent,
  }) {
    final meta = CategoryConstants.get(category);
    final color = meta.color;
    final pct = totalSpent > 0 ? (categoryTotal / totalSpent * 100) : 0.0;
    final txList = _categoryTransactions ?? [];
    final txCount = txList.length;
    final avgAmount = txCount > 0 ? (categoryTotal ~/ txCount) : categoryTotal;

    Map<String, dynamic>? highestExpense;
    if (txList.isNotEmpty) {
      highestExpense = txList.reduce((a, b) {
        final aAmt = (a['totalAmount'] as num?)?.toInt() ?? 0;
        final bAmt = (b['totalAmount'] as num?)?.toInt() ?? 0;
        return aAmt >= bAmt ? a : b;
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(meta.icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              meta.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${pct.toStringAsFixed(1)}% of total',
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Detailed breakdown & transactions',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _selectCategory(null),
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  tooltip: 'Close drill-down',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4-cell Metric Highlights
                Row(
                  children: [
                    Expanded(
                      child: _drillDownStatBox(
                        title: 'Total Spent',
                        value: _currFmt.format(categoryTotal / 100),
                        valueColor: color,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _drillDownStatBox(
                        title: 'Transactions',
                        value: _loadingCategoryDetails ? '...' : '$txCount',
                        valueColor: Colors.white,
                        icon: Icons.receipt_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _drillDownStatBox(
                        title: 'Average Spend',
                        value: _loadingCategoryDetails ? '...' : _currFmt.format(avgAmount / 100),
                        valueColor: Colors.white70,
                        icon: Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _drillDownStatBox(
                        title: 'Highest Bill',
                        value: _loadingCategoryDetails
                            ? '...'
                            : (highestExpense != null
                                ? _currFmt.format(((highestExpense['totalAmount'] as num?)?.toInt() ?? 0) / 100)
                                : '—'),
                        valueColor: const Color(0xFFF2994A),
                        icon: Icons.star_border,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Transactions List Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transactions for ${meta.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_loadingCategoryDetails && txList.isNotEmpty)
                      Text(
                        'Tap item to view',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_loadingCategoryDetails)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: PennyLoadingIndicator(
                        size: 38,
                        primaryColor: color,
                        secondaryColor: color,
                        message: 'Loading ${meta.label} transactions...',
                      ),
                    ),
                  )
                else if (txList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141419),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 36, color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text(
                          'No transactions found for ${meta.label} in this period',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ...txList.map((tx) {
                    final isTop = highestExpense != null && tx['id'] == highestExpense['id'];
                    final amt = (tx['totalAmount'] as num?)?.toInt() ?? 0;
                    final desc = (tx['description'] as String?)?.isNotEmpty == true
                        ? tx['description'] as String
                        : meta.label;
                    final rawDate = tx['date'] as String?;
                    String formattedDate = '';
                    if (rawDate != null) {
                      try {
                        formattedDate = DateFormat('dd MMM, hh:mm a').format(DateTime.parse(rawDate).toLocal());
                      } catch (_) {
                        formattedDate = rawDate;
                      }
                    }
                    final payMethod = tx['paymentMethod'] as String? ?? 'upi';
                    final payMeta = PaymentConstants.get(payMethod);
                    final isGroupExp = tx['groupId'] != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141419),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isTop ? color.withValues(alpha: 0.4) : const Color(0xFF282830),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            final id = tx['id'] as String?;
                            if (id != null) context.push('/expenses/$id');
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(meta.icon, color: color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              desc,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isTop) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF2994A).withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('Top',
                                                  style: TextStyle(
                                                      color: Color(0xFFF2994A),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (formattedDate.isNotEmpty)
                                            Text(
                                              formattedDate,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.4),
                                                fontSize: 11,
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2C2C34),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(payMeta.icon, size: 10, color: Colors.white60),
                                                const SizedBox(width: 3),
                                                Text(payMeta.label,
                                                    style: const TextStyle(color: Colors.white60, fontSize: 10)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: (isGroupExp ? const Color(0xFF9B51E0) : const Color(0xFF2F80ED))
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isGroupExp ? '👥 Group' : '👤 Personal',
                                              style: TextStyle(
                                                color: isGroupExp ? const Color(0xFF9B51E0) : const Color(0xFF2F80ED),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _currFmt.format(amt / 100),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 16, color: Colors.white30),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drillDownStatBox({
    required String title,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF282830)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: Colors.white38),
              const SizedBox(width: 5),
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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

class _PaymentMethodRow extends StatelessWidget {
  final String methodId;
  final int amount;
  final double percentage;

  const _PaymentMethodRow({
    required this.methodId,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final meta = PaymentConstants.get(methodId);
    final color = meta.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(meta.icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        meta.label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _currFmt.format(amount / 100),
                        style: TextStyle(
                          color: color,
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
    );
  }
}

class _TagRow extends StatelessWidget {
  final String tag;
  final int amount;
  final double percentage;

  const _TagRow({
    required this.tag,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFF2994A);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text(
                '#',
                style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '#$tag',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _currFmt.format(amount / 100),
                        style: const TextStyle(
                          color: color,
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
                            valueColor: const AlwaysStoppedAnimation(color),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(percentage * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
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
    );
  }
}
