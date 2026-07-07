import 'dart:ui';
import '../core/enums/device_type.dart';
import 'acl_rule.dart';
import 'dhcp_server_config.dart';
import 'mac_table_entry.dart';
import 'network_interface.dart';
import 'routing_entry.dart';

/// Represents a network device placed on the topology canvas.
class NetworkDevice {
  /// Unique identifier for this device.
  final String id;

  /// Type of network device.
  final DeviceType type;

  /// User-editable hostname, e.g., "Router0", "PC1".
  String hostname;

  /// Position on the canvas (top-left of icon bounding box).
  Offset position;

  /// List of network interfaces (ports) on this device.
  final List<NetworkInterface> interfaces;

  /// Routing table entries (only meaningful for routers).
  final List<RoutingEntry> routingTable;

  /// Whether this device is currently selected by the user.
  bool isSelected;

  /// Configuration for DHCP Server if this device acts as one.
  DhcpServerConfig? _dhcpServerConfig;

  DhcpServerConfig? get dhcpServerConfig {
    if (type.supportsDhcp && _dhcpServerConfig == null) {
      _dhcpServerConfig = DhcpServerConfig();
    }
    return _dhcpServerConfig;
  }

  set dhcpServerConfig(DhcpServerConfig? value) {
    _dhcpServerConfig = value;
  }

  /// MAC Address table (primarily for Switches).
  /// Maps a destination MAC Address to the interface name where it can be reached.
  final Map<String, MacTableEntry> macTable;

  /// ARP Cache (maps IP Address to MAC Address).
  final Map<String, String> arpCache;

  /// Access Control List rules (for Firewalls and Routers).
  final List<AclRule> aclRules;

  /// Default ACL policy: true = deny all unmatched, false = permit all unmatched.
  bool aclDefaultDeny;

  NetworkDevice({
    required this.id,
    required this.type,
    required this.hostname,
    required this.position,
    required this.interfaces,
    List<RoutingEntry>? routingTable,
    this.isSelected = false,
    this._dhcpServerConfig,
    Map<String, MacTableEntry>? macTable,
    Map<String, String>? arpCache,
    List<AclRule>? aclRules,
    this.aclDefaultDeny = false,
  }) : routingTable = routingTable ?? [],
       macTable = macTable ?? {},
       arpCache = arpCache ?? {},
       aclRules = aclRules ?? [] {
    // Getter handles lazy initialization
  }

  /// Returns the first available (unconnected) interface, or null if all are in use.
  NetworkInterface? get firstAvailableInterface {
    try {
      return interfaces.firstWhere((iface) => !iface.isConnected);
    } catch (_) {
      return null;
    }
  }

  /// Returns the interface with the given name, or null if not found.
  NetworkInterface? getInterface(String name) {
    try {
      return interfaces.firstWhere((iface) => iface.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Whether all interfaces on this device are connected.
  bool get allPortsUsed => interfaces.every((iface) => iface.isConnected);

  /// Number of connected interfaces.
  int get connectedPortCount =>
      interfaces.where((iface) => iface.isConnected).length;

  /// The bounding rectangle for this device on the canvas.
  Rect get bounds => Rect.fromCenter(center: position, width: 72, height: 72);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'hostname': hostname,
      'positionX': position.dx,
      'positionY': position.dy,
      'interfaces': interfaces.map((e) => e.toJson()).toList(),
      'routingTable': routingTable.map((e) => e.toJson()).toList(),
      'isSelected': isSelected,
      'dhcpServerConfig': dhcpServerConfig?.toJson(),
      'macTable': macTable.map((k, v) => MapEntry(k, v.toJson())),
      'arpCache': arpCache,
      'aclRules': aclRules.map((e) => e.toJson()).toList(),
      'aclDefaultDeny': aclDefaultDeny,
    };
  }

  factory NetworkDevice.fromJson(Map<String, dynamic> json) {
    return NetworkDevice(
      id: json['id'] as String,
      type: DeviceType.values.firstWhere((e) => e.name == json['type']),
      hostname: json['hostname'] as String,
      position: Offset(
        (json['positionX'] as num).toDouble(),
        (json['positionY'] as num).toDouble(),
      ),
      interfaces: (json['interfaces'] as List<dynamic>)
          .map((e) => NetworkInterface.fromJson(e as Map<String, dynamic>))
          .toList(),
      routingTable:
          (json['routingTable'] as List<dynamic>?)
              ?.map((e) => RoutingEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isSelected: json['isSelected'] as bool? ?? false,
      dhcpServerConfig: json['dhcpServerConfig'] != null
          ? DhcpServerConfig.fromJson(
              json['dhcpServerConfig'] as Map<String, dynamic>,
            )
          : null,
      macTable: (json['macTable'] as Map<String, dynamic>?)?.map(
        (k, v) =>
            MapEntry(k, MacTableEntry.fromJson(v as Map<String, dynamic>)),
      ),
      arpCache: (json['arpCache'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as String),
      ),
      aclRules:
          (json['aclRules'] as List<dynamic>?)
              ?.map((e) => AclRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      aclDefaultDeny: json['aclDefaultDeny'] as bool? ?? false,
    );
  }
}
