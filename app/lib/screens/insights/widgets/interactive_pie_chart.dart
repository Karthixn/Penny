import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/category_constants.dart';

final _currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

class InteractivePieChart extends StatelessWidget {
  final Map<String, int> byCategory;
  final int totalSpent; // in paise
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  const InteractivePieChart({
    super.key,
    required this.byCategory,
    required this.totalSpent,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (byCategory.isEmpty || totalSpent <= 0) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 54, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            const Text('No expense data to display', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    // Sort categories descending by amount
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selectedEntry = selectedCategory != null
        ? entries.where((e) => e.key.toLowerCase() == selectedCategory!.toLowerCase()).firstOrNull
        : null;

    final selectedMeta = selectedEntry != null ? CategoryConstants.get(selectedEntry.key) : null;
    final selectedPct = (selectedEntry != null && totalSpent > 0)
        ? (selectedEntry.value / totalSpent * 100)
        : 0.0;

    return Center(
      child: GestureDetector(
        onTapDown: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final center = Offset(box.size.width / 2, box.size.height / 2);
          final touch = details.localPosition;
          final dx = touch.dx - center.dx;
          final dy = touch.dy - center.dy;
          final dist = sqrt(dx * dx + dy * dy);

          // Slices are drawn between inner radius ~55 and outer radius ~95
          if (dist >= 40 && dist <= 110) {
            // Angle normalized from -pi/2 (top) clockwise
            var angle = atan2(dy, dx) + (pi / 2);
            if (angle < 0) angle += 2 * pi;

            var currentAngle = 0.0;
            String? tappedCat;
            for (final e in entries) {
              final sweep = (e.value / totalSpent) * (2 * pi);
              if (angle >= currentAngle && angle <= currentAngle + sweep) {
                tappedCat = e.key;
                break;
              }
              currentAngle += sweep;
            }

            if (tappedCat != null) {
              if (selectedCategory?.toLowerCase() == tappedCat.toLowerCase()) {
                onCategorySelected(null); // deselect
              } else {
                onCategorySelected(tappedCat);
              }
            }
          } else if (dist < 40) {
            // Tapped center: clear selection
            onCategorySelected(null);
          }
        },
        child: SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(240, 240),
                painter: _PieChartPainter(
                  entries: entries,
                  totalSpent: totalSpent,
                  selectedCategory: selectedCategory,
                ),
              ),
              // Center hole content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedEntry != null && selectedMeta != null) ...[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: selectedMeta.color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(selectedMeta.icon, color: selectedMeta.color, size: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedMeta.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currFmt.format(selectedEntry.value / 100),
                        style: TextStyle(
                          color: selectedMeta.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: selectedMeta.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${selectedPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: selectedMeta.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Total Spent',
                        style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currFmt.format(totalSpent / 100),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap slice to inspect',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final int totalSpent;
  final String? selectedCategory;

  _PieChartPainter({
    required this.entries,
    required this.totalSpent,
    required this.selectedCategory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final normalOuterRadius = size.width / 2 - 24; // ~96
    final selectedOuterRadius = size.width / 2 - 16; // ~104 (expanded)
    const innerRadius = 58.0;

    var startAngle = -pi / 2; // start from top (12 o'clock)
    const gap = 0.035; // gap between slices in radians

    for (final e in entries) {
      final sweepAngle = (e.value / totalSpent) * (2 * pi);
      final isSelected = selectedCategory != null &&
          e.key.toLowerCase() == selectedCategory!.toLowerCase();
      final color = CategoryConstants.getColor(e.key);

      final outerRadius = isSelected ? selectedOuterRadius : normalOuterRadius;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      // Draw slice as a donut arc segment
      final path = Path();
      final effectiveSweep = max(0.01, sweepAngle - (entries.length > 1 ? gap : 0.0));
      final sliceStart = startAngle + (entries.length > 1 ? gap / 2 : 0.0);

      path.arcTo(
        Rect.fromCircle(center: center, radius: outerRadius),
        sliceStart,
        effectiveSweep,
        false,
      );
      path.arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        sliceStart + effectiveSweep,
        -effectiveSweep,
        false,
      );
      path.close();

      canvas.drawPath(path, paint);

      if (isSelected) {
        // Draw subtle outline glow on selected slice
        final strokePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..isAntiAlias = true;
        canvas.drawPath(path, strokePaint);
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.totalSpent != totalSpent ||
        oldDelegate.selectedCategory != selectedCategory;
  }
}
