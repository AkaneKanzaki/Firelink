import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/device_icons.dart';
import '../../models/device.dart';

/// Paints network devices on the canvas with icons, labels, and selection glow.
class DevicePainter extends CustomPainter {
  final List<NetworkDevice> devices;
  final bool isDark;

  DevicePainter({required this.devices, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    for (final device in devices) {
      _drawDevice(canvas, device);
    }
  }

  void _drawDevice(Canvas canvas, NetworkDevice device) {
    final center = device.position;
    final color = DeviceIcons.getColor(device.type);
    final iconData = DeviceIcons.getIcon(device.type);

    // ─── Selection glow ─────────────────────────────────────────
    if (device.isSelected) {
      final glowPaint = Paint()
        ..color = AppColors.selectionGlow.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(center, 44, glowPaint);

      // Selection ring
      final ringPaint = Paint()
        ..color = AppColors.selectionGlow.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, 36, ringPaint);
    }

    // ─── Device body (circle background) ────────────────────────
    final bodyPaint = Paint()
      ..color = isDark
          ? AppColors.darkSurfaceVariant
          : AppColors.lightSurfaceVariant;
    canvas.drawCircle(center, 30, bodyPaint);

    // Border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 30, borderPaint);

    // ─── Device icon ────────────────────────────────────────────
    _drawIcon(canvas, iconData, color, 28, center);

    // ─── Port indicators ────────────────────────────────────────
    _drawPortIndicators(canvas, device, center);

    // ─── Hostname label ─────────────────────────────────────────
    _drawLabel(canvas, device.hostname, center);
  }

  void _drawPortIndicators(Canvas canvas, NetworkDevice device, Offset center) {
    final totalPorts = device.interfaces.length;
    if (totalPorts <= 0) return;

    const radius = 34.0;
    const portDotRadius = 3.0;

    for (int i = 0; i < totalPorts; i++) {
      final iface = device.interfaces[i];
      final angle = (2 * pi * i / totalPorts) - pi / 2;
      final portCenter = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      final portPaint = Paint()
        ..color = iface.isConnected
            ? AppColors.linkUp
            : (isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary);

      canvas.drawCircle(portCenter, portDotRadius, portPaint);

      // Draw IP/Mask label if configured
      if (iface.isConfigured) {
        final textRadius = radius + 15.0; // Place it slightly further out
        final textCenter = Offset(
          center.dx + textRadius * cos(angle),
          center.dy + textRadius * sin(angle),
        );

        final textPainter = TextPainter(
          text: TextSpan(
            text: '${iface.name}\n${iface.ipAddress}\n${iface.subnetMask}',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              fontSize: 8,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();

        // Adjust position so text is centered on the textCenter offset
        textPainter.paint(
          canvas,
          Offset(
            textCenter.dx - textPainter.width / 2,
            textCenter.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset deviceCenter) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: 100);

    textPainter.paint(
      canvas,
      Offset(deviceCenter.dx - textPainter.width / 2, deviceCenter.dy + 36),
    );
  }

  /// Draws a Material Icon on the canvas using TextPainter.
  void _drawIcon(
    Canvas canvas,
    IconData icon,
    Color color,
    double size,
    Offset center,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant DevicePainter oldDelegate) {
    return true; // Devices can move/change frequently.
  }
}
