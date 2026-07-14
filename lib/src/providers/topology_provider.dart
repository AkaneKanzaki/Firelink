import 'package:flutter/material.dart';
import '../core/enums/cable_type.dart';
import '../core/enums/device_type.dart';
import '../core/enums/interface_status.dart';
import '../core/utils/canvas_utils.dart';
import '../core/utils/id_generator.dart';
import '../core/utils/ip_utils.dart';
import '../models/connection.dart';
import '../models/device.dart';
import '../models/network_interface.dart';
import '../models/topology.dart';
import '../models/acl_rule.dart';
import '../models/tutorial_level.dart';
import '../services/tutorial_progress_service.dart';

/// Core state provider for the network topology: devices, connections, and selection.
class TopologyProvider extends ChangeNotifier {
  final List<NetworkDevice> _devices = [];
  final List<Connection> _connections = [];
  String? _selectedDeviceId;
  String? _selectedConnectionId;

  /// Used for connection mode: the first device tapped.
  String? _connectionSourceDeviceId;
  String? _connectionSourceInterfaceName;

  /// Used for Simple PDU mode.
  bool _isPduMode = false;

  /// Used for Complex PDU mode.
  bool _isComplexPduMode = false;

  String? _pduSourceDeviceId;

  /// Counters for auto-naming hostnames per type.
  final Map<DeviceType, int> _deviceCounters = {};

  // ─── Tutorial State ───────────────────────────────────────────
  TutorialLevel? _currentTutorial;
  int _currentTutorialStageIndex = 0;
  bool _tutorialCompleted = false;

  // ─── Getters ──────────────────────────────────────────────────

  List<NetworkDevice> get devices => List.unmodifiable(_devices);
  List<Connection> get connections => List.unmodifiable(_connections);

  TutorialLevel? get currentTutorial => _currentTutorial;
  int get currentTutorialStageIndex => _currentTutorialStageIndex;
  bool get tutorialCompleted => _tutorialCompleted;

  String? get selectedDeviceId => _selectedDeviceId;
  String? get selectedConnectionId => _selectedConnectionId;

  String? get connectionSourceDeviceId => _connectionSourceDeviceId;
  String? get connectionSourceInterfaceName => _connectionSourceInterfaceName;

  bool get isPduMode => _isPduMode;
  bool get isComplexPduMode => _isComplexPduMode;
  String? get pduSourceDeviceId => _pduSourceDeviceId;

  NetworkDevice? get selectedDevice {
    if (_selectedDeviceId == null) return null;
    try {
      return _devices.firstWhere((d) => d.id == _selectedDeviceId);
    } catch (_) {
      return null;
    }
  }

  Connection? get selectedConnection {
    if (_selectedConnectionId == null) return null;
    try {
      return _connections.firstWhere((c) => c.id == _selectedConnectionId);
    } catch (_) {
      return null;
    }
  }

  // ─── Device CRUD ──────────────────────────────────────────────

  /// Adds a new device of [type] at [position] on the canvas.
  NetworkDevice addDevice(DeviceType type, Offset position) {
    final count = _deviceCounters[type] ?? 0;
    _deviceCounters[type] = count + 1;

    final id = IdGenerator.generateDeviceId();
    final hostname = IdGenerator.generateHostname(type, count);
    final interfaceNames = IdGenerator.generateInterfaceNames(type);

    final interfaces = interfaceNames.map((name) {
      return NetworkInterface(
        name: name,
        macAddress: IpUtils.generateMacAddress(),
      );
    }).toList();

    final device = NetworkDevice(
      id: id,
      type: type,
      hostname: hostname,
      position: position,
      interfaces: interfaces,
    );

    _devices.add(device);
    _updateWirelessConnections();
    notifyListeners();
    checkTutorialCompletion();
    return device;
  }

  /// Removes the device with [deviceId] and all its connections.
  void removeDevice(String deviceId) {
    // Remove all connections involving this device.
    final connectionsToRemove = _connections
        .where((c) => c.involvesDevice(deviceId))
        .toList();

    for (final conn in connectionsToRemove) {
      _disconnectInterfaces(conn);
      _connections.remove(conn);
    }

    _devices.removeWhere((d) => d.id == deviceId);

    if (_selectedDeviceId == deviceId) {
      _selectedDeviceId = null;
    }

    notifyListeners();
  }

  /// Moves a device to a new position, optionally snapping to grid.
  void moveDevice(String deviceId, Offset newPosition, {bool snap = false}) {
    final device = _findDevice(deviceId);
    if (device == null) return;

    device.position = snap ? CanvasUtils.snapToGrid(newPosition) : newPosition;

    _updateWirelessConnections();
    notifyListeners();
    checkTutorialCompletion();
  }

  /// Updates the hostname of a device.
  void updateHostname(String deviceId, String hostname) {
    final device = _findDevice(deviceId);
    if (device == null) return;
    device.hostname = hostname;
    notifyListeners();
  }

  // ─── Interface Configuration ──────────────────────────────────

  /// Sets the IP address and subnet mask for an interface on a device.
  void configureInterface(
    String deviceId,
    String interfaceName, {
    String? ipAddress,
    String? subnetMask,
    String? defaultGateway,
    String? dnsServer,
    InterfaceStatus? status,
    bool? isDhcpClient,
  }) {
    final deviceIndex = _devices.indexWhere((d) => d.id == deviceId);
    if (deviceIndex == -1) return;

    final device = _devices[deviceIndex];
    final ifaceIndex = device.interfaces.indexWhere(
      (i) => i.name == interfaceName,
    );
    if (ifaceIndex == -1) return;

    final iface = device.interfaces[ifaceIndex];

    final updatedIface = iface.copyWith(
      ipAddress: ipAddress,
      subnetMask: subnetMask,
      defaultGateway: defaultGateway,
      dnsServer: dnsServer,
      status: status,
      isDhcpClient: isDhcpClient,
    );

    device.interfaces[ifaceIndex] = updatedIface;

    checkTutorialCompletion();
    notifyListeners();
  }

  // ─── Connection Management ────────────────────────────────────

  /// Starts connection mode from [deviceId].
  void startConnection(String deviceId, String interfaceName) {
    _connectionSourceDeviceId = deviceId;
    _connectionSourceInterfaceName = interfaceName;
    notifyListeners();
  }

  /// Cancels the current connection operation.
  void cancelConnection() {
    _connectionSourceDeviceId = null;
    _connectionSourceInterfaceName = null;
    _isPduMode = false;
    _isComplexPduMode = false;
    _pduSourceDeviceId = null;
    notifyListeners();
  }

  /// Attempts to connect two devices.
  /// Fails if an interface is unavailable.
  Connection? connectDevices(
    String deviceAId,
    String interfaceAName,
    String deviceBId,
    String interfaceBName, {
    CableType cableType = CableType.straight,
  }) {
    final deviceA = _findDevice(deviceAId);
    final deviceB = _findDevice(deviceBId);
    if (deviceA == null || deviceB == null) return null;

    // Check for existing connection between these devices.
    final existing = _connections.any(
      (c) => c.involvesDevice(deviceAId) && c.involvesDevice(deviceBId),
    );
    if (existing) return null;

    final ifaceA = deviceA.getInterface(interfaceAName);
    final ifaceB = deviceB.getInterface(interfaceBName);
    if (ifaceA == null ||
        ifaceB == null ||
        ifaceA.connectedToConnectionId != null ||
        ifaceB.connectedToConnectionId != null) {
      return null;
    }

    final connection = Connection(
      id: IdGenerator.generateConnectionId(),
      deviceAId: deviceAId,
      interfaceAName: ifaceA.name,
      deviceBId: deviceBId,
      interfaceBName: ifaceB.name,
      cableType: cableType,
    );

    // Mark interfaces as connected and turn them ON automatically.
    ifaceA.connectedToConnectionId = connection.id;
    ifaceA.status = InterfaceStatus.up;
    ifaceB.connectedToConnectionId = connection.id;
    ifaceB.status = InterfaceStatus.up;

    _connections.add(connection);
    _connectionSourceDeviceId = null;
    _connectionSourceInterfaceName = null;
    notifyListeners();
    checkTutorialCompletion();
    return connection;
  }

  /// Removes a connection by ID.
  void removeConnection(String connectionId) {
    final conn = _findConnection(connectionId);
    if (conn == null) return;

    _disconnectInterfaces(conn);
    _connections.remove(conn);

    if (_selectedConnectionId == connectionId) {
      _selectedConnectionId = null;
    }

    notifyListeners();
  }

  /// Clears all interface references when a connection is removed.
  void _disconnectInterfaces(Connection conn) {
    final deviceA = _findDevice(conn.deviceAId);
    final deviceB = _findDevice(conn.deviceBId);

    final ifaceA = deviceA?.getInterface(conn.interfaceAName);
    final ifaceB = deviceB?.getInterface(conn.interfaceBName);

    if (ifaceA != null) {
      ifaceA.connectedToConnectionId = null;
      ifaceA.status = InterfaceStatus.down;
    }
    if (ifaceB != null) {
      ifaceB.connectedToConnectionId = null;
      ifaceB.status = InterfaceStatus.down;
    }
  }

  // ─── Selection ────────────────────────────────────────────────

  void selectDevice(String? deviceId) {
    // Deselect previous.
    if (_selectedDeviceId != null) {
      _findDevice(_selectedDeviceId!)?.isSelected = false;
    }
    _selectedDeviceId = deviceId;
    _selectedConnectionId = null;
    if (deviceId != null) {
      _findDevice(deviceId)?.isSelected = true;
    }
    notifyListeners();
  }

  void selectConnection(String? connectionId) {
    _selectedConnectionId = connectionId;
    if (_selectedDeviceId != null) {
      _findDevice(_selectedDeviceId!)?.isSelected = false;
    }
    _selectedDeviceId = null;
    notifyListeners();
  }

  // ─── Simple PDU Mode ──────────────────────────────────────────

  void togglePduMode() {
    _isPduMode = !_isPduMode;
    if (_isPduMode) {
      _isComplexPduMode = false;
      _pduSourceDeviceId = null;
    }
    notifyListeners();
  }

  /// Toggles Complex PDU mode for custom packets (TCP/UDP/ICMP).
  void toggleComplexPduMode() {
    _isComplexPduMode = !_isComplexPduMode;
    if (_isComplexPduMode) {
      _isPduMode = false;
      _pduSourceDeviceId = null;
    }
    notifyListeners();
  }

  void setPduSourceDevice(String deviceId) {
    _pduSourceDeviceId = deviceId;
    notifyListeners();
  }

  void cancelPduMode() {
    _isPduMode = false;
    _pduSourceDeviceId = null;
    notifyListeners();
  }

  /// Cancels Complex PDU mode.
  void cancelComplexPduMode() {
    _isComplexPduMode = false;
    _pduSourceDeviceId = null;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedDeviceId != null) {
      _findDevice(_selectedDeviceId!)?.isSelected = false;
    }
    _selectedDeviceId = null;
    _selectedConnectionId = null;
    notifyListeners();
  }

  // ─── Hit Testing ──────────────────────────────────────────────

  /// Finds the device at the given canvas position, or null if none.
  NetworkDevice? hitTestDevice(Offset position) {
    // Reverse iteration to check devices painted on top first
    for (int i = _devices.length - 1; i >= 0; i--) {
      if (CanvasUtils.hitTest(position, _devices[i].position)) {
        return _devices[i];
      }
    }
    return null;
  }

  Connection? hitTestConnection(Offset position) {
    for (int i = _connections.length - 1; i >= 0; i--) {
      final conn = _connections[i];
      final deviceA = _findDevice(conn.deviceAId);
      final deviceB = _findDevice(conn.deviceBId);
      if (deviceA == null || deviceB == null) continue;

      final startPos = CanvasUtils.getInterfacePosition(
        deviceA,
        conn.interfaceAName,
      );
      final endPos = CanvasUtils.getInterfacePosition(
        deviceB,
        conn.interfaceBName,
      );

      if (CanvasUtils.hitTestLine(position, startPos, endPos)) {
        return conn;
      }
    }
    return null;
  }

  // ─── Topology Operations ──────────────────────────────────────

  /// Clears the entire topology.
  void clearTopology() {
    _devices.clear();
    _connections.clear();
    _selectedDeviceId = null;
    _selectedConnectionId = null;
    _connectionSourceDeviceId = null;
    _deviceCounters.clear();
    notifyListeners();
  }

  /// Returns the device at the other end of a connection from [deviceId].
  NetworkDevice? getConnectedDevice(String deviceId, Connection connection) {
    final otherId = connection.getOtherDeviceId(deviceId);
    return _findDevice(otherId);
  }

  /// Returns all connections involving the given device.
  List<Connection> getDeviceConnections(String deviceId) {
    return _connections.where((c) => c.involvesDevice(deviceId)).toList();
  }

  /// Find a device by IP address (searches all interfaces).
  NetworkDevice? findDeviceByIp(String ip) {
    for (final device in _devices) {
      for (final iface in device.interfaces) {
        if (iface.ipAddress == ip) return device;
      }
    }
    return null;
  }

  // ─── Persistence (Save & Load) ────────────────────────────────

  /// Loads the entire topology from a Topology object.
  void loadFromTopology(Topology topology) {
    _devices.clear();
    _connections.clear();
    _selectedDeviceId = null;
    _selectedConnectionId = null;
    _connectionSourceDeviceId = null;
    _deviceCounters.clear();

    for (final device in topology.devices) {
      _devices.add(device);
      final currentCount = _deviceCounters[device.type] ?? 0;
      _deviceCounters[device.type] = currentCount + 1;
    }

    for (final conn in topology.connections) {
      _connections.add(conn);
    }

    notifyListeners();
  }

  // ─── Private Helpers ──────────────────────────────────────────

  NetworkDevice? _findDevice(String id) {
    try {
      return _devices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  Connection? _findConnection(String id) {
    try {
      return _connections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Automatically connects wireless devices within range and disconnects those out of range.
  void _updateWirelessConnections() {
    const double wirelessRadius = 250.0;

    // Separate devices into APs and Clients
    final aps = _devices
        .where(
          (d) =>
              d.type == DeviceType.accessPoint ||
              d.type == DeviceType.wirelessRouter,
        )
        .toList();

    final clients = _devices
        .where(
          (d) =>
              d.interfaces.any((i) => i.name.startsWith('Wlan')) &&
              d.type != DeviceType.accessPoint &&
              d.type != DeviceType.wirelessRouter,
        )
        .toList();

    // Remove wireless connections that are out of range
    final connectionsToRemove = <Connection>[];
    for (final conn in _connections.where(
      (c) => c.cableType == CableType.wireless,
    )) {
      final deviceA = _findDevice(conn.deviceAId);
      final deviceB = _findDevice(conn.deviceBId);

      if (deviceA == null || deviceB == null) {
        connectionsToRemove.add(conn);
        continue;
      }

      final distance = (deviceA.position - deviceB.position).distance;
      if (distance > wirelessRadius) {
        connectionsToRemove.add(conn);
      }
    }

    for (final conn in connectionsToRemove) {
      _disconnectInterfaces(conn);
      _connections.remove(conn);
    }

    // Attempt to connect disconnected clients to the nearest AP
    for (final client in clients) {
      final wlanIface = client.interfaces.firstWhere(
        (i) => i.name.startsWith('Wlan'),
      );
      if (wlanIface.isConnected) continue; // Already connected

      NetworkDevice? nearestAp;
      double minDistance = double.infinity;

      for (final ap in aps) {
        final distance = (client.position - ap.position).distance;
        if (distance <= wirelessRadius && distance < minDistance) {
          // Check if AP has an available Wlan port
          final availableApIface = ap.interfaces
              .cast<NetworkInterface?>()
              .firstWhere(
                (i) => i!.name.startsWith('Wlan') && !i.isConnected,
                orElse: () => null,
              );

          if (availableApIface != null) {
            nearestAp = ap;
            minDistance = distance;
          }
        }
      }

      if (nearestAp != null) {
        final apIface = nearestAp.interfaces.firstWhere(
          (i) => i.name.startsWith('Wlan') && !i.isConnected,
        );
        final connection = Connection(
          id: IdGenerator.generateConnectionId(),
          deviceAId: nearestAp.id,
          interfaceAName: apIface.name,
          deviceBId: client.id,
          interfaceBName: wlanIface.name,
          cableType: CableType.wireless,
        );

        apIface.connectedToConnectionId = connection.id;
        apIface.status = InterfaceStatus.up;
        wlanIface.connectedToConnectionId = connection.id;
        wlanIface.status = InterfaceStatus.up;
        _connections.add(connection);
      }
    }
  }

  // ─── ACL Operations ─────────────────────────────────────────────────────────

  void addAclRule(String deviceId, AclRule rule) {
    final device = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw Exception('Device not found'),
    );
    device.aclRules.add(rule);
    notifyListeners();
  }

  void removeAclRule(String deviceId, String ruleId) {
    final device = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw Exception('Device not found'),
    );
    device.aclRules.removeWhere((r) => r.id == ruleId);
    notifyListeners();
  }

  void updateAclRule(String deviceId, String ruleId, AclRule updatedRule) {
    final device = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw Exception('Device not found'),
    );
    final index = device.aclRules.indexWhere((r) => r.id == ruleId);
    if (index != -1) {
      device.aclRules[index] = updatedRule;
      notifyListeners();
    }
  }

  void reorderAclRules(String deviceId, int oldIndex, int newIndex) {
    final device = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw Exception('Device not found'),
    );
    // Note: newIndex is already adjusted by onReorderItem
    final rule = device.aclRules.removeAt(oldIndex);
    device.aclRules.insert(newIndex, rule);
    notifyListeners();
  }

  void toggleAclDefaultPolicy(String deviceId) {
    final device = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw Exception('Device not found'),
    );
    device.aclDefaultDeny = !device.aclDefaultDeny;
    notifyListeners();
  }

  // ─── Tutorial Methods ─────────────────────────────────────────

  void startTutorial(TutorialLevel level) {
    clearTopology();
    _currentTutorial = level;
    _currentTutorialStageIndex = 0;
    _tutorialCompleted = false;
    notifyListeners();
  }

  void exitTutorial() {
    _currentTutorial = null;
    _currentTutorialStageIndex = 0;
    _tutorialCompleted = false;
    clearTopology();
  }

  void checkTutorialCompletion() {
    if (_currentTutorial == null || _tutorialCompleted) return;

    final level = _currentTutorial!;
    if (_currentTutorialStageIndex >= level.stages.length) return;

    final currentStage = level.stages[_currentTutorialStageIndex];
    
    // Map of blueprint device ID to actual device ID
    final Map<String, String> mappedDevices = {};

    // 1. Check if all target devices for this stage are placed correctly
    for (final bpDevice in currentStage.targetDevices) {
      bool found = false;
      for (final actualDevice in _devices) {
        if (actualDevice.type == bpDevice.type) {
          // Check distance with 150px tolerance
          final distance = (actualDevice.position - bpDevice.position).distance;
          if (distance < 150.0) { 
            mappedDevices[bpDevice.id] = actualDevice.id;
            found = true;
            break;
          }
        }
      }
      if (!found) return; // A required device is missing or not placed correctly
    }

    // 2. Check if all target connections exist for this stage
    for (final bpConn in currentStage.targetConnections) {
      final actualFromId = mappedDevices[bpConn.fromDeviceId];
      final actualToId = mappedDevices[bpConn.toDeviceId];
      
      if (actualFromId == null || actualToId == null) return;

      bool connFound = false;
      for (final actualConn in _connections) {
        if (actualConn.cableType == bpConn.cableType) {
          if ((actualConn.deviceAId == actualFromId && actualConn.deviceBId == actualToId) ||
              (actualConn.deviceAId == actualToId && actualConn.deviceBId == actualFromId)) {
            connFound = true;
            break;
          }
        }
      }
      if (!connFound) return; // A required connection is missing or wrong cable
    }

    // If we reach here, all devices and connections for the current stage match!
    if (currentStage.extraValidation != null) {
      final Map<String, NetworkDevice> mappedDevicesObjects = {};
      for (var entry in mappedDevices.entries) {
        mappedDevicesObjects[entry.key] = _findDevice(entry.value)!;
      }
      if (!currentStage.extraValidation!(mappedDevicesObjects)) {
        return; // Validation failed
      }
    }

    _currentTutorialStageIndex++;

    if (_currentTutorialStageIndex >= level.stages.length) {
      _tutorialCompleted = true;
      
      // Unlock next level
      final allLevels = TutorialLevel.allLevels;
      final currentIndex = allLevels.indexWhere((l) => l.id == level.id);
      if (currentIndex != -1 && currentIndex + 1 < allLevels.length) {
        // We do this asynchronously, it's fine if it's fire-and-forget here
        _unlockNextLevel(currentIndex + 1);
      }
    }
    
    notifyListeners();
  }

  Future<void> _unlockNextLevel(int nextIndex) async {
    // Import will be added to the top
    await TutorialProgressService.unlockLevel(nextIndex);
  }
}
