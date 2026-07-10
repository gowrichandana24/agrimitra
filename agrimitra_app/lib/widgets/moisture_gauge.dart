import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class MoistureGauge extends StatelessWidget {
  final double moisture; // 0-100
  final double size;

  const MoistureGauge({super.key, required this.moisture, this.size = 160});

  Color get fillColor {
    if (moisture < 25) return AgriMitraColors.accent; // dry — amber
    if (moisture < 70) return AgriMitraColors.primary; // healthy — green
    return AgriMitraColors.water; // saturated — blue
  }

  String get statusLabel {
    if (moisture < 15) return 'Very dry';
    if (moisture < 25) return 'Dry';
    if (moisture < 70) return 'Healthy';
    return 'Saturated';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(moisture: moisture, color: fillColor),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${moisture.round()}%',
                style: GoogleFonts.fraunces(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w600,
                  color: AgriMitraColors.ink,
                ),
              ),
              Text(
                statusLabel,
                style: GoogleFonts.mulish(
                  fontSize: size * 0.08,
                  fontWeight: FontWeight.w600,
                  color: AgriMitraColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double moisture;
  final Color color;

  _GaugePainter({required this.moisture, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    const startAngle = pi * 0.75; // gauge sweeps 270 degrees, like a dial
    const sweepAngle = pi * 1.5;

    final trackPaint = Paint()
      ..color = const Color(0xFFE7E2D3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false, trackPaint,
    );

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final fillSweep = sweepAngle * (moisture.clamp(0, 100) / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, fillSweep, false, fillPaint,
    );

    // small tick marks, like a real instrument dial
    final tickPaint = Paint()
      ..color = const Color(0xFFCFC8B5)
      ..strokeWidth = 2;
    for (int i = 0; i <= 10; i++) {
      final angle = startAngle + sweepAngle * (i / 10);
      final outer = Offset(
        center.dx + (radius + 8) * cos(angle),
        center.dy + (radius + 8) * sin(angle),
      );
      final inner = Offset(
        center.dx + (radius + 2) * cos(angle),
        center.dy + (radius + 2) * sin(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.moisture != moisture || oldDelegate.color != color;
}