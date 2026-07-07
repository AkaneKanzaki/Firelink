import '../core/enums/cable_type.dart';
import '../core/enums/connection_state.dart';

/// Represents a physical connection (cable) between two device interfaces.
class Connection {
  /// Unique identifier for this connection.
  final String id;

  /// ID of the first connected device.
  final String deviceAId;

  /// Name of the interface on device A used by this connection.
  final String interfaceAName;

  /// ID of the second connected device.
  final String deviceBId;

  /// Name of the interface on device B used by this connection.
  final String interfaceBName;

  /// Type of cable used.
  final CableType cableType;

  /// Current state of the connection
  ConnectionState state;

  Connection({
    required this.id,
    required this.deviceAId,
    required this.interfaceAName,
    required this.deviceBId,
    required this.interfaceBName,
    this.cableType = CableType.straight,
    this.state = ConnectionState.unconfigured,
  });

  /// Check if this connection involves the given device.
  bool involvesDevice(String deviceId) {
    return deviceAId == deviceId || deviceBId == deviceId;
  }

  /// Get the other device ID in this connection.
  String getOtherDeviceId(String deviceId) {
    return deviceAId == deviceId ? deviceBId : deviceAId;
  }

  /// Get the interface name on the other device in this connection.
  String getOtherInterfaceName(String deviceId) {
    return deviceAId == deviceId ? interfaceBName : interfaceAName;
  }

  /// Get the interface name on the given device in this connection.
  String getInterfaceName(String deviceId) {
    return deviceAId == deviceId ? interfaceAName : interfaceBName;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceAId': deviceAId,
      'interfaceAName': interfaceAName,
      'deviceBId': deviceBId,
      'interfaceBName': interfaceBName,
      'cableType': cableType.name,
      'state': state.name,
    };
  }

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'] as String,
      deviceAId: json['deviceAId'] as String,
      interfaceAName: json['interfaceAName'] as String,
      deviceBId: json['deviceBId'] as String,
      interfaceBName: json['interfaceBName'] as String,
      cableType: CableType.values.firstWhere(
        (e) => e.name == json['cableType'],
        orElse: () => CableType.straight,
      ),
      state: ConnectionState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => ConnectionState.unconfigured,
      ),
    );
  }
}
