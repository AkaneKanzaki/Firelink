/// Types of network devices available in Firelink.
enum DeviceType {
  router,
  switchDevice,
  hub,
  pc,
  server,
  laptop,
  isp,
  smartphone,
  accessPoint,
  wirelessRouter,
  printer,
  ipPhone,
  firewall,
}

extension DeviceTypeExtension on DeviceType {
  String get displayName {
    switch (this) {
      case DeviceType.router:
        return 'Router';
      case DeviceType.switchDevice:
        return 'Switch';
      case DeviceType.hub:
        return 'Hub';
      case DeviceType.pc:
        return 'PC';
      case DeviceType.server:
        return 'Server';
      case DeviceType.laptop:
        return 'Laptop';
      case DeviceType.isp:
        return 'ISP / Cloud';
      case DeviceType.smartphone:
        return 'Smartphone';
      case DeviceType.accessPoint:
        return 'Access Point';
      case DeviceType.wirelessRouter:
        return 'Wireless Router';
      case DeviceType.printer:
        return 'Printer';
      case DeviceType.ipPhone:
        return 'IP Phone';
      case DeviceType.firewall:
        return 'Firewall';
    }
  }

  String get hostnamePrefix {
    switch (this) {
      case DeviceType.router:
        return 'Router';
      case DeviceType.switchDevice:
        return 'Switch';
      case DeviceType.hub:
        return 'Hub';
      case DeviceType.pc:
        return 'PC';
      case DeviceType.server:
        return 'Server';
      case DeviceType.laptop:
        return 'Laptop';
      case DeviceType.isp:
        return 'Cloud';
      case DeviceType.smartphone:
        return 'Phone';
      case DeviceType.accessPoint:
        return 'AP';
      case DeviceType.wirelessRouter:
        return 'W-Router';
      case DeviceType.printer:
        return 'Printer';
      case DeviceType.ipPhone:
        return 'IP-Phone';
      case DeviceType.firewall:
        return 'FW';
    }
  }

  /// Number of network interfaces available for this device type.
  int get defaultPortCount {
    switch (this) {
      case DeviceType.router:
        return 4;
      case DeviceType.switchDevice:
        return 24;
      case DeviceType.hub:
        return 8;
      case DeviceType.pc:
        return 1;
      case DeviceType.server:
        return 2;
      case DeviceType.laptop:
        return 1;
      case DeviceType.isp:
        return 1; // logical connection to ISP
      case DeviceType.smartphone:
        return 1; // wireless interface
      case DeviceType.accessPoint:
        return 4; // 1 wired, 3 wireless or mixed
      case DeviceType.wirelessRouter:
        return 5; // 4 LAN, 1 WAN, (and wireless implied)
      case DeviceType.printer:
        return 1;
      case DeviceType.ipPhone:
        return 2; // PC port and switch port
      case DeviceType.firewall:
        return 4;
    }
  }

  /// Interface naming prefix (Cisco-style).
  String get interfacePrefix {
    switch (this) {
      case DeviceType.router:
      case DeviceType.firewall:
        return 'GigabitEthernet';
      case DeviceType.switchDevice:
      case DeviceType.hub:
      case DeviceType.ipPhone:
        return 'FastEthernet';
      case DeviceType.pc:
      case DeviceType.laptop:
      case DeviceType.server:
      case DeviceType.printer:
        return 'Ethernet';
      case DeviceType.isp:
        return 'Serial';
      case DeviceType.smartphone:
      case DeviceType.accessPoint:
      case DeviceType.wirelessRouter:
        return 'Wlan';
    }
  }

  /// Whether this device can perform routing (Layer 3).
  bool get canRoute {
    return this == DeviceType.router ||
        this == DeviceType.wirelessRouter ||
        this == DeviceType.firewall ||
        this == DeviceType.isp;
  }

  /// Whether this device can perform switching (Layer 2).
  bool get canSwitch {
    return this == DeviceType.switchDevice ||
        this == DeviceType.hub ||
        this == DeviceType.accessPoint ||
        this == DeviceType.wirelessRouter;
  }

  /// Whether this device supports DHCP Server service.
  bool get supportsDhcp {
    return this == DeviceType.server ||
        this == DeviceType.router ||
        this == DeviceType.wirelessRouter ||
        this == DeviceType.isp;
  }

  /// Whether this device supports Access Control List (ACL) service.
  bool get supportsAcl {
    return this == DeviceType.router ||
        this == DeviceType.firewall ||
        this == DeviceType.wirelessRouter ||
        this == DeviceType.isp;
  }

  /// Whether this device has any configurable services.
  bool get hasServices => supportsDhcp || supportsAcl;

  /// Whether this device is strictly Layer 2 (no IP configuration per interface).
  bool get isLayer2Only {
    return this == DeviceType.switchDevice ||
        this == DeviceType.hub ||
        this == DeviceType.accessPoint;
  }

  /// Whether this device is an end-device that typically requires a default gateway.
  bool get requiresDefaultGateway {
    return this == DeviceType.pc ||
        this == DeviceType.laptop ||
        this == DeviceType.server ||
        this == DeviceType.smartphone ||
        this == DeviceType.printer ||
        this == DeviceType.ipPhone ||
        this == DeviceType.wirelessRouter ||
        this == DeviceType.isp;
  }

  /// Whether this device allows configuring a DNS server.
  bool get requiresDnsServer {
    return !isLayer2Only;
  }
}
