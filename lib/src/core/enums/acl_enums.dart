/// ACL (Access Control List) action types.
enum AclAction {
  /// Allow traffic through.
  permit,

  /// Block traffic.
  deny,
}

/// Network protocols for ACL matching.
enum AclProtocol {
  /// Match any protocol.
  any,

  /// ICMP (ping, traceroute).
  icmp,

  /// TCP (HTTP, HTTPS, SSH, etc.).
  tcp,

  /// UDP (DNS, DHCP, etc.).
  udp,
}

extension AclActionExtension on AclAction {
  String get displayName {
    switch (this) {
      case AclAction.permit:
        return 'PERMIT';
      case AclAction.deny:
        return 'DENY';
    }
  }
}

extension AclProtocolExtension on AclProtocol {
  String get displayName {
    switch (this) {
      case AclProtocol.any:
        return 'ANY';
      case AclProtocol.icmp:
        return 'ICMP';
      case AclProtocol.tcp:
        return 'TCP';
      case AclProtocol.udp:
        return 'UDP';
    }
  }
}
