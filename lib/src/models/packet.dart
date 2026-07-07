import '../core/enums/packet_type.dart';

/// Represents a network packet traveling through the topology during simulation.
class Packet {
  /// Unique identifier for this packet.
  final String id;

  /// The type of packet (ICMP, ARP, etc.).
  final PacketType type;

  /// Source IP address.
  final String sourceIp;

  /// Destination IP address.
  final String destIp;

  /// Source MAC address.
  final String sourceMac;

  /// Destination MAC address (may be broadcast "FF:FF:FF:FF:FF:FF" for ARP).
  String destMac;

  /// Time-to-live counter, decremented at each hop.
  int ttl;

  /// List of device IDs that this packet has traversed.
  final List<String> hops;

  /// Current status of the packet: null (in transit), "success", "timeout",
  /// "unreachable", "ttl_exceeded".
  String? status;

  /// Current position along the connection path (0.0 = source, 1.0 = destination).
  /// Used for animation.
  double animationProgress;

  /// The connection ID this packet is currently traveling on.
  String? currentConnectionId;

  Packet({
    required this.id,
    required this.type,
    required this.sourceIp,
    required this.destIp,
    required this.sourceMac,
    this.destMac = 'FF:FF:FF:FF:FF:FF',
    this.ttl = 64,
    List<String>? hops,
    this.status,
    this.animationProgress = 0.0,
    this.currentConnectionId,
  }) : hops = hops ?? [];

  /// Whether this packet has completed its journey (success or failure).
  bool get isComplete => status != null;

  /// Add a hop to the packet's path.
  void addHop(String deviceId) {
    hops.add(deviceId);
    ttl--;
  }

  /// Create a deep copy snapshot of this packet.
  Packet copy() {
    return Packet(
      id: id,
      type: type,
      sourceIp: sourceIp,
      destIp: destIp,
      sourceMac: sourceMac,
      destMac: destMac,
      ttl: ttl,
      hops: List.from(hops),
      status: status,
      animationProgress: animationProgress,
      currentConnectionId: currentConnectionId,
    );
  }

  /// Whether TTL has expired.
  bool get isTtlExpired => ttl <= 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'sourceIp': sourceIp,
      'destIp': destIp,
      'sourceMac': sourceMac,
      'destMac': destMac,
      'ttl': ttl,
      'hops': hops,
      'status': status,
    };
  }
}
