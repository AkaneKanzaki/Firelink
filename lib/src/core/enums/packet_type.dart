/// Types of network packets used in simulation.
enum PacketType {
  /// ICMP Echo Request (ping).
  icmpEcho,

  /// ICMP Echo Reply.
  icmpReply,

  /// ARP Request — resolving IP to MAC address.
  arp,

  /// ARP Reply — response with MAC address.
  arpReply,

  /// ICMP Destination Unreachable.
  icmpUnreachable,

  /// ICMP Time Exceeded (TTL expired).
  icmpTimeExceeded,

  /// DHCP Discover - Broadcast to find DHCP Server.
  dhcpDiscover,

  /// DHCP Offer - Response from DHCP Server with IP.
  dhcpOffer,

  /// Packet blocked by ACL firewall rule.
  aclBlocked,

  /// TCP Segment.
  tcp,

  /// UDP Datagram.
  udp,
}

extension PacketTypeExtension on PacketType {
  String get displayName {
    switch (this) {
      case PacketType.icmpEcho:
        return 'ICMP Echo Request';
      case PacketType.icmpReply:
        return 'ICMP Echo Reply';
      case PacketType.arp:
        return 'ARP Request';
      case PacketType.arpReply:
        return 'ARP Reply';
      case PacketType.icmpUnreachable:
        return 'ICMP Unreachable';
      case PacketType.icmpTimeExceeded:
        return 'ICMP Time Exceeded';
      case PacketType.dhcpDiscover:
        return 'DHCP Discover';
      case PacketType.dhcpOffer:
        return 'DHCP Offer';
      case PacketType.aclBlocked:
        return 'ACL Blocked';
      case PacketType.tcp:
        return 'TCP Segment';
      case PacketType.udp:
        return 'UDP Datagram';
    }
  }

  /// Color hex for rendering the packet on canvas.
  String get colorHex {
    switch (this) {
      case PacketType.icmpEcho:
      case PacketType.icmpReply:
        return '#00D4AA'; // cyan-teal
      case PacketType.arp:
      case PacketType.arpReply:
        return '#F59E0B'; // amber
      case PacketType.icmpUnreachable:
      case PacketType.icmpTimeExceeded:
        return '#EF4444'; // red
      case PacketType.dhcpDiscover:
      case PacketType.dhcpOffer:
        return '#3B82F6'; // blue
      case PacketType.aclBlocked:
        return '#DC2626'; // red
      case PacketType.tcp:
        return '#8B5CF6'; // violet
      case PacketType.udp:
        return '#10B981'; // emerald green
    }
  }
}
