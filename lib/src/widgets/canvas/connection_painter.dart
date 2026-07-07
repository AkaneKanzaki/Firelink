import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/cable_type.dart';
import '../../core/enums/device_type.dart';
import '../../core/enums/interface_status.dart';
import '../../core/utils/canvas_utils.dart';
import '../../core/utils/ip_utils.dart';
import '../../models/connection.dart';
import '../../models/device.dart';

/// Paints connections (cables) between devices on the canvas.
class ConnectionPainter extends CustomPainter {
  final List<Connection> connections;
  final List<NetworkDevice> devices;
  final String? selectedConnectionId;
  final bool isDark;

  /// If set, draws a preview line from this device to [pendingEndPoint].
  final String? pendingFromDeviceId;
  final Offset? pendingEndPoint;

  ConnectionPainter({
    required this.connections,
    required this.devices,
    this.selectedConnectionId,
    required this.isDark,
    this.pendingFromDeviceId,
    this.pendingEndPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw existing connections.
    for (final conn in connections) {
      _drawConnection(canvas, conn);
    }

    // Draw pending connection preview.
    if (pendingFromDeviceId != null && pendingEndPoint != null) {
      _drawPendingConnection(canvas);
    }
  }

  void _drawConnection(Canvas canvas, Connection conn) {
    final deviceA = _findDevice(conn.deviceAId);
    final deviceB = _findDevice(conn.deviceBId);
    if (deviceA == null || deviceB == null) return;

    final start = CanvasUtils.getInterfacePosition(
      deviceA,
      conn.interfaceAName,
    );
    final end = CanvasUtils.getInterfacePosition(deviceB, conn.interfaceBName);
    final isSelected = conn.id == selectedConnectionId;

    // Interface statuses.
    final ifaceA = deviceA.getInterface(conn.interfaceAName);
    final ifaceB = deviceB.getInterface(conn.interfaceBName);

    final statusA = ifaceA?.status ?? InterfaceStatus.disabled;
    final statusB = ifaceB?.status ?? InterfaceStatus.disabled;

    // Connection line color based on dynamic status.
    Color lineColor;
    if (isSelected) {
      lineColor = AppColors.selectionGlow;
    } else if (statusA != InterfaceStatus.up || statusB != InterfaceStatus.up) {
      // If either side is down or disabled (switch is OFF), link is RED (disconnected).
      lineColor = AppColors.connectionInactive;
    } else {
      // Both sides are UP (switches are ON).
      // Check if they require IP configuration and are actually configured.
      final aNeedsIp = !deviceA.type.canSwitch;
      final bNeedsIp = !deviceB.type.canSwitch;

      final aConfigured = !aNeedsIp || (ifaceA != null && ifaceA.isConfigured);
      final bConfigured = !bNeedsIp || (ifaceB != null && ifaceB.isConfigured);

      if (aConfigured && bConfigured) {
        if (aNeedsIp && bNeedsIp) {
          // Both are Layer 3 devices, check if they are in the same subnet
          if (IpUtils.isInSameSubnet(
                ifaceA!.ipAddress,
                ifaceB!.ipAddress,
                ifaceA.subnetMask,
              ) &&
              IpUtils.isInSameSubnet(
                ifaceB.ipAddress,
                ifaceA.ipAddress,
                ifaceB.subnetMask,
              )) {
            lineColor = AppColors.connectionActive;
          } else {
            lineColor = AppColors.connectionUnconfigured;
          }
        } else {
          // One or both are Layer 2 devices (e.g., switches). Link is UP.
          lineColor = AppColors.connectionActive;
        }
      } else {
        lineColor = AppColors.connectionUnconfigured;
      }
    }

    // Draw glow for selected connections.
    if (isSelected) {
      final glowPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.2)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(start, end, glowPaint);
    }

    // Main line.
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = isSelected ? 3 : 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (conn.cableType == CableType.wireless) {
      _drawDashedLine(canvas, start, end, linePaint, dashWidth: 5, dashSpace: 5);
    } else if (conn.cableType == CableType.crossover) {
      _drawDashedLine(canvas, start, end, linePaint, dashWidth: 10, dashSpace: 5);
    } else if (conn.cableType == CableType.console) {
      // Override color for console cable
      linePaint.color = const Color(0xFF3B82F6); // console blue
      _drawBezierLine(canvas, start, end, linePaint);
    } else {
      // Straight-through
      canvas.drawLine(start, end, linePaint);
    }
    // Note: Endpoint dots are now handled entirely by DevicePainter
  }

  void _drawPendingConnection(Canvas canvas) {
    final sourceDevice = _findDevice(pendingFromDeviceId!);
    if (sourceDevice == null) return;

    final start = sourceDevice.position;
    final end = pendingEndPoint!;

    // Animated dashed line.
    final paint = Paint()
      ..color = (isDark ? AppColors.primaryCyan : AppColors.primaryTeal)
          .withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    _drawDashedLine(canvas, start, end, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint, {double dashWidth = 8.0, double dashSpace = 6.0}) {
    final direction = end - start;
    final distance = direction.distance;
    if (distance < 1) return;

    final normalized = direction / distance;

    double drawn = 0;
    bool drawing = true;

    while (drawn < distance) {
      final segmentLength = drawing ? dashWidth : dashSpace;
      final segmentEnd = (drawn + segmentLength).clamp(0.0, distance);

      if (drawing) {
        final p1 = start + normalized * drawn;
        final p2 = start + normalized * segmentEnd;
        canvas.drawLine(p1, p2, paint);
      }

      drawn += segmentLength;
      drawing = !drawing;
    }
  }

  void _drawBezierLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final path = Path();
    path.moveTo(start.dx, start.dy);
    
    // Add a curve to distinguish console cables
    final controlPoint1 = Offset(start.dx + (end.dx - start.dx) / 3, start.dy - 50);
    final controlPoint2 = Offset(start.dx + 2 * (end.dx - start.dx) / 3, end.dy + 50);
    
    path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  NetworkDevice? _findDevice(String id) {
    try {
      return devices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) {
    return true; // Connections change with device movement.
  }
}
