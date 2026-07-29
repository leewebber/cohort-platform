import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../services/capability_radar_projection_service.dart';

/// Calm capability radar for Progress — scaffolding when evidence is missing.
class CapabilityRadarChart extends StatelessWidget {
  const CapabilityRadarChart({
    super.key,
    required this.model,
    this.size = 220,
  });

  final CapabilityRadarModel model;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RadarPainter(model: model),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          model.hasAnyEvidence
              ? 'Capability overview'
              : 'Awaiting evidence — axes shown as scaffolding',
          style: CohortTextStyles.small.copyWith(
            color: CohortColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.model});

  final CapabilityRadarModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final axes = model.axes;
    if (axes.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 28;
    final n = axes.length;
    final angleStep = (2 * math.pi) / n;

    final gridPaint = Paint()
      ..color = CohortColors.border.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = CohortColors.textMuted.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final ring in [0.33, 0.66, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final angle = -math.pi / 2 + i * angleStep;
        final point = Offset(
          center.dx + radius * ring * math.cos(angle),
          center.dy + radius * ring * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final tip = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, tip, axisPaint);

      final label = axes[i].label;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: axes[i].available
                ? CohortColors.textPrimary.withValues(alpha: 0.85)
                : CohortColors.textMuted.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelOffset = Offset(
        center.dx + (radius + 14) * math.cos(angle) - tp.width / 2,
        center.dy + (radius + 14) * math.sin(angle) - tp.height / 2,
      );
      tp.paint(canvas, labelOffset);
    }

    final available = axes.where((a) => a.available && a.normalisedValue != null);
    if (available.isEmpty) return;

    final fillPaint = Paint()
      ..color = CohortColors.phosphor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = CohortColors.phosphor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final value = axes[i].available
          ? (axes[i].normalisedValue ?? 0).clamp(0.0, 1.0)
          : 0.08;
      final point = Offset(
        center.dx + radius * value * math.cos(angle),
        center.dy + radius * value * math.sin(angle),
      );
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.model != model;
}
