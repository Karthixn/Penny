import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/export_dialog.dart';
import '../../core/widgets/penny_loading.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expenses_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/export_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).loadProfile();
    });
  }

  void _showEditName(Map<String, dynamic>? profile) {
    final ctl = TextEditingController(text: profile?['displayName'] as String? ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Display name',
            filled: true,
            fillColor: const Color(0xFF2C2C34),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A)),
            onPressed: () async {
              final name = ctl.text.trim();
              if (name.isEmpty) return;
              await ref.read(userProvider.notifier).updateProfile({'displayName': name});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditBudget(Map<String, dynamic>? profile) {
    final currency = ref.read(currencyProvider);
    final ctl = TextEditingController(
      text: ((profile?['monthlyBudget'] as int?) != null)
          ? ((profile!['monthlyBudget'] as int) / 100).toStringAsFixed(0)
          : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Monthly Budget', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Budget amount in ${currency.symbol}',
            prefixText: '${currency.symbol} ',
            filled: true,
            fillColor: const Color(0xFF2C2C34),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A)),
            onPressed: () async {
              final val = double.tryParse(ctl.text);
              if (val == null) return;
              await ref.read(userProvider.notifier).updateProfile({'monthlyBudget': (val * 100).round()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditUpi(Map<String, dynamic>? profile) {
    final ctl = TextEditingController(text: profile?['upiId'] as String? ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('UPI ID (VPA)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add your UPI ID so group members can pay you directly via Google Pay or PhonePe in 1 tap.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. name@okhdfcbank, 9876543210@paytm',
                prefixIcon: const Icon(Icons.bolt, color: Color(0xFF00D68F)),
                filled: true,
                fillColor: const Color(0xFF2C2C34),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A)),
            onPressed: () async {
              final upi = ctl.text.trim();
              await ref.read(userProvider.notifier).updateProfile({'upiId': upi});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(ThemeMode currentMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose App Theme',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select your preferred display appearance',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildThemeOption(
                ctx,
                mode: ThemeMode.dark,
                title: 'Dark Mode 🌙',
                subtitle: 'Sleek dark aesthetics, best for battery & low-light',
                isSelected: currentMode == ThemeMode.dark,
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                ctx,
                mode: ThemeMode.light,
                title: 'Light Mode ☀️',
                subtitle: 'Clean, crisp white and high-contrast interface',
                isSelected: currentMode == ThemeMode.light,
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                ctx,
                mode: ThemeMode.system,
                title: 'System Default ⚙️',
                subtitle: 'Follow your device system setting automatically',
                isSelected: currentMode == ThemeMode.system,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext ctx, {
    required ThemeMode mode,
    required String title,
    required String subtitle,
    required bool isSelected,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF7C6FF7).withValues(alpha: 0.15) : const Color(0xFF2C2C34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFF7C6FF7) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        title: Text(title, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C6FF7))
            : const Icon(Icons.circle_outlined, color: Colors.white30),
        onTap: () {
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showCurrencyPicker(AppCurrency currentCurrency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Display Currency',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Amounts across the app will format in your chosen currency',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: AppCurrency.all.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, index) {
                    final curr = AppCurrency.all[index];
                    final isSelected = curr.code == currentCurrency.code;
                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF00D68F).withValues(alpha: 0.15) : const Color(0xFF2C2C34),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF00D68F) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(curr.flag, style: const TextStyle(fontSize: 22)),
                        ),
                        title: Text(
                          '${curr.code} (${curr.symbol})',
                          style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600),
                        ),
                        subtitle: Text(curr.name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00D68F))
                            : const Icon(Icons.circle_outlined, color: Colors.white30),
                        onTap: () {
                          ref.read(currencyProvider.notifier).setCurrency(curr);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutPenny() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // Logo & Badge
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B7FF9), Color(0xFF5B4FCF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C6FF7).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text('₹', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Penny Expense Manager',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00D68F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'v1.0.0 (Release 2026.10) • 100% Free Forever',
                style: TextStyle(color: Color(0xFF00D68F), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Penny is a smart, privacy-first personal and group expense splitter designed to be completely free with zero ads, subscriptions, or locked features.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),

            // Feature Highlights
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C34),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildAboutFeature(Icons.bolt, '1-Tap UPI / GPay Settlements', 'Settle debts instantly via Google Pay & PhonePe'),
                  const Divider(color: Colors.white10, height: 16),
                  _buildAboutFeature(Icons.pie_chart_outline, 'Category Deep-Dive & Insights', 'Interactive pie chart and spending statistics'),
                  const Divider(color: Colors.white10, height: 16),
                  _buildAboutFeature(Icons.table_chart_outlined, 'Excel & CSV Statement Export', 'Shareable directly to WhatsApp or Google Drive'),
                  const Divider(color: Colors.white10, height: 16),
                  _buildAboutFeature(Icons.account_balance_wallet_outlined, 'Personal Expense Tracker', 'Separate individual tracker apart from groups'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C6FF7),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.share, color: Colors.white, size: 18),
              label: const Text('Share Penny with Friends', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Check out Penny! A 100% free expense splitter and personal finance tracker with 1-tap GPay & WhatsApp reminders. Download here: http://192.168.0.124:5000/app-release.apk',
                    subject: 'Track & Split bills with Penny!',
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutFeature(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFF2994A), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportAllExpenses() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: PennyLoadingIndicator(size: 44, message: 'Preparing statement...')),
      );

      final res = await ref.read(expensesApiProvider).list();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final rawData = res['data'];
      final List<Map<String, dynamic>> expenses = [];
      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map) expenses.add(Map<String, dynamic>.from(item));
        }
      }

      if (expenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No expenses recorded yet to export!')),
        );
        return;
      }

      final profile = ref.read(userProvider).profile;
      final userName = profile?['displayName'] as String? ?? 'User';
      final csv = ExportService.generatePersonalCsv(expenses: expenses, userName: userName);
      final whatsAppText = ExportService.generateWhatsAppGroupSummary(
        group: {'name': 'All Transactions (Personal & Groups)'},
        expenses: expenses,
      );

      int totalPaise = 0;
      for (final e in expenses) {
        totalPaise += (e['amount'] as int? ?? 0);
      }
      final totalFormatted = '₹${(totalPaise / 100).toStringAsFixed(2)}';

      ExportBottomSheet.show(
        context: context,
        title: 'Export All Transactions',
        subtitle: 'Comprehensive financial statement',
        csvContent: csv,
        fileName: 'penny_statement_all_${DateTime.now().millisecondsSinceEpoch}.csv',
        whatsAppSummary: whatsAppText,
        itemCount: expenses.length,
        totalFormatted: totalFormatted,
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

  Future<void> _exportPersonalExpenses() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: PennyLoadingIndicator(size: 44, message: 'Preparing personal statement...')),
      );

      final res = await ref.read(expensesApiProvider).list();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final rawData = res['data'];
      final List<Map<String, dynamic>> expenses = [];
      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map && item['groupId'] == null) {
            expenses.add(Map<String, dynamic>.from(item));
          }
        }
      }

      if (expenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No personal expenses recorded yet to export!')),
        );
        return;
      }

      final profile = ref.read(userProvider).profile;
      final userName = profile?['displayName'] as String? ?? 'User';
      final csv = ExportService.generatePersonalCsv(expenses: expenses, userName: userName);
      final whatsAppText = ExportService.generateWhatsAppGroupSummary(
        group: {'name': 'Personal Spending Statement'},
        expenses: expenses,
      );

      int totalPaise = 0;
      for (final e in expenses) {
        totalPaise += (e['amount'] as int? ?? 0);
      }
      final totalFormatted = '₹${(totalPaise / 100).toStringAsFixed(2)}';

      ExportBottomSheet.show(
        context: context,
        title: 'Export Personal Expenses',
        subtitle: 'Personal tracker transactions only',
        csvContent: csv,
        fileName: 'penny_personal_expenses_${DateTime.now().millisecondsSinceEpoch}.csv',
        whatsAppSummary: whatsAppText,
        itemCount: expenses.length,
        totalFormatted: totalFormatted,
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

  String _cleanErrorMessage(dynamic e) {
    if (e is DioException) {
      final resData = e.response?.data;
      if (resData is Map && resData['message'] != null) {
        final msg = resData['message'];
        if (msg is List && msg.isNotEmpty) return msg.first.toString();
        if (msg is String) return msg;
      }
      if (e.response?.statusCode == 400) return 'Invalid verification request';
      if (e.response?.statusCode == 404) return 'User account not found';
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        return 'Could not connect to server. Check your network.';
      }
      return e.message ?? 'Network error occurred';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  void _startEmailVerification([String? email]) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: PennyLoadingIndicator(size: 44, message: 'Requesting verification code...'),
        ),
      );

      final effectiveEmail = (email != null && email.trim().isNotEmpty)
          ? email.trim()
          : (ref.read(userProvider).profile?['email'] as String? ?? '');

      final res = await ref.read(authApiProvider).sendOtp(
        email: effectiveEmail.isNotEmpty ? effectiveEmail : null,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final targetEmail = (res['email'] as String?)?.isNotEmpty == true
          ? res['email'] as String
          : effectiveEmail;

      _showOtpVerificationSheet(targetEmail);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request verification code: ${_cleanErrorMessage(e)}'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  void _showOtpVerificationSheet(String email) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 18),
              const Icon(Icons.mark_email_read_outlined, color: Color(0xFFF2994A), size: 40),
              const SizedBox(height: 12),
              const Text(
                'Verify Email Address',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                email.isNotEmpty
                    ? 'Enter the 6-digit code sent to\n$email'
                    : 'Enter the 6-digit code sent to your registered email',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                  filled: true,
                  fillColor: const Color(0xFF2C2C34),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2994A),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isVerifying
                    ? null
                    : () async {
                        final code = otpController.text.trim();
                        if (code.length != 6) return;
                        setModalState(() => isVerifying = true);
                        try {
                          await ref.read(authApiProvider).verifyOtp(
                            email: email.isNotEmpty ? email : null,
                            otp: code,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted) return;
                          await ref.read(userProvider.notifier).loadProfile();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email verified successfully! 🎉'),
                              backgroundColor: Color(0xFF4CAF50),
                            ),
                          );
                        } catch (err) {
                          setModalState(() => isVerifying = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Verification failed: ${_cleanErrorMessage(err)}'),
                              backgroundColor: AppColors.red,
                            ),
                          );
                        }
                      },
                child: isVerifying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Confirm Verification', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  try {
                    await ref.read(authApiProvider).sendOtp(
                      email: email.isNotEmpty ? email : null,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New code sent!'), backgroundColor: Color(0xFF4CAF50)),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to resend: ${_cleanErrorMessage(e)}'),
                        backgroundColor: AppColors.red,
                      ),
                    );
                  }
                },
                child: const Text('Resend Code', style: TextStyle(color: Color(0xFFF2994A))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () async {
              await ref.read(userProvider.notifier).deleteAccount();
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(userProvider);
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final themeMode = ref.watch(themeModeProvider);
    final currency = ref.watch(currencyProvider);

    final profile = userState.profile;
    final name = profile?['displayName'] as String? ?? '';
    final email = profile?['email'] as String? ?? '';
    final budget = profile?['monthlyBudget'] as int?;
    final isEmailVerified = profile?['isEmailVerified'] as bool? ?? false;
    final upiId = profile?['upiId'] as String? ?? '';

    String themeSubtitle = 'Dark';
    if (themeMode == ThemeMode.light) {
      themeSubtitle = 'Light';
    } else if (themeMode == ThemeMode.system) {
      themeSubtitle = 'System';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: userState.isLoading && profile == null
          ? const Center(child: PennyLoadingIndicator(size: 48, message: 'Loading settings...'))
          : profile == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          userState.isAuthError ? 'Session Expired' : 'Failed to load profile',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          userState.error ?? 'Please check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        if (userState.isAuthError) ...[
                          ElevatedButton.icon(
                            onPressed: () async {
                              ref.invalidate(userProvider);
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) context.go('/login');
                            },
                            icon: const Icon(Icons.login),
                            label: const Text('Sign In Again'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(200, 48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => ref.read(userProvider.notifier).loadProfile(),
                            child: const Text('Retry', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            onPressed: () => ref.read(userProvider.notifier).loadProfile(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Profile card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.isNotEmpty ? name : 'User',
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                const SizedBox(height: 6),
                                if (isEmailVerified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 13),
                                        SizedBox(width: 4),
                                        Text('Email Verified', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: () => _startEmailVerification(email),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2994A).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFF2994A).withValues(alpha: 0.4)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.shield_outlined, color: Color(0xFFF2994A), size: 12),
                                          SizedBox(width: 4),
                                          Text('Unverified • Verify Email', style: TextStyle(color: Color(0xFFF2994A), fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Account Section
                    const Text('Account', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    _SettingsTile(
                      icon: isEmailVerified ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                      title: 'Email Verification',
                      subtitle: isEmailVerified ? 'Verified' : 'Verify for data recovery',
                      trailing: isEmailVerified
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20)
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2994A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Verify', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                      onTap: isEmailVerified ? () {} : () => _startEmailVerification(email),
                    ),
                    _SettingsTile(
                      icon: Icons.person_outline,
                      title: 'Display Name',
                      subtitle: name.isNotEmpty ? name : 'Not set',
                      onTap: () => _showEditName(profile),
                    ),
                    _SettingsTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Monthly Budget',
                      subtitle: budget != null ? '${currency.symbol}${(budget / 100).toStringAsFixed(0)}' : 'Not set',
                      onTap: () => _showEditBudget(profile),
                    ),
                    _SettingsTile(
                      icon: Icons.bolt_outlined,
                      title: 'UPI ID (GPay / PhonePe)',
                      subtitle: upiId.isNotEmpty ? upiId : 'Not set (tap to add)',
                      onTap: () => _showEditUpi(profile),
                    ),

                    const SizedBox(height: 24),

                    // Data & Export Section
                    const Text('Data & Export', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    _SettingsTile(
                      icon: Icons.table_chart_outlined,
                      title: 'Export All Transactions',
                      subtitle: 'Download Excel / CSV or share to WhatsApp',
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF00D68F), size: 16),
                      onTap: _exportAllExpenses,
                    ),
                    _SettingsTile(
                      icon: Icons.person_pin_circle_outlined,
                      title: 'Export Personal Expenses',
                      subtitle: 'Download personal spending sheet',
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF00D68F), size: 16),
                      onTap: _exportPersonalExpenses,
                    ),

                    const SizedBox(height: 24),

                    // App Section (Theme, Currency, About Penny)
                    const Text('App', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: 'Theme',
                      subtitle: themeSubtitle,
                      onTap: () => _showThemePicker(themeMode),
                    ),
                    _SettingsTile(
                      icon: Icons.currency_rupee,
                      title: 'Currency',
                      subtitle: '${currency.code} (${currency.symbol})',
                      onTap: () => _showCurrencyPicker(currency),
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: 'About Penny',
                      subtitle: 'v1.0.0',
                      onTap: _showAboutPenny,
                    ),

                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: () async {
                        ref.invalidate(userProvider);
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                      label: const Text('Sign Out', style: TextStyle(color: AppColors.textSecondary)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _showDeleteAccount,
                      icon: const Icon(Icons.delete_outline, color: AppColors.red),
                      label: const Text('Delete Account', style: TextStyle(color: AppColors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.red),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textSecondary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                ),
                if (trailing != null)
                  trailing!
                else ...[
                  Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
