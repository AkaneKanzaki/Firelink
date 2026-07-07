/// Status of a network interface on a device.
enum InterfaceStatus {
  /// Interface is active and operational.
  up,

  /// Interface is administratively up but link is down (no cable connected).
  down,

  /// Interface is administratively disabled.
  disabled,
}

extension InterfaceStatusExtension on InterfaceStatus {
  String get displayName {
    switch (this) {
      case InterfaceStatus.up:
        return 'Up';
      case InterfaceStatus.down:
        return 'Down';
      case InterfaceStatus.disabled:
        return 'Disabled';
    }
  }

  String get cliStatus {
    switch (this) {
      case InterfaceStatus.up:
        return 'up';
      case InterfaceStatus.down:
        return 'down';
      case InterfaceStatus.disabled:
        return 'administratively down';
    }
  }
}
