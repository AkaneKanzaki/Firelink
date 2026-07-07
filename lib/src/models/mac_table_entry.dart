/// Represents a single entry in a Layer 2 Switch's MAC address table.
class MacTableEntry {
  /// The MAC address learned by the switch.
  final String macAddress;

  /// The name of the interface/port on the switch where this MAC was seen.
  final String interfaceName;

  /// The timestamp when this MAC was last seen. Used for aging out old entries.
  final DateTime timestamp;

  MacTableEntry({
    required this.macAddress,
    required this.interfaceName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'macAddress': macAddress,
      'interfaceName': interfaceName,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MacTableEntry.fromJson(Map<String, dynamic> json) {
    return MacTableEntry(
      macAddress: json['macAddress'] as String,
      interfaceName: json['interfaceName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
