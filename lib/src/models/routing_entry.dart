/// Represents a single static routing table entry.
class RoutingEntry {
  /// Destination network address, e.g., "192.168.2.0".
  final String destination;

  /// Subnet mask for the destination, e.g., "255.255.255.0".
  final String subnetMask;

  /// Next-hop IP address for reaching the destination.
  final String nextHop;

  /// Name of the exit interface, e.g., "GigabitEthernet0/0".
  final String exitInterface;

  const RoutingEntry({
    required this.destination,
    required this.subnetMask,
    required this.nextHop,
    required this.exitInterface,
  });

  RoutingEntry copyWith({
    String? destination,
    String? subnetMask,
    String? nextHop,
    String? exitInterface,
  }) {
    return RoutingEntry(
      destination: destination ?? this.destination,
      subnetMask: subnetMask ?? this.subnetMask,
      nextHop: nextHop ?? this.nextHop,
      exitInterface: exitInterface ?? this.exitInterface,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'destination': destination,
      'subnetMask': subnetMask,
      'nextHop': nextHop,
      'exitInterface': exitInterface,
    };
  }

  factory RoutingEntry.fromJson(Map<String, dynamic> json) {
    return RoutingEntry(
      destination: json['destination'] as String,
      subnetMask: json['subnetMask'] as String,
      nextHop: json['nextHop'] as String,
      exitInterface: json['exitInterface'] as String,
    );
  }
}
