import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Paints a subtle dot grid background on the canvas.
class GridPainter extends CustomPainter {
  final double gridSize;
  final bool isDark;
  final Matrix4 transform;
  final Size viewportSize;

  GridPainter({
    this.gridSize = 40.0,
    required this.isDark,
    required this.transform,
    required this.viewportSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? AppColors.canvasDarkGrid : AppColors.canvasLightGrid
      ..strokeCap = StrokeCap.round;

    final scale = transform.getMaxScaleOnAxis();

    // Dot radius adapts to zoom level.
    final dotRadius = (1.5 * scale).clamp(0.8, 3.0);
    paint.strokeWidth = dotRadius;

    // Inverse transform to find visible area in canvas coordinates
    final inv = Matrix4.copy(transform)..invert();
    final topLeft = MatrixUtils.transformPoint(inv, Offset.zero);
    final bottomRight = MatrixUtils.transformPoint(inv, Offset(viewportSize.width, viewportSize.height));

    // Calculate the visible grid range.
    final startX = (topLeft.dx / gridSize).floor() * gridSize;
    final startY = (topLeft.dy / gridSize).floor() * gridSize;
    // Add extra padding to ensure edges are covered during rapid pan
    final endX = bottomRight.dx + gridSize * 2;
    final endY = bottomRight.dy + gridSize * 2;

    // Use a pre-allocated list of points for massive performance gain
    final List<Offset> points = [];
    for (double x = startX; x < endX; x += gridSize) {
      if (x < 0 || x > 10000) continue; // clamp to world bounds
      for (double y = startY; y < endY; y += gridSize) {
        if (y < 0 || y > 10000) continue; // clamp to world bounds
        points.add(Offset(x, y));
      }
    }

    if (points.isNotEmpty) {
      // drawPoints is significantly faster than thousands of drawCircle calls
      canvas.drawPoints(ui.PointMode.points, points, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return isDark != oldDelegate.isDark ||
        transform != oldDelegate.transform ||
        viewportSize != oldDelegate.viewportSize;
  }
}
