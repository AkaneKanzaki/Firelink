import 'dart:ui';
import '../core/enums/device_type.dart';
import '../core/enums/cable_type.dart';
import 'device.dart';

/// Represents a device in a tutorial blueprint.
class BlueprintDevice {
  final String id;
  final DeviceType type;
  final Offset position;

  BlueprintDevice({
    required this.id,
    required this.type,
    required this.position,
  });
}

/// Represents a required connection in a tutorial blueprint.
class BlueprintConnection {
  final String fromDeviceId;
  final String toDeviceId;
  final CableType cableType;

  BlueprintConnection({
    required this.fromDeviceId,
    required this.toDeviceId,
    required this.cableType,
  });
}

/// Defines a tutorial or practice level.
class TutorialStage {
  final String description;
  final List<BlueprintDevice> targetDevices;
  final List<BlueprintConnection> targetConnections;
  final bool Function(Map<String, NetworkDevice>)? extraValidation;

  TutorialStage({
    required this.description,
    this.targetDevices = const [],
    this.targetConnections = const [],
    this.extraValidation,
  });
}

class TutorialLevel {
  final String id;
  final String title;
  final String description;
  final List<TutorialStage> stages;
  final List<BlueprintDevice> blueprintDevices;
  final List<BlueprintConnection> blueprintConnections;

  TutorialLevel({
    required this.id,
    required this.title,
    required this.description,
    required this.stages,
    this.blueprintDevices = const [],
    this.blueprintConnections = const [],
  });

  /// List of all available tutorial levels.
  static List<TutorialLevel> get allLevels => [
        basicConnection(),
        switchConnection(),
        routerConnection(),
        basicIpConfig(),
        dhcpConfig(),
      ];

  /// Factory for Level 4 tutorial
  static TutorialLevel basicIpConfig() {
    final pc1 = BlueprintDevice(
      id: 'bp_ip_pc1',
      type: DeviceType.pc,
      position: const Offset(4960, 4160),
    );

    return TutorialLevel(
      id: 'level_4_basic_ip',
      title: 'Level 4: Basic IP Config',
      description: 'Learn how to configure an IP address on a PC.',
      stages: [
        TutorialStage(
          description: 'Step 1: Place a single PC on the workspace.',
          targetDevices: [pc1],
        ),
        TutorialStage(
          description: 'Step 2: Tap the PC, open its Interfaces, and set its IP address to 192.168.1.10',
          targetDevices: [pc1],
          extraValidation: (mappedDevices) {
            final pc = mappedDevices[pc1.id];
            if (pc == null) return false;
            // Check if any interface has IP 192.168.1.10
            return pc.interfaces.any((iface) => iface.ipAddress == '192.168.1.10');
          },
        ),
      ],
      blueprintDevices: [],
      blueprintConnections: [],
    );
  }

  /// Factory for Level 5 tutorial
  static TutorialLevel dhcpConfig() {
    final rt = BlueprintDevice(
      id: 'bp_dhcp_rt',
      type: DeviceType.router,
      position: const Offset(4960, 4080),
    );
    final pc = BlueprintDevice(
      id: 'bp_dhcp_pc',
      type: DeviceType.pc,
      position: const Offset(4960, 4240),
    );

    return TutorialLevel(
      id: 'level_5_dhcp',
      title: 'Level 5: DHCP Config',
      description: 'Learn how to enable a DHCP server on a Router and a DHCP client on a PC.',
      stages: [
        TutorialStage(
          description: 'Step 1: Place a Router and a PC, then connect them using a Crossover cable.',
          targetDevices: [rt, pc],
          targetConnections: [
            BlueprintConnection(
              fromDeviceId: rt.id,
              toDeviceId: pc.id,
              cableType: CableType.crossover,
            ),
          ],
        ),
        TutorialStage(
          description: 'Step 2: Configure the Router\'s interface (Tap Router -> Interfaces) and set IP to 192.168.1.1',
          targetDevices: [rt, pc],
          targetConnections: [
            BlueprintConnection(
              fromDeviceId: rt.id,
              toDeviceId: pc.id,
              cableType: CableType.crossover,
            ),
          ],
          extraValidation: (mappedDevices) {
            final router = mappedDevices[rt.id];
            if (router == null) return false;
            return router.interfaces.any((iface) => iface.ipAddress == '192.168.1.1');
          },
        ),
        TutorialStage(
          description: 'Step 3: Configure the Router to act as a DHCP server (Tap Router -> DHCP Server -> Enable).',
          targetDevices: [rt, pc],
          targetConnections: [
            BlueprintConnection(
              fromDeviceId: rt.id,
              toDeviceId: pc.id,
              cableType: CableType.crossover,
            ),
          ],
          extraValidation: (mappedDevices) {
            final router = mappedDevices[rt.id];
            if (router == null) return false;
            return router.interfaces.any((iface) => iface.ipAddress == '192.168.1.1') && 
                   (router.dhcpServerConfig?.isEnabled ?? false);
          },
        ),
        TutorialStage(
          description: 'Step 4: Enable DHCP Client on the PC (Tap PC -> Interfaces -> DHCP Client).',
          targetDevices: [rt, pc],
          targetConnections: [
            BlueprintConnection(
              fromDeviceId: rt.id,
              toDeviceId: pc.id,
              cableType: CableType.crossover,
            ),
          ],
          extraValidation: (mappedDevices) {
            final router = mappedDevices[rt.id];
            final client = mappedDevices[pc.id];
            if (router == null || client == null) return false;
            
            final routerDhcpEnabled = router.dhcpServerConfig?.isEnabled ?? false;
            final pcDhcpEnabled = client.interfaces.any((i) => i.isDhcpClient);
            
            return routerDhcpEnabled && pcDhcpEnabled;
          },
        ),
      ],
      blueprintDevices: [],
      blueprintConnections: [],
    );
  }

  /// Factory for a basic Level 1 tutorial
  static TutorialLevel basicConnection() {
    final pc1 = BlueprintDevice(
      id: 'bp_pc1',
      type: DeviceType.pc,
      position: const Offset(4800, 4160), // Multiples of 40 for perfect grid snap
    );
    final pc2 = BlueprintDevice(
      id: 'bp_pc2',
      type: DeviceType.pc,
      position: const Offset(5120, 4160), // Multiples of 40 for perfect grid snap
    );

    return TutorialLevel(
      id: 'level_1_basic',
      title: 'Level 1: Basic Connection',
      description: 'Learn how to add devices and connect them directly.',
      stages: [
        TutorialStage(
          description: 'Step 1: Drag and drop two PCs onto the glowing blueprints.',
          targetDevices: [pc1, pc2],
        ),
        TutorialStage(
          description: 'Step 2: Open the Cable Palette, select the Crossover cable, and connect the two PCs together.',
          targetDevices: [pc1, pc2],
          targetConnections: [
            BlueprintConnection(
              fromDeviceId: pc1.id,
              toDeviceId: pc2.id,
              cableType: CableType.crossover,
            ),
          ],
        ),
      ],
      blueprintDevices: [], // Kept for legacy compatibility, unused.
      blueprintConnections: [],
    );
  }

  /// Factory for Level 2 tutorial
  static TutorialLevel switchConnection() {
    final pc1 = BlueprintDevice(
      id: 'bp_sw_pc1',
      type: DeviceType.pc,
      position: const Offset(4760, 4280),
    );
    final sw = BlueprintDevice(
      id: 'bp_sw1',
      type: DeviceType.switchDevice,
      position: const Offset(4960, 4120),
    );
    final pc2 = BlueprintDevice(
      id: 'bp_sw_pc2',
      type: DeviceType.pc,
      position: const Offset(5160, 4280),
    );

    return TutorialLevel(
      id: 'level_2_switch',
      title: 'Level 2: Switch Connection',
      description: 'Learn how to connect multiple PCs using a Switch.',
      stages: [
        TutorialStage(
          description: 'Step 1: Place a Switch at the top, and two PCs below it.',
          targetDevices: [pc1, sw, pc2],
        ),
        TutorialStage(
          description: 'Step 2: Connect both PCs to the Switch using Straight-through cables.',
          targetDevices: [pc1, sw, pc2],
          targetConnections: [
            BlueprintConnection(
              fromDeviceId: pc1.id,
              toDeviceId: sw.id,
              cableType: CableType.straight,
            ),
            BlueprintConnection(
              fromDeviceId: pc2.id,
              toDeviceId: sw.id,
              cableType: CableType.straight,
            ),
          ],
        ),
      ],
      blueprintDevices: [],
      blueprintConnections: [],
    );
  }

  /// Factory for Level 3 tutorial
  static TutorialLevel routerConnection() {
    final rt = BlueprintDevice(
      id: 'bp_rt1',
      type: DeviceType.router,
      position: const Offset(4960, 4080),
    );
    final sw = BlueprintDevice(
      id: 'bp_rt_sw1',
      type: DeviceType.switchDevice,
      position: const Offset(4960, 4240),
    );
    final pc1 = BlueprintDevice(
      id: 'bp_rt_pc1',
      type: DeviceType.pc,
      position: const Offset(4960, 4400),
    );

    return TutorialLevel(
      id: 'level_3_router',
      title: 'Level 3: Router Connection',
      description: 'Learn how to connect a Router to a Switch and a PC.',
      stages: [
        TutorialStage(
          description: 'Step 1: Place a Router, a Switch, and a PC in a vertical line.',
          targetDevices: [rt, sw, pc1],
        ),
        TutorialStage(
          description: 'Step 2: Connect the PC to the Switch, and the Switch to the Router using Straight-through cables.',
          targetDevices: [rt, sw, pc1],
          targetConnections: [
            BlueprintConnection(
              fromDeviceId: pc1.id,
              toDeviceId: sw.id,
              cableType: CableType.straight,
            ),
            BlueprintConnection(
              fromDeviceId: sw.id,
              toDeviceId: rt.id,
              cableType: CableType.straight,
            ),
          ],
        ),
      ],
      blueprintDevices: [],
      blueprintConnections: [],
    );
  }
}
