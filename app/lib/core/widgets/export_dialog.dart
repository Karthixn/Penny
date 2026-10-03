import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../services/export_service.dart';

class ExportBottomSheet {
  static void show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String csvContent,
    required String fileName,
    required String whatsAppSummary,
    int? itemCount,
    String? totalFormatted,
  }) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D68F).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.table_chart_outlined, color: Color(0xFF00D68F), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (itemCount != null || totalFormatted != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C34),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (itemCount != null)
                      Text(
                        '$itemCount transactions',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    if (totalFormatted != null)
                      Text(
                        'Total: $totalFormatted',
                        style: const TextStyle(
                          color: Color(0xFF00D68F),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Button 1: Share Excel / CSV
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D68F),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.share, color: Colors.black, size: 20),
              label: const Text(
                'Share Excel / CSV File',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ExportService.shareOrDownloadCsv(
                  context: context,
                  fileName: fileName,
                  csvContent: csvContent,
                  shareTitle: title,
                  whatsAppMessage: whatsAppSummary,
                );
              },
            ),

            const SizedBox(height: 10),

            // Button 2: Share via WhatsApp text
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp green
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
              label: const Text(
                'Share Summary to WhatsApp',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ExportService.shareViaWhatsApp(
                  context: context,
                  text: whatsAppSummary,
                );
              },
            ),

            const SizedBox(height: 10),

            // Button 3: Copy Text Summary to clipboard
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.copy_outlined, color: Colors.white70, size: 18),
              label: const Text(
                'Copy Summary to Clipboard',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: whatsAppSummary));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Summary copied to clipboard! 📋'),
                    backgroundColor: Color(0xFF00D68F),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
