/// State of a physical or logical connection (cable) between two devices.
enum ConnectionState {
  /// Both sides are configured and link is fully operational (Green)
  connected,

  /// Physical connection exists but configuration is missing or incomplete (Orange)
  unconfigured,

  /// Link is down or administratively disabled (Red)
  disconnected,
}

extension ConnectionStateExtension on ConnectionState {
  String get displayName {
    switch (this) {
      case ConnectionState.connected:
        return 'Connected';
      case ConnectionState.unconfigured:
        return 'Unconfigured';
      case ConnectionState.disconnected:
        return 'Disconnected';
    }
  }
}
