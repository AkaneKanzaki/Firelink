import '../core/enums/acl_enums.dart';
import '../core/utils/id_generator.dart';

/// Represents a single ACL rule for firewall/router packet filtering.
class AclRule {
  /// Unique identifier for this rule.
  final String id;

  /// Action to take when this rule matches: permit or deny.
  final AclAction action;

  /// Source IP address to match, or "any" to match all sources.
  final String sourceIp;

  /// Source wildcard mask (e.g., "0.0.0.255" matches a /24 subnet).
  /// Ignored when sourceIp is "any".
  final String sourceWildcard;

  /// Destination IP address to match, or "any" to match all destinations.
  final String destIp;

  /// Destination wildcard mask.
  /// Ignored when destIp is "any".
  final String destWildcard;

  /// Protocol to match.
  final AclProtocol protocol;

  /// Whether this rule is currently active.
  final bool isEnabled;

  const AclRule({
    required this.id,
    required this.action,
    this.sourceIp = 'any',
    this.sourceWildcard = '0.0.0.0',
    this.destIp = 'any',
    this.destWildcard = '0.0.0.0',
    this.protocol = AclProtocol.any,
    this.isEnabled = true,
  });

  /// Creates a new AclRule with a generated ID.
  factory AclRule.create({
    required AclAction action,
    String sourceIp = 'any',
    String sourceWildcard = '0.0.0.0',
    String destIp = 'any',
    String destWildcard = '0.0.0.0',
    AclProtocol protocol = AclProtocol.any,
    bool isEnabled = true,
  }) {
    return AclRule(
      id: IdGenerator.generatePacketId(),
      action: action,
      sourceIp: sourceIp,
      sourceWildcard: sourceWildcard,
      destIp: destIp,
      destWildcard: destWildcard,
      protocol: protocol,
      isEnabled: isEnabled,
    );
  }

  /// Checks if a packet with the given source/dest IP and protocol matches this rule.
  bool matches({
    required String packetSourceIp,
    required String packetDestIp,
    required AclProtocol packetProtocol,
  }) {
    if (!isEnabled) return false;

    // Check protocol
    if (protocol != AclProtocol.any && protocol != packetProtocol) {
      return false;
    }

    // Check source IP
    if (sourceIp != 'any') {
      if (!_matchesWithWildcard(packetSourceIp, sourceIp, sourceWildcard)) {
        return false;
      }
    }

    // Check destination IP
    if (destIp != 'any') {
      if (!_matchesWithWildcard(packetDestIp, destIp, destWildcard)) {
        return false;
      }
    }

    return true;
  }

  /// Checks if [ip] matches [ruleIp] given a [wildcard] mask.
  /// Wildcard mask: 0 bits = must match, 1 bits = don't care.
  /// E.g., wildcard "0.0.0.255" with ruleIp "192.168.1.0" matches any 192.168.1.x.
  bool _matchesWithWildcard(String ip, String ruleIp, String wildcard) {
    final ipParts = ip.split('.').map(int.tryParse).toList();
    final ruleParts = ruleIp.split('.').map(int.tryParse).toList();
    final wildcardParts = wildcard.split('.').map(int.tryParse).toList();

    if (ipParts.length != 4 ||
        ruleParts.length != 4 ||
        wildcardParts.length != 4) {
      return false;
    }

    for (int i = 0; i < 4; i++) {
      final ipOctet = ipParts[i];
      final ruleOctet = ruleParts[i];
      final wildcardOctet = wildcardParts[i];

      if (ipOctet == null || ruleOctet == null || wildcardOctet == null) {
        return false;
      }

      // Bits where wildcard is 0 must match.
      final mask = ~wildcardOctet & 0xFF;
      if ((ipOctet & mask) != (ruleOctet & mask)) {
        return false;
      }
    }

    return true;
  }

  AclRule copyWith({
    AclAction? action,
    String? sourceIp,
    String? sourceWildcard,
    String? destIp,
    String? destWildcard,
    AclProtocol? protocol,
    bool? isEnabled,
  }) {
    return AclRule(
      id: id,
      action: action ?? this.action,
      sourceIp: sourceIp ?? this.sourceIp,
      sourceWildcard: sourceWildcard ?? this.sourceWildcard,
      destIp: destIp ?? this.destIp,
      destWildcard: destWildcard ?? this.destWildcard,
      protocol: protocol ?? this.protocol,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.name,
      'sourceIp': sourceIp,
      'sourceWildcard': sourceWildcard,
      'destIp': destIp,
      'destWildcard': destWildcard,
      'protocol': protocol.name,
      'isEnabled': isEnabled,
    };
  }

  factory AclRule.fromJson(Map<String, dynamic> json) {
    return AclRule(
      id: json['id'] as String,
      action: AclAction.values.firstWhere((e) => e.name == json['action']),
      sourceIp: json['sourceIp'] as String? ?? 'any',
      sourceWildcard: json['sourceWildcard'] as String? ?? '0.0.0.0',
      destIp: json['destIp'] as String? ?? 'any',
      destWildcard: json['destWildcard'] as String? ?? '0.0.0.0',
      protocol: AclProtocol.values.firstWhere(
        (e) => e.name == json['protocol'],
        orElse: () => AclProtocol.any,
      ),
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    final src = sourceIp == 'any' ? 'any' : '$sourceIp/$sourceWildcard';
    final dst = destIp == 'any' ? 'any' : '$destIp/$destWildcard';
    return '${action.displayName} $src → $dst (${protocol.displayName})';
  }
}
