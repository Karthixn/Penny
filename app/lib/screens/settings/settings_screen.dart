import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

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
        backgroundColor: AppColors.surface,
        title: const Text('Edit Name', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Display name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = ctl.text.trim();
              if (name.isEmpty) return;
              await ref.read(userProvider.notifier).updateProfile({'displayName': name});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditBudget(Map<String, dynamic>? profile) {
    final ctl = TextEditingController(
      text: ((profile?['monthlyBudget'] as int?) != null)
          ? ((profile!['monthlyBudget'] as int) / 100).toStringAsFixed(0)
          : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Monthly Budget', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Amount in ₹', prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(ctl.text);
              if (val == null) return;
              await ref.read(userProvider.notifier).updateProfile({'monthlyBudget': (val * 100).round()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
          child: CircularProgressIndicator(color: Color(0xFFF2994A)),
        ),
      );

      final effectiveEmail = (email != null && email.trim().isNotEmpty)
          ? email.trim()
          : (ref.read(userProvider).profile?['email'] as String? ?? '');

      final res = await ref.read(authApiProvider).sendOtp(
        email: effectiveEmail.isNotEmpty ? effectiveEmail : null,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

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
        backgroundColor: AppColors.surface,
        title: const Text('Delete Account', style: TextStyle(color: AppColors.red)),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone.', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () async {
              await ref.read(userProvider.notifier).deleteAccount();
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(userProvider);
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final profile = userState.profile;
    final name = profile?['displayName'] as String? ?? '';
    final email = profile?['email'] as String? ?? '';
    final budget = profile?['monthlyBudget'] as int?;
    final isEmailVerified = profile?['isEmailVerified'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: userState.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.red, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load profile',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          userState.error ?? 'Please check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => ref.read(userProvider.notifier).loadProfile(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
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
                  subtitle: budget != null ? '₹${(budget / 100).toStringAsFixed(0)}' : 'Not set',
                  onTap: () => _showEditBudget(profile),
                ),

                const SizedBox(height: 24),
                const Text('App', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Theme',
                  subtitle: 'Dark',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.currency_rupee,
                  title: 'Currency',
                  subtitle: 'INR (₹)',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'About Penny',
                  subtitle: 'v1.0.0',
                  onTap: () {},
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
