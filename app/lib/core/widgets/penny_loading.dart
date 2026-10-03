import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PennyLoadingIndicator extends StatefulWidget {
  final double size;
  final String? message;
  final Color? primaryColor;
  final Color? secondaryColor;

  const PennyLoadingIndicator({
    super.key,
    this.size = 48.0,
    this.message,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<PennyLoadingIndicator> createState() => _PennyLoadingIndicatorState();
}

class _PennyLoadingIndicatorState extends State<PennyLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor ?? AppColors.primary;
    final secondary = widget.secondaryColor ?? const Color(0xFFF2994A);

    final indicator = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final pulse = 0.88 + 0.12 * math.sin(t * 2 * math.pi);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating gradient orbit
              Transform.rotate(
                angle: t * 2 * math.pi,
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _OrbitRingPainter(
                    color1: primary,
                    color2: secondary,
                    strokeWidth: math.max(2.5, widget.size * 0.07),
                  ),
                ),
              ),

              // Counter-rotating inner dashed orbit
              Transform.rotate(
                angle: -t * 2 * math.pi * 0.75,
                child: SizedBox(
                  width: widget.size * 0.68,
                  height: widget.size * 0.68,
                  child: CustomPaint(
                    painter: _InnerArcPainter(
                      color: secondary.withValues(alpha: 0.85),
                      strokeWidth: math.max(1.8, widget.size * 0.05),
                    ),
                  ),
                ),
              ),

              // Glowing center coin pulse
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: widget.size * 0.36,
                  height: widget.size * 0.36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        primary.withValues(alpha: 0.9),
                        secondary.withValues(alpha: 0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.45),
                        blurRadius: widget.size * 0.25,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: widget.size * 0.14,
                      height: widget.size * 0.14,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (widget.message != null && widget.message!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(height: 14),
          Text(
            widget.message!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return indicator;
  }
}

class _OrbitRingPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double strokeWidth;

  _OrbitRingPainter({
    required this.color1,
    required this.color2,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final sweepGradient = SweepGradient(
      colors: [
        color1.withValues(alpha: 0.05),
        color1,
        color2,
        color2.withValues(alpha: 0.05),
      ],
      stops: const [0.0, 0.45, 0.85, 1.0],
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 1.85, false, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) => false;
}

class _InnerArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _InnerArcPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw two opposite mini arcs
    canvas.drawArc(rect, 0, math.pi * 0.7, false, paint);
    canvas.drawArc(rect, math.pi, math.pi * 0.7, false, paint);
  }

  @override
  bool shouldRepaint(covariant _InnerArcPainter oldDelegate) => false;
}

/// Convenience helpers for common Penny loading patterns
class PennyLoading {
  static Widget fullScreen({String message = 'Loading...'}) {
    return Center(
      child: PennyLoadingIndicator(
        size: 54,
        message: message,
      ),
    );
  }

  static Widget card({String? message}) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Center(
        child: PennyLoadingIndicator(
          size: 40,
          message: message,
        ),
      ),
    );
  }

  static Widget inline({double size = 20, Color? color}) {
    return SizedBox(
      width: size,
      height: size,
      child: PennyLoadingIndicator(
        size: size,
        primaryColor: color,
        secondaryColor: color,
      ),
    );
  }
}
