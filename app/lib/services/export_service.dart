import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ExportService {
  /// Generate CSV content for group expenses
  static String generateGroupCsv({
    required Map<String, dynamic> group,
    required List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>>? settlements,
  }) {
    final groupName = group['name'] as String? ?? 'Group';
    final currencySymbol = '₹';
    final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final sb = StringBuffer();
    // UTF-8 BOM so Microsoft Excel opens it seamlessly with UTF-8 characters
    sb.write('\uFEFF');

    // Header info
    sb.writeln('"=== PENNY GROUP EXPENSE STATEMENT ==="');
    sb.writeln('"Group Name:","$groupName"');
    sb.writeln('"Generated On:","$nowStr"');
    sb.writeln('"Total Transactions:","${expenses.length}"');

    // Calculate total spend
    int totalPaise = 0;
    for (final exp in expenses) {
      totalPaise += (exp['amount'] as int? ?? 0);
    }
    sb.writeln('"Total Group Spending:","$currencySymbol${(totalPaise / 100).toStringAsFixed(2)}"');
    sb.writeln('');

    // Table Header
    sb.writeln('"Date","Description","Category","Paid By","Amount ($currencySymbol)","Split Mode","Split Details","Notes"');

    // Rows
    for (final exp in expenses) {
      final dateStr = _formatDate(exp['createdAt'] ?? exp['date']);
      final desc = _clean(exp['description'] as String? ?? 'Expense');
      final cat = _clean(exp['category'] as String? ?? 'General');
      final payer = _clean(exp['paidBy']?['displayName'] ?? exp['payerName'] ?? 'Unknown');
      final amount = ((exp['amount'] as int? ?? 0) / 100).toStringAsFixed(2);
      final splitType = _clean(exp['splitType'] as String? ?? 'EQUAL');
      
      // Splits summary
      String splitsSummary = '';
      final splits = exp['splits'] as List<dynamic>? ?? [];
      if (splits.isNotEmpty) {
        splitsSummary = splits.map((s) {
          final uName = s['user']?['displayName'] ?? 'Member';
          final sAmt = ((s['amount'] as int? ?? 0) / 100).toStringAsFixed(2);
          return '$uName: $currencySymbol$sAmt';
        }).join('; ');
      }
      final notes = _clean(exp['notes'] as String? ?? '');

      sb.writeln('"$dateStr","$desc","$cat","$payer","$amount","$splitType","${_clean(splitsSummary)}","$notes"');
    }

    if (settlements != null && settlements.isNotEmpty) {
      sb.writeln('');
      sb.writeln('"=== SETTLEMENTS & PAYMENTS ==="');
      sb.writeln('"Date","Payer","Payee","Amount ($currencySymbol)","Status","Note"');
      for (final s in settlements) {
        final sDate = _formatDate(s['createdAt']);
        final sPayer = _clean(s['payer']?['displayName'] ?? 'Payer');
        final sPayee = _clean(s['payee']?['displayName'] ?? 'Payee');
        final sAmt = ((s['amount'] as int? ?? 0) / 100).toStringAsFixed(2);
        final sStatus = _clean(s['status'] as String? ?? 'SETTLED');
        final sNote = _clean(s['note'] as String? ?? '');
        sb.writeln('"$sDate","$sPayer","$sPayee","$sAmt","$sStatus","$sNote"');
      }
    }

    return sb.toString();
  }

  /// Generate CSV content for personal or general expenses
  static String generatePersonalCsv({
    required List<Map<String, dynamic>> expenses,
    String userName = 'User',
  }) {
    final currencySymbol = '₹';
    final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final sb = StringBuffer();
    sb.write('\uFEFF');

    sb.writeln('"=== PENNY PERSONAL EXPENSES STATEMENT ==="');
    sb.writeln('"User:","$userName"');
    sb.writeln('"Generated On:","$nowStr"');
    sb.writeln('"Total Transactions:","${expenses.length}"');

    int totalPaise = 0;
    for (final exp in expenses) {
      totalPaise += (exp['amount'] as int? ?? 0);
    }
    sb.writeln('"Total Spend:","$currencySymbol${(totalPaise / 100).toStringAsFixed(2)}"');
    sb.writeln('');

    sb.writeln('"Date","Description","Category","Type","Amount ($currencySymbol)","Payment Method","Notes"');

    for (final exp in expenses) {
      final dateStr = _formatDate(exp['createdAt'] ?? exp['date']);
      final desc = _clean(exp['description'] as String? ?? 'Expense');
      final cat = _clean(exp['category'] as String? ?? 'General');
      final isPersonal = exp['groupId'] == null;
      final type = isPersonal ? 'Personal' : 'Group Split';
      final amount = ((exp['amount'] as int? ?? 0) / 100).toStringAsFixed(2);
      final paymentMethod = _clean(exp['paymentMethod'] as String? ?? 'UPI');
      final notes = _clean(exp['notes'] as String? ?? '');

      sb.writeln('"$dateStr","$desc","$cat","$type","$amount","$paymentMethod","$notes"');
    }

    return sb.toString();
  }

  /// Generate formatted summary text optimized for WhatsApp messages
  static String generateWhatsAppGroupSummary({
    required Map<String, dynamic> group,
    required List<Map<String, dynamic>> expenses,
  }) {
    final groupName = group['name'] as String? ?? 'Group';
    int totalPaise = 0;
    final categoryTotals = <String, int>{};

    for (final exp in expenses) {
      final amt = exp['amount'] as int? ?? 0;
      totalPaise += amt;
      final cat = (exp['category'] as String? ?? 'General').toUpperCase();
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;
    }

    final totalInr = (totalPaise / 100).toStringAsFixed(2);

    final sb = StringBuffer();
    sb.writeln('📊 *Penny Expense Statement*');
    sb.writeln('👥 *Group:* $groupName');
    sb.writeln('💰 *Total Spend:* ₹$totalInr');
    sb.writeln('🧾 *Transactions:* ${expenses.length}');
    sb.writeln('📅 *Date:* ${DateFormat('dd MMM yyyy').format(DateTime.now())}');
    sb.writeln('');
    sb.writeln('*Category Breakdown:*');

    final sortedCats = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedCats.take(5)) {
      final inr = (entry.value / 100).toStringAsFixed(2);
      final pct = totalPaise > 0 ? (entry.value / totalPaise * 100).toStringAsFixed(1) : '0';
      sb.writeln('• ${entry.key}: ₹$inr ($pct%)');
    }

    sb.writeln('');
    sb.writeln('📎 _Detailed transaction spreadsheet attached (open in Excel/Sheets)._');
    sb.writeln('⚡ _Tracked & Split effortlessly with Penny app_');

    return sb.toString();
  }

  /// Share or download spreadsheet
  static Future<void> shareOrDownloadCsv({
    required BuildContext context,
    required String fileName,
    required String csvContent,
    required String shareTitle,
    String? whatsAppMessage,
  }) async {
    try {
      final bytes = utf8.encode(csvContent);

      if (kIsWeb) {
        // Web handling: trigger browser download via XFile
        final xFile = XFile.fromData(
          Uint8List.fromList(bytes),
          name: fileName,
          mimeType: 'text/csv',
        );

        await SharePlus.instance.share(
          ShareParams(
            text: whatsAppMessage ?? shareTitle,
            subject: shareTitle,
          ),
        );

        // Also offer download
        await xFile.saveTo(fileName);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "$fileName" downloaded successfully! 📁'),
              backgroundColor: const Color(0xFF00D68F),
            ),
          );
        }
      } else {
        // Native Android / iOS
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        final xFile = XFile(filePath, mimeType: 'text/csv');

        await SharePlus.instance.share(
          ShareParams(
            files: [xFile],
            text: whatsAppMessage ?? shareTitle,
            subject: shareTitle,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: const Color(0xFFFF5757),
          ),
        );
      }
    }
  }

  /// Direct WhatsApp share with pre-filled text
  static Future<void> shareViaWhatsApp({
    required BuildContext context,
    required String text,
  }) async {
    final encoded = Uri.encodeComponent(text);
    final waUri = Uri.parse('whatsapp://send?text=$encoded');
    final webWaUri = Uri.parse('https://api.whatsapp.com/send?text=$encoded');

    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webWaUri)) {
        await launchUrl(webWaUri, mode: LaunchMode.externalApplication);
      } else {
        await SharePlus.instance.share(ShareParams(text: text));
      }
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  static String _clean(String val) {
    return val.replaceAll('"', '""').replaceAll('\n', ' ');
  }

  static String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      if (date is DateTime) return DateFormat('yyyy-MM-dd HH:mm').format(date);
      final parsed = DateTime.tryParse(date.toString());
      if (parsed != null) return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
      return date.toString();
    } catch (_) {
      return date.toString();
    }
  }
}
