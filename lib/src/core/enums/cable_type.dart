/// Types of network cables for connecting devices.
enum CableType {
  /// Straight-through cable: connects different device types (e.g., PC to Switch).
  straight,

  /// Crossover cable: connects same device types (e.g., PC to PC, Switch to Switch).
  crossover,

  /// Console cable: connects to device management port.
  console,

  /// Wireless connection: auto-connects devices over air.
  wireless,
}

extension CableTypeExtension on CableType {
  String get displayName {
    switch (this) {
      case CableType.straight:
        return 'Straight-Through';
      case CableType.crossover:
        return 'Crossover';
      case CableType.console:
        return 'Console';
      case CableType.wireless:
        return 'Wireless Signal';
    }
  }

  /// The color used to draw this cable type on the canvas.
  String get colorHex {
    switch (this) {
      case CableType.straight:
        return '#10B981'; // green
      case CableType.crossover:
        return '#F59E0B'; // amber
      case CableType.console:
        return '#3B82F6'; // blue
      case CableType.wireless:
        return '#38BDF8'; // light blue
    }
  }
}
