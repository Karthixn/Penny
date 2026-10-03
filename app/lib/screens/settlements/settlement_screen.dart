import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settlements_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/user_provider.dart';

final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

class SettlementScreen extends ConsumerWidget {
  final String groupId;
  const SettlementScreen({super.key, required this.groupId});

  Future<void> _payViaUpi(
    BuildContext context,
    WidgetRef ref,
    String payerId,
    String payeeId,
    Map<String, dynamic> to,
    int amountPaise, {
    String? note,
  }) async {
    final payeeName = (to['displayName'] ?? to['email'] ?? 'Member').toString();
    String vpa = (to['upiId'] as String? ?? '').trim();

    if (vpa.isEmpty) {
      final ctl = TextEditingController();
      final entered = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: Text('Pay $payeeName via UPI', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter payee UPI ID or phone number (e.g. 9876543210@paytm, name@okhdfcbank):',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'user@upi or 9876543210@paytm',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.bolt, color: Color(0xFF00D68F)),
                  filled: true,
                  fillColor: const Color(0xFF282830),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D68F)),
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              child: const Text('Open UPI App', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (entered == null || entered.isEmpty) return;
      vpa = entered;
    }

    final amountInr = (amountPaise / 100).toStringAsFixed(2);
    final upiUri = Uri.parse(
      'upi://pay?pa=$vpa&pn=${Uri.encodeComponent(payeeName)}&am=$amountInr&cu=INR&tn=${Uri.encodeComponent('Penny settlement')}',
    );

    try {
      final launched = await launchUrl(upiUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open UPI app. Make sure Google Pay or PhonePe is installed.')),
          );
        }
      } else {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: const Text('Confirm Settlement?', style: TextStyle(color: Colors.white)),
            content: Text(
              'Did your payment of ₹$amountInr to $payeeName succeed in Google Pay / UPI?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not Yet', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D68F)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _recordSettlement(context, ref, payerId, payeeId, amountPaise, note ?? 'Paid via GPay/UPI');
                },
                child: const Text('Yes, Record Settlement', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch UPI app: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _recordSettlement(
    BuildContext context,
    WidgetRef ref,
    String payerId,
    String payeeId,
    int amountPaise,
    String? note,
  ) async {
    try {
      await ref.read(settlementsApiProvider).create({
        'groupId': groupId,
        'payerId': payerId,
        'payeeId': payeeId,
        'amount': amountPaise,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement recorded successfully!'), backgroundColor: Color(0xFF00D68F)),
        );
      }
      ref.invalidate(settlementOptimizeProvider(groupId));
      ref.invalidate(groupDetailProvider(groupId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record settlement: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _showPartPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    String payerId,
    String payeeId,
    Map<String, dynamic> from,
    Map<String, dynamic> to,
    int maxAmountPaise, {
    required bool isMeCreditor,
  }) {
    final amountController = TextEditingController(text: (maxAmountPaise / 100).toStringAsFixed(0));
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(
          isMeCreditor
              ? 'Record Partial Received'
              : 'Part Payment to ${to['displayName'] ?? 'Member'}',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMeCreditor ? 'Enter amount received:' : 'Enter amount to settle now:',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: Color(0xFFF2994A), fontSize: 20, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: const Color(0xFF282830),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: isMeCreditor ? 'Note (optional, e.g. Received part cash)' : 'Note (optional, e.g. GPay part 1)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF282830),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2994A)),
            onPressed: () {
              final entered = double.tryParse(amountController.text.trim()) ?? 0;
              final enteredPaise = (entered * 100).round();
              if (enteredPaise <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: AppColors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              _recordSettlement(
                context,
                ref,
                payerId,
                payeeId,
                enteredPaise,
                noteController.text.trim().isNotEmpty
                    ? noteController.text.trim()
                    : (isMeCreditor ? 'Partial amount received' : 'Partial payment'),
              );
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRemindDialog(
    BuildContext context,
    String debtorName,
    String myName,
    int amountPaise,
    Map<String, dynamic> myUser,
  ) {
    final amountInr = (amountPaise / 100).toStringAsFixed(2);
    final myUpi = (myUser['upiId'] as String? ?? '').trim();
    final upiSuffix = myUpi.isNotEmpty ? '\nUPI ID: $myUpi' : '';
    final message = 'Hi $debtorName, please settle your group balance of ₹$amountInr on Penny!$upiSuffix';

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remind $debtorName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send a payment reminder for ₹$amountInr:', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF282830),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            icon: const Icon(Icons.chat, color: Colors.black, size: 16),
            label: const Text('WhatsApp', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(dCtx);
              final waUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
              try {
                await launchUrl(waUri, mode: LaunchMode.externalApplication);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open WhatsApp')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSettlements = ref.watch(settlementOptimizeProvider(groupId));
    final userState = ref.watch(userProvider);
    final currentUserId = (userState.profile?['id'] ?? '').toString();
    final currentUserName = (userState.profile?['displayName'] ?? 'You').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Settle Up')),
      body: asyncSettlements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settlements) {
          if (settlements.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 72, color: AppColors.green),
                  SizedBox(height: 16),
                  Text('All settled up!',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('No pending payments',
                      style: TextStyle(color: AppColors.textTertiary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: settlements.length,
            itemBuilder: (context, index) {
              final s = settlements[index];
              final from = s['from'] as Map<String, dynamic>;
              final to = s['to'] as Map<String, dynamic>;
              final fromId = (from['id'] ?? from['_id'] ?? '').toString();
              final toId = (to['id'] ?? to['_id'] ?? '').toString();
              final fromName = (from['displayName'] ?? from['email'] ?? 'Member').toString();
              final toName = (to['displayName'] ?? to['email'] ?? 'Member').toString();
              final amount = s['amount'] as int;

              final isMeDebtor = currentUserId.isNotEmpty && currentUserId == fromId;
              final isMeCreditor = currentUserId.isNotEmpty && currentUserId == toId;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Role Badge
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isMeCreditor
                                ? const Color(0xFF00D68F)
                                : (isMeDebtor ? const Color(0xFFEF4444) : const Color(0xFFF2994A)))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isMeCreditor
                            ? '$fromName owes you ${_fmt.format(amount / 100)}'
                            : (isMeDebtor
                                ? 'You owe $toName ${_fmt.format(amount / 100)}'
                                : '$fromName owes $toName ${_fmt.format(amount / 100)}'),
                        style: TextStyle(
                          color: isMeCreditor
                              ? const Color(0xFF00D68F)
                              : (isMeDebtor ? const Color(0xFFEF4444) : const Color(0xFFF2994A)),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    Row(
                      children: [
                        _Avatar(name: from['displayName'] ?? 'U'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(from['displayName'] ?? from['email'] ?? '',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                              const Text('pays', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward, color: AppColors.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(to['displayName'] ?? to['email'] ?? '',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                              const Text('receives', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _Avatar(name: to['displayName'] ?? 'U'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _fmt.format(amount / 100),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role-aware buttons
                    if (isMeCreditor) ...[
                      // Current user is owed money by fromName
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D68F),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: Text('Mark as Received (${_fmt.format(amount / 100)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E24),
                              title: const Text('Confirm Payment Received', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              content: Text('Did $fromName pay you ${_fmt.format(amount / 100)}?', style: const TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D68F)),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Yes, Received', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            _recordSettlement(context, ref, fromId, toId, amount, 'Confirmed received by $toName');
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFF2994A)),
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.share_outlined, size: 15, color: Color(0xFFF2994A)),
                              label: Text('Remind $fromName',
                                  style: const TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.w600, fontSize: 12)),
                              onPressed: () => _showRemindDialog(context, fromName, toName, amount, to),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showPartPaymentDialog(context, ref, fromId, toId, from, to, amount, isMeCreditor: true),
                              child: const Text('Part Received', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isMeDebtor) ...[
                      // Current user owes money to toName
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D68F),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.bolt, size: 20),
                        label: const Text('Pay Now (GPay / UPI)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () => _payViaUpi(context, ref, fromId, toId, to, amount),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _recordSettlement(
                                context,
                                ref,
                                fromId,
                                toId,
                                amount,
                                'Paid in cash',
                              ),
                              child: const Text('I Paid via Cash', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFF2994A)),
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showPartPaymentDialog(context, ref, fromId, toId, from, to, amount, isMeCreditor: false),
                              child: const Text('Part Pay', style: TextStyle(color: Color(0xFFF2994A), fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Third-party: Amithabh owes Charlie, and user is viewing!
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F80ED),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text('Record: $fromName Paid $toName',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => _recordSettlement(
                          context,
                          ref,
                          fromId,
                          toId,
                          amount,
                          'Settled by $currentUserName on behalf of $fromName',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF00D68F)),
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.bolt, color: Color(0xFF00D68F), size: 16),
                        label: Text('Pay on Behalf of $fromName (GPay / UPI)',
                            style: const TextStyle(color: Color(0xFF00D68F), fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => _payViaUpi(
                          context,
                          ref,
                          fromId,
                          toId,
                          to,
                          amount,
                          note: 'Paid by $currentUserName on behalf of $fromName',
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
      ),
    );
  }
}
