import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/cable_type.dart';
import '../../models/tutorial_level.dart';
import '../../core/enums/device_type.dart';
import '../../core/constants/device_icons.dart';

class BlueprintPainter extends CustomPainter {
  final TutorialLevel level;
  final int stageIndex;
  final bool isDark;
  final double opacity;

  BlueprintPainter({
    required this.level,
    required this.stageIndex,
    required this.isDark,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stageIndex >= level.stages.length) return;
    final currentStage = level.stages[stageIndex];

    // 1. Draw blueprint connections
    final linePaint = Paint()
      ..color =
          (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)
              .withValues(alpha: opacity)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color =
          (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)
              .withValues(alpha: opacity)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final conn in currentStage.targetConnections) {
      final fromDevice = currentStage.targetDevices.firstWhere(
        (d) => d.id == conn.fromDeviceId,
      );
      final toDevice = currentStage.targetDevices.firstWhere(
        (d) => d.id == conn.toDeviceId,
      );

      if (conn.cableType == CableType.crossover) {
        _drawDashedLine(
          canvas,
          fromDevice.position,
          toDevice.position,
          dashPaint,
        );
      } else if (conn.cableType == CableType.console) {
        // Just draw a curve
        final path = Path();
        path.moveTo(fromDevice.position.dx, fromDevice.position.dy);
        final controlPoint = Offset(
          (fromDevice.position.dx + toDevice.position.dx) / 2,
          fromDevice.position.dy - 100,
        );
        path.quadraticBezierTo(
          controlPoint.dx,
          controlPoint.dy,
          toDevice.position.dx,
          toDevice.position.dy,
        );
        canvas.drawPath(path, linePaint);
      } else {
        // Straight
        canvas.drawLine(fromDevice.position, toDevice.position, linePaint);
      }
    }

    // 2. Draw blueprint devices
    for (final device in currentStage.targetDevices) {
      final color = DeviceIcons.getColor(
        device.type,
      ).withValues(alpha: opacity);
      final icon = DeviceIcons.getIcon(device.type);

      // Solid background for visibility
      final bgPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(
          alpha: opacity * 0.2,
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(device.position, 30, bgPaint);

      // Border
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(device.position, 30, borderPaint);

      // Icon
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 28,
            color: color,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          device.position.dx - textPainter.width / 2,
          device.position.dy - textPainter.height / 2,
        ),
      );

      // Label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: device.type.displayName,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      labelPainter.paint(
        canvas,
        Offset(
          device.position.dx - labelPainter.width / 2,
          device.position.dy + 36,
        ),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    double startX = p1.dx;
    double startY = p1.dy;

    final dx = (p2.dx - p1.dx);
    final dy = (p2.dy - p1.dy);
    final distance = Offset(dx, dy).distance;
    final unitDx = dx / distance;
    final unitDy = dy / distance;

    double drawn = 0.0;
    while (drawn < distance) {
      final curDashWidth = (drawn + dashWidth > distance)
          ? (distance - drawn)
          : dashWidth;
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + unitDx * curDashWidth, startY + unitDy * curDashWidth),
        paint,
      );
      startX += unitDx * (dashWidth + dashSpace);
      startY += unitDy * (dashWidth + dashSpace);
      drawn += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant BlueprintPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.stageIndex != stageIndex ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacity != opacity;
  }
}
