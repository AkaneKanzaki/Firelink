/// Configuration for a DHCP Server running on a router or server device.
class DhcpServerConfig {
  bool isEnabled;
  String poolStartIp;
  String poolEndIp;
  String subnetMask;
  String defaultGateway;
  String dnsServer;

  /// Map of MAC address to leased IP address.
  Map<String, String> leasedIps;

  DhcpServerConfig({
    this.isEnabled = false,
    this.poolStartIp = '',
    this.poolEndIp = '',
    this.subnetMask = '',
    this.defaultGateway = '',
    this.dnsServer = '',
    Map<String, String>? leasedIps,
  }) : leasedIps = leasedIps ?? {};

  /// Allocates the next available IP in the pool for the given MAC address.
  /// If the MAC address already has a leased IP, returns that IP.
  /// Returns null if the pool is exhausted.
  String? allocateNextIp(String macAddress) {
    if (!isEnabled) return null;

    if (leasedIps.containsKey(macAddress)) {
      return leasedIps[macAddress];
    }

    try {
      final start = _ipToLong(poolStartIp);
      final end = _ipToLong(poolEndIp);

      for (var i = start; i <= end; i++) {
        final ip = _longToIp(i);
        if (!leasedIps.containsValue(ip) && ip != defaultGateway) {
          leasedIps[macAddress] = ip;
          return ip;
        }
      }
    } catch (e) {
      // Handle invalid IP formats
    }

    return null; // Pool exhausted or invalid configuration
  }

  /// Converts an IPv4 string to a 32-bit integer.
  int _ipToLong(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) throw const FormatException('Invalid IPv4');
    return (int.parse(parts[0]) << 24) +
        (int.parse(parts[1]) << 16) +
        (int.parse(parts[2]) << 8) +
        int.parse(parts[3]);
  }

  /// Converts a 32-bit integer back to an IPv4 string.
  String _longToIp(int long) {
    return '${(long >> 24) & 255}.${(long >> 16) & 255}.${(long >> 8) & 255}.${long & 255}';
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'poolStartIp': poolStartIp,
      'poolEndIp': poolEndIp,
      'subnetMask': subnetMask,
      'defaultGateway': defaultGateway,
      'dnsServer': dnsServer,
      'leasedIps': leasedIps,
    };
  }

  factory DhcpServerConfig.fromJson(Map<String, dynamic> json) {
    return DhcpServerConfig(
      isEnabled: json['isEnabled'] as bool? ?? false,
      poolStartIp: json['poolStartIp'] as String? ?? '',
      poolEndIp: json['poolEndIp'] as String? ?? '',
      subnetMask: json['subnetMask'] as String? ?? '',
      defaultGateway: json['defaultGateway'] as String? ?? '',
      dnsServer: json['dnsServer'] as String? ?? '',
      leasedIps:
          (json['leasedIps'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          {},
    );
  }
}
