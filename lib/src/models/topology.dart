import 'device.dart';
import 'connection.dart';

/// Represents a complete network topology that can be saved and loaded.
class Topology {
  /// Name of the topology project.
  String name;

  /// Optional description.
  String? description;

  /// When this topology was first created.
  final DateTime createdAt;

  /// When this topology was last modified.
  DateTime modifiedAt;

  /// All devices in the topology.
  final List<NetworkDevice> devices;

  /// All connections (cables) in the topology.
  final List<Connection> connections;

  Topology({
    required this.name,
    this.description,
    DateTime? createdAt,
    DateTime? modifiedAt,
    List<NetworkDevice>? devices,
    List<Connection>? connections,
  }) : createdAt = createdAt ?? DateTime.now(),
       modifiedAt = modifiedAt ?? DateTime.now(),
       devices = devices ?? [],
       connections = connections ?? [];

  /// File format version for forward compatibility.
  static const int fileVersion = 1;

  /// Total number of devices.
  int get deviceCount => devices.length;

  /// Total number of connections.
  int get connectionCount => connections.length;

  Map<String, dynamic> toJson() {
    return {
      'fileVersion': fileVersion,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': DateTime.now().toIso8601String(),
      'devices': devices.map((d) => d.toJson()).toList(),
      'connections': connections.map((c) => c.toJson()).toList(),
    };
  }

  factory Topology.fromJson(Map<String, dynamic> json) {
    return Topology(
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      devices: (json['devices'] as List<dynamic>)
          .map((d) => NetworkDevice.fromJson(d as Map<String, dynamic>))
          .toList(),
      connections: (json['connections'] as List<dynamic>)
          .map((c) => Connection.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
