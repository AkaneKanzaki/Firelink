import '../core/enums/device_type.dart';
import '../core/utils/ip_utils.dart';
import '../models/device.dart';
import '../models/connection.dart';

/// Validates the topology for common configuration errors.
class TopologyValidator {
  TopologyValidator._();

  /// Validates the entire topology and returns a list of warning/error messages.
  static List<ValidationMessage> validate(
    List<NetworkDevice> devices,
    List<Connection> connections,
  ) {
    final messages = <ValidationMessage>[];

    messages.addAll(_checkDuplicateIps(devices));
    messages.addAll(_checkUnconnectedDevices(devices, connections));
    messages.addAll(_checkSubnetMismatch(devices, connections));
    messages.addAll(_checkMissingGateway(devices));

    return messages;
  }

  /// Checks for duplicate IP addresses across all devices.
  static List<ValidationMessage> _checkDuplicateIps(
    List<NetworkDevice> devices,
  ) {
    final messages = <ValidationMessage>[];
    final ipMap = <String, List<String>>{}; // IP -> list of device hostnames

    for (final device in devices) {
      for (final iface in device.interfaces) {
        if (iface.ipAddress.isEmpty) continue;
        ipMap.putIfAbsent(iface.ipAddress, () => []).add(device.hostname);
      }
    }

    for (final entry in ipMap.entries) {
      if (entry.value.length > 1) {
        messages.add(
          ValidationMessage(
            type: ValidationMessageType.error,
            message:
                'Duplicate IP ${entry.key} found on: ${entry.value.join(", ")}',
          ),
        );
      }
    }

    return messages;
  }

  /// Checks for devices that are not connected to any other device.
  static List<ValidationMessage> _checkUnconnectedDevices(
    List<NetworkDevice> devices,
    List<Connection> connections,
  ) {
    final messages = <ValidationMessage>[];

    for (final device in devices) {
      final hasConnection = connections.any((c) => c.involvesDevice(device.id));
      if (!hasConnection) {
        messages.add(
          ValidationMessage(
            type: ValidationMessageType.warning,
            message: '${device.hostname} is not connected to any device.',
          ),
        );
      }
    }

    return messages;
  }

  /// Checks for subnet mismatches on directly connected interfaces.
  static List<ValidationMessage> _checkSubnetMismatch(
    List<NetworkDevice> devices,
    List<Connection> connections,
  ) {
    final messages = <ValidationMessage>[];

    for (final conn in connections) {
      final deviceA = devices.cast().firstWhere(
        (d) => d.id == conn.deviceAId,
        orElse: () => null,
      );
      final deviceB = devices.cast().firstWhere(
        (d) => d.id == conn.deviceBId,
        orElse: () => null,
      );

      if (deviceA == null || deviceB == null) continue;

      final ifaceA = deviceA.getInterface(conn.interfaceAName);
      final ifaceB = deviceB.getInterface(conn.interfaceBName);

      if (ifaceA == null || ifaceB == null) continue;
      if (ifaceA.ipAddress.isEmpty || ifaceB.ipAddress.isEmpty) continue;

      // Both interfaces should be in the same subnet.
      if (!IpUtils.isInSameSubnet(
        ifaceA.ipAddress,
        ifaceB.ipAddress,
        ifaceA.subnetMask,
      )) {
        messages.add(
          ValidationMessage(
            type: ValidationMessageType.error,
            message:
                '${deviceA.hostname}:${ifaceA.name} (${ifaceA.ipAddress}) and '
                '${deviceB.hostname}:${ifaceB.name} (${ifaceB.ipAddress}) are '
                'not in the same subnet.',
          ),
        );
      }
    }

    return messages;
  }

  /// Checks for end devices missing a default gateway.
  static List<ValidationMessage> _checkMissingGateway(
    List<NetworkDevice> devices,
  ) {
    final messages = <ValidationMessage>[];

    for (final device in devices) {
      if (device.type.canRoute || device.type.canSwitch) continue;

      for (final iface in device.interfaces) {
        if (iface.ipAddress.isNotEmpty &&
            (iface.defaultGateway == null || iface.defaultGateway!.isEmpty)) {
          messages.add(
            ValidationMessage(
              type: ValidationMessageType.warning,
              message:
                  '${device.hostname}:${iface.name} has no default gateway configured.',
            ),
          );
        }
      }
    }

    return messages;
  }
}

enum ValidationMessageType { error, warning, info }

class ValidationMessage {
  final ValidationMessageType type;
  final String message;

  const ValidationMessage({required this.type, required this.message});
}
