import 'package:uuid/uuid.dart';

import '../enums/device_type.dart';

/// Generates unique identifiers for devices, connections, and packets.
class IdGenerator {
  IdGenerator._();

  static const _uuid = Uuid();

  /// Generates a unique device ID.
  static String generateDeviceId() => _uuid.v4();

  /// Generates a unique connection ID.
  static String generateConnectionId() => _uuid.v4();

  /// Generates a unique packet ID.
  static String generatePacketId() => _uuid.v4();

  /// Generates an auto-incrementing hostname based on device type and current count.
  ///
  /// Example: `generateHostname(DeviceType.router, 0)` → "Router0"
  static String generateHostname(DeviceType type, int index) {
    return '${type.hostnamePrefix}$index';
  }

  /// Generates interface names for a device type.
  ///
  /// Example for a router with 4 ports:
  /// ["GigabitEthernet0/0", "GigabitEthernet0/1", "GigabitEthernet0/2", "GigabitEthernet0/3"]
  static List<String> generateInterfaceNames(DeviceType type) {
    final prefix = type.interfacePrefix;
    final count = type.defaultPortCount;

    if (type == DeviceType.pc || type == DeviceType.laptop) {
      // End devices use simple naming: "Ethernet0"
      return List.generate(count, (i) => '$prefix$i');
    }

    if (type == DeviceType.accessPoint) {
      List<String> names = [];
      for (int i = 0; i < count; i++) {
        if (i == 0) {
          names.add('Wlan 0/$i');
        } else {
          names.add('FastEthernet 0/$i');
        }
      }
      return names;
    }

    if (type == DeviceType.wirelessRouter) {
      List<String> names = [];
      for (int i = 0; i < count; i++) {
        if (i == 0) {
          names.add('Wlan 0/$i'); // wireless
        } else if (i == 1) {
          names.add('GigabitEthernet 0/WAN'); // WAN
        } else {
          names.add('FastEthernet 0/$i'); // LAN
        }
      }
      return names;
    }

    // Network devices use slot/port naming: "GigabitEthernet0/0"
    return List.generate(count, (i) => '$prefix 0/$i');
  }
}
