import '../core/enums/interface_status.dart';

/// Represents a single network interface (port) on a device.
class NetworkInterface {
  /// Interface name, e.g., "GigabitEthernet0/0", "Ethernet0".
  final String name;

  /// IPv4 address assigned to this interface, e.g., "192.168.1.1".
  String ipAddress;

  /// Subnet mask, e.g., "255.255.255.0".
  String subnetMask;

  /// MAC address (auto-generated), e.g., "AA:BB:CC:DD:EE:01".
  final String macAddress;

  /// Default gateway IP (only for end-devices like PC/Server).
  String? defaultGateway;

  /// DNS Server IP (only for end-devices).
  String? dnsServer;

  /// Current operational status of the interface.
  InterfaceStatus status;

  /// ID of the Connection using this interface, null if disconnected.
  String? connectedToConnectionId;

  /// Whether this interface requests IP configuration via DHCP.
  bool isDhcpClient;

  NetworkInterface({
    required this.name,
    this.ipAddress = '',
    this.subnetMask = '',
    required this.macAddress,
    this.defaultGateway,
    this.dnsServer,
    this.status = InterfaceStatus.down,
    this.connectedToConnectionId,
    this.isDhcpClient = false,
  });

  /// Whether this interface has a valid IP configuration.
  bool get isConfigured => ipAddress.isNotEmpty;

  /// Whether this interface is physically connected to another device.
  bool get isConnected => connectedToConnectionId != null;

  /// Creates a deep copy of this interface.
  NetworkInterface copyWith({
    String? name,
    String? ipAddress,
    String? subnetMask,
    String? macAddress,
    String? defaultGateway,
    String? dnsServer,
    InterfaceStatus? status,
    String? connectedToConnectionId,
    bool? isDhcpClient,
  }) {
    return NetworkInterface(
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      subnetMask: subnetMask ?? this.subnetMask,
      macAddress: macAddress ?? this.macAddress,
      defaultGateway: defaultGateway ?? this.defaultGateway,
      dnsServer: dnsServer ?? this.dnsServer,
      status: status ?? this.status,
      connectedToConnectionId:
          connectedToConnectionId ?? this.connectedToConnectionId,
      isDhcpClient: isDhcpClient ?? this.isDhcpClient,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ipAddress': ipAddress,
      'subnetMask': subnetMask,
      'macAddress': macAddress,
      'defaultGateway': defaultGateway,
      'dnsServer': dnsServer,
      'status': status.name,
      'connectedToConnectionId': connectedToConnectionId,
      'isDhcpClient': isDhcpClient,
    };
  }

  factory NetworkInterface.fromJson(Map<String, dynamic> json) {
    return NetworkInterface(
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String? ?? '',
      subnetMask: json['subnetMask'] as String? ?? '',
      macAddress: json['macAddress'] as String,
      defaultGateway: json['defaultGateway'] as String?,
      dnsServer: json['dnsServer'] as String?,
      status: InterfaceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InterfaceStatus.down,
      ),
      connectedToConnectionId: json['connectedToConnectionId'] as String?,
      isDhcpClient: json['isDhcpClient'] as bool? ?? false,
    );
  }
}
