import 'dart:ui';
import 'dart:math' as math;

import '../../models/device.dart';
import '../enums/device_type.dart';

/// Utility class for canvas coordinate operations.
class CanvasUtils {
  CanvasUtils._();

  /// Default grid cell size in logical pixels.
  static const double defaultGridSize = 40.0;

  /// Default device icon size (bounding box side length).
  static const double deviceSize = 72.0;

  /// Hit-test radius for tapping on a device.
  static const double hitTestRadius = 40.0;

  /// Minimum zoom scale.
  static const double minScale = 0.3;

  /// Maximum zoom scale.
  static const double maxScale = 3.0;

  /// Snaps the given [position] to the nearest grid intersection.
  static Offset snapToGrid(
    Offset position, [
    double gridSize = defaultGridSize,
  ]) {
    return Offset(
      (position.dx / gridSize).roundToDouble() * gridSize,
      (position.dy / gridSize).roundToDouble() * gridSize,
    );
  }

  /// Returns `true` if [tapPosition] is within [radius] of [deviceCenter].
  static bool hitTest(
    Offset tapPosition,
    Offset deviceCenter, [
    double radius = hitTestRadius,
  ]) {
    return (tapPosition - deviceCenter).distance <= radius;
  }

  /// Returns `true` if [tapPosition] is within [tolerance] distance from the line segment between [start] and [end].
  static bool hitTestLine(
    Offset tapPosition,
    Offset start,
    Offset end, [
    double tolerance = 15.0,
  ]) {
    final double l2 =
        (start.dx - end.dx) * (start.dx - end.dx) +
        (start.dy - end.dy) * (start.dy - end.dy);
    if (l2 == 0) return hitTest(tapPosition, start, tolerance);

    double t =
        ((tapPosition.dx - start.dx) * (end.dx - start.dx) +
            (tapPosition.dy - start.dy) * (end.dy - start.dy)) /
        l2;
    t = math.max(0, math.min(1, t));

    final projection = Offset(
      start.dx + t * (end.dx - start.dx),
      start.dy + t * (end.dy - start.dy),
    );
    return (tapPosition - projection).distance <= tolerance;
  }

  /// Calculates a point along a line between [from] and [to] at progress [t] (0.0–1.0).
  static Offset lerpAlongLine(Offset from, Offset to, double t) {
    return Offset.lerp(from, to, t)!;
  }

  /// Calculates the midpoint between two offsets (useful for connection labels).
  static Offset midpoint(Offset a, Offset b) {
    return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  }

  /// Clamps a scale value within the allowed zoom range.
  static double clampScale(double scale) {
    return scale.clamp(minScale, maxScale);
  }

  /// Calculates the exact coordinate where a cable should connect to a device
  /// based on its interface index. This ensures cables are drawn from the edge
  /// of the device icon rather than its center.
  static Offset getInterfacePosition(
    NetworkDevice device,
    String interfaceName,
  ) {
    final index = device.interfaces.indexWhere((i) => i.name == interfaceName);
    if (index == -1) return device.position; // Fallback to center

    final count = device.interfaces.length;
    final angle = (index / count) * 2 * math.pi - math.pi / 2;

    final radius =
        device.type == DeviceType.switchDevice ||
            device.type == DeviceType.router
        ? 35.0
        : 25.0; // Device visual radius

    return Offset(
      device.position.dx + radius * math.cos(angle),
      device.position.dy + radius * math.sin(angle),
    );
  }
}
