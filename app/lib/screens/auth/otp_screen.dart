import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  int _resendCountdown = 45;
  Timer? _timer;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 45);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full 6-digit code'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).verifyOtp(
          email: widget.email,
          otp: code,
        );

    if (success && mounted) {
      context.go('/home');
    }
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0 || _resending) return;
    setState(() => _resending = true);

    final sent = await ref.read(authProvider.notifier).resendOtp(widget.email);
    if (mounted) {
      setState(() => _resending = false);
      if (sent) {
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent! Check your inbox.'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: AppColors.red,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify Your Email',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'We have sent a 6-digit verification code to',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 36),

              // PIN display boxes
              GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final text = _otpController.text;
                    final char = index < text.length ? text[index] : '';
                    final isFocused = index == text.length || (index == 5 && text.length == 6);

                    return Container(
                      width: 44,
                      height: 54,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused ? AppColors.primary : AppColors.border,
                          width: isFocused ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        char,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Hidden text field for input
              Opacity(
                opacity: 0.0,
                child: TextField(
                  controller: _otpController,
                  focusNode: _focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (val) {
                    setState(() {});
                    if (val.length == 6) {
                      _verify();
                    }
                  },
                ),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: auth.status == AuthStatus.loading ? null : _verify,
                child: auth.status == AuthStatus.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verify & Continue'),
              ),

              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive the code? ",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: _resendCountdown == 0 && !_resending ? _resend : null,
                    child: Text(
                      _resendCountdown > 0
                          ? 'Resend in ${_resendCountdown}s'
                          : _resending
                              ? 'Sending...'
                              : 'Resend Code',
                      style: TextStyle(
                        color: _resendCountdown == 0 && !_resending
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
