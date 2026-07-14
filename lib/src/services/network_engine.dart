import '../core/enums/acl_enums.dart';
import '../core/enums/cable_type.dart';
import '../core/enums/device_type.dart';
import '../core/enums/interface_status.dart';
import '../core/enums/packet_type.dart';
import '../core/utils/id_generator.dart';
import '../core/utils/ip_utils.dart';
import '../models/connection.dart';
import '../models/device.dart';
import '../models/mac_table_entry.dart';
import '../models/network_interface.dart';
import '../models/packet.dart';
import '../services/routing_service.dart';

/// Result of a simulation step.
class SimulationStep {
  final String deviceId;
  final String description;
  final Packet packet;
  final String? connectionId;
  final int tick;

  const SimulationStep({
    required this.deviceId,
    required this.description,
    required this.packet,
    this.connectionId,
    this.tick = 0,
  });
}

/// Result of a complete ping operation.
class PingResult {
  final bool success;
  final String sourceIp;
  final String destIp;
  final List<SimulationStep> steps;
  final List<String> consoleOutput;
  final int hops;

  const PingResult({
    required this.success,
    required this.sourceIp,
    required this.destIp,
    required this.steps,
    required this.consoleOutput,
    this.hops = 0,
  });
}

/// Result of a complete DHCP operation.
class DhcpResult {
  final bool success;
  final String? assignedIp;
  final String? subnetMask;
  final String? defaultGateway;
  final String? dnsServer;
  final List<SimulationStep> steps;
  final List<String> consoleOutput;

  const DhcpResult({
    required this.success,
    this.assignedIp,
    this.subnetMask,
    this.defaultGateway,
    this.dnsServer,
    required this.steps,
    required this.consoleOutput,
  });
}

/// Core network simulation engine.
///
/// Simulates packet routing through the topology step-by-step, including:
/// - Subnet checking
/// - ARP resolution (simplified)
/// - Static route lookup
/// - TTL decrementing
/// - Hop-by-hop forwarding
class NetworkEngine {
  final List<NetworkDevice> devices;
  final List<Connection> connections;

  NetworkEngine({required this.devices, required this.connections});

  /// Simulates an ICMP ping from [sourceDeviceId] to [destIp].
  PingResult simulatePing(String sourceDeviceId, String destIp) {
    final steps = <SimulationStep>[];
    final output = <String>[];

    final sourceDevice = _findDevice(sourceDeviceId);
    if (sourceDevice == null) {
      output.add('Error: Source device not found.');
      return PingResult(
        success: false,
        sourceIp: '',
        destIp: destIp,
        steps: steps,
        consoleOutput: output,
      );
    }

    NetworkInterface? sourceIface;

    // For routers, find the best interface based on the routing table.
    if (sourceDevice.type.canRoute) {
      final allRoutes = [
        ...RoutingService.generateConnectedRoutes(sourceDevice.interfaces),
        ...sourceDevice.routingTable,
      ];
      final route = RoutingService.lookupRoute(allRoutes, destIp);
      if (route != null) {
        sourceIface = sourceDevice.getInterface(route.exitInterface);
      }
    }

    // Fallback: pick the first configured interface.
    sourceIface ??= sourceDevice.interfaces.firstWhere(
      (i) => i.ipAddress.isNotEmpty,
      orElse: () => sourceDevice.interfaces.first,
    );

    if (sourceIface.ipAddress.isEmpty) {
      output.add('% No IP address configured on ${sourceDevice.hostname}.');
      return PingResult(
        success: false,
        sourceIp: '',
        destIp: destIp,
        steps: steps,
        consoleOutput: output,
      );
    }

    if (sourceIface.status != InterfaceStatus.up) {
      output.add('% Source interface is administratively down.');
      return PingResult(
        success: false,
        sourceIp: sourceIface.ipAddress,
        destIp: destIp,
        steps: steps,
        consoleOutput: output,
      );
    }

    output.add('Pinging $destIp from ${sourceIface.ipAddress}:');
    output.add('');

    // ─── ARP Resolution ─────────────────────────────────────────
    String targetIpForArp = destIp;

    if (!IpUtils.isInSameSubnet(
      sourceIface.ipAddress,
      destIp,
      sourceIface.subnetMask,
    )) {
      if (sourceIface.defaultGateway != null &&
          sourceIface.defaultGateway!.isNotEmpty) {
        targetIpForArp = sourceIface.defaultGateway!;
      } else {
        output.add('Destination not in same subnet and no gateway configured.');
        return PingResult(
          success: false,
          sourceIp: sourceIface.ipAddress,
          destIp: destIp,
          steps: steps,
          consoleOutput: output,
        );
      }
    }

    final targetDeviceForArp = _findDeviceByIp(targetIpForArp);
    String? resolvedMac = sourceDevice.arpCache[targetIpForArp];

    if (resolvedMac == null && targetDeviceForArp != null) {
      final targetIfaceForArp = targetDeviceForArp.interfaces.firstWhere(
        (i) => i.ipAddress == targetIpForArp,
        orElse: () => targetDeviceForArp.interfaces.first,
      );

      output.add(
        '  [${sourceDevice.hostname}] Broadcasting ARP Request for $targetIpForArp...',
      );
      final arpRequest = Packet(
        id: IdGenerator.generatePacketId(),
        type: PacketType.arp,
        sourceIp: sourceIface.ipAddress,
        destIp: targetIpForArp,
        sourceMac: sourceIface.macAddress,
        destMac: 'FF:FF:FF:FF:FF:FF',
      );

      int currentTick = steps.isEmpty
          ? 0
          : steps.fold<int>(
                  0,
                  (max, step) => step.tick > max ? step.tick : max,
                ) +
                1;

      final arpResult = _routePacket(
        packet: arpRequest,
        currentDevice: sourceDevice,
        currentInterface: sourceIface,
        steps: steps,
        output: output,
        tick: currentTick,
      );

      if (arpResult) {
        resolvedMac = targetIfaceForArp.macAddress;
        sourceDevice.arpCache[targetIpForArp] =
            resolvedMac; // Store in ARP cache!

        output.add(
          '  [${targetDeviceForArp.hostname}] Sending ARP Reply to ${sourceIface.macAddress} (Unicast)...',
        );

        final arpReply = Packet(
          id: IdGenerator.generatePacketId(),
          type: PacketType.arpReply,
          sourceIp: targetIpForArp,
          destIp: sourceIface.ipAddress,
          sourceMac: resolvedMac,
          destMac: sourceIface.macAddress,
        );

        currentTick = steps.isEmpty
            ? 0
            : steps.fold<int>(
                    0,
                    (max, step) => step.tick > max ? step.tick : max,
                  ) +
                  1;

        _routePacket(
          packet: arpReply,
          currentDevice: targetDeviceForArp,
          currentInterface: targetIfaceForArp,
          steps: steps,
          output: output,
          tick: currentTick,
        );
      }
    } else if (resolvedMac != null) {
      output.add(
        '  [${sourceDevice.hostname}] MAC for $targetIpForArp found in ARP Cache.',
      );
    }

    if (resolvedMac == null) {
      output.add('  [${sourceDevice.hostname}] ARP Request timed out.');
      output.add('Request timed out.');
      return PingResult(
        success: false,
        sourceIp: sourceIface.ipAddress,
        destIp: destIp,
        steps: steps,
        consoleOutput: output,
      );
    }

    output.add('');
    output.add(
      '  [${sourceDevice.hostname}] ARP resolved! Target MAC is $resolvedMac.',
    );
    output.add('  [${sourceDevice.hostname}] Sending ICMP Ping (Unicast)...');

    // Create the ICMP packet.
    final packet = Packet(
      id: IdGenerator.generatePacketId(),
      type: PacketType.icmpEcho,
      sourceIp: sourceIface.ipAddress,
      destIp: destIp,
      sourceMac: sourceIface.macAddress,
      destMac: resolvedMac,
    );

    int currentTick = steps.isEmpty
        ? 0
        : steps.fold<int>(0, (max, step) => step.tick > max ? step.tick : max) +
              1;

    // ─── Route the ICMP packet ────────────────────────────────────
    final routeResult = _routePacket(
      packet: packet,
      currentDevice: sourceDevice,
      currentInterface: sourceIface,
      steps: steps,
      output: output,
      tick: currentTick,
    );

    final destDevice = _findDeviceByIp(destIp);

    if (routeResult && destDevice != null) {
      output.add(
        '  [${destDevice.hostname}] ICMP Echo received. Sending ICMP Echo Reply...',
      );

      final replyPacket = Packet(
        id: IdGenerator.generatePacketId(),
        type: PacketType.icmpReply,
        sourceIp: destIp,
        destIp: sourceIface.ipAddress,
        sourceMac: packet.destMac,
        destMac: packet.sourceMac,
      );

      final destIface = destDevice.interfaces.firstWhere(
        (i) => i.ipAddress == destIp,
      );

      int replyTick = steps.isEmpty
          ? 0
          : steps.fold<int>(
                  0,
                  (max, step) => step.tick > max ? step.tick : max,
                ) +
                1;

      final replyResult = _routePacket(
        packet: replyPacket,
        currentDevice: destDevice,
        currentInterface: destIface,
        steps: steps,
        output: output,
        tick: replyTick,
      );

      if (replyResult) {
        output.add(
          'Reply from $destIp: bytes=32 time<1ms TTL=${64 - packet.hops.length}',
        );
        output.add('');
        output.add('Ping statistics for $destIp:');
        output.add('    Packets: Sent = 1, Received = 1, Lost = 0 (0% loss)');
      } else {
        output.add('Reply timeout.');
        output.add('');
        output.add('Ping statistics for $destIp:');
        output.add('    Packets: Sent = 1, Received = 0, Lost = 1 (100% loss)');
      }
    } else {
      output.add('Request timed out.');
      output.add('');
      output.add('Ping statistics for $destIp:');
      output.add('    Packets: Sent = 1, Received = 0, Lost = 1 (100% loss)');
    }

    return PingResult(
      success: routeResult,
      sourceIp: sourceIface.ipAddress,
      destIp: destIp,
      steps: steps,
      consoleOutput: output,
      hops: packet.hops.length,
    );
  }

  /// Simulates sending a custom PDU (TCP/UDP/ICMP).
  PingResult simulateCustomPdu(
    String sourceDeviceId,
    String destIp,
    AclProtocol protocol,
  ) {
    if (protocol == AclProtocol.icmp || protocol == AclProtocol.any) {
      return simulatePing(sourceDeviceId, destIp);
    }

    final steps = <SimulationStep>[];
    final output = <String>[];
    final sourceDevice = _findDevice(sourceDeviceId);

    if (sourceDevice == null) {
      output.add('Source device not found.');
      return PingResult(
        success: false,
        sourceIp: '',
        destIp: destIp,
        steps: steps,
        consoleOutput: output,
      );
    }

    // Find the interface with an IP
    NetworkInterface? sourceIface;
    for (var i in sourceDevice.interfaces) {
      if (i.ipAddress.isNotEmpty) {
        sourceIface = i;
        break;
      }
    }

    if (sourceIface == null) {
      output.add(
        '  [${sourceDevice.hostname}] No IP configured. Cannot send packet.',
      );
      return PingResult(
        success: false,
        sourceIp: '',
        destIp: destIp,
        steps: steps,
        consoleOutput: output,
      );
    }

    output.add('');
    output.add(
      'Pinging $destIp from ${sourceDevice.hostname} (${sourceIface.ipAddress}) with ${protocol.displayName}:',
    );
    output.add('');

    // --- ARP Logic ---
    final isSameSubnet = IpUtils.isInSameSubnet(
      sourceIface.ipAddress,
      destIp,
      sourceIface.subnetMask,
    );
    final targetIpForArp = isSameSubnet
        ? destIp
        : sourceIface.defaultGateway ?? '';

    if (targetIpForArp.isEmpty) {
      output.add(
        '  [${sourceDevice.hostname}] No gateway and not in same subnet. Packet dropped.',
      );
      return PingResult(
        success: false,
        sourceIp: sourceIface.ipAddress,
        destIp: destIp,
        steps: steps,
        consoleOutput: output,
      );
    }

    final targetDeviceForArp = _findDeviceByIp(targetIpForArp);
    String? resolvedMac = sourceDevice.arpCache[targetIpForArp];

    if (resolvedMac == null && targetDeviceForArp != null) {
      final targetIfaceForArp = targetDeviceForArp.interfaces.firstWhere(
        (i) => i.ipAddress == targetIpForArp,
        orElse: () => targetDeviceForArp.interfaces.first,
      );

      output.add(
        '  [${sourceDevice.hostname}] Broadcasting ARP Request for $targetIpForArp...',
      );
      final arpRequest = Packet(
        id: IdGenerator.generatePacketId(),
        type: PacketType.arp,
        sourceIp: sourceIface.ipAddress,
        destIp: targetIpForArp,
        sourceMac: sourceIface.macAddress,
        destMac: 'FF:FF:FF:FF:FF:FF',
      );

      int currentTick = steps.isEmpty
          ? 0
          : steps.fold<int>(
                  0,
                  (max, step) => step.tick > max ? step.tick : max,
                ) +
                1;

      final arpResult = _routePacket(
        packet: arpRequest,
        currentDevice: sourceDevice,
        currentInterface: sourceIface,
        steps: steps,
        output: output,
        tick: currentTick,
      );

      if (arpResult) {
        resolvedMac = targetIfaceForArp.macAddress;
        sourceDevice.arpCache[targetIpForArp] = resolvedMac;

        output.add(
          '  [${targetDeviceForArp.hostname}] Sending ARP Reply to ${sourceIface.macAddress} (Unicast)...',
        );

        final arpReply = Packet(
          id: IdGenerator.generatePacketId(),
          type: PacketType.arpReply,
          sourceIp: targetIpForArp,
          destIp: sourceIface.ipAddress,
          sourceMac: resolvedMac,
          destMac: sourceIface.macAddress,
        );

        currentTick = steps.isEmpty
            ? 0
            : steps.fold<int>(
                    0,
                    (max, step) => step.tick > max ? step.tick : max,
                  ) +
                  1;

        _routePacket(
          packet: arpReply,
          currentDevice: targetDeviceForArp,
          currentInterface: targetIfaceForArp,
          steps: steps,
          output: output,
          tick: currentTick,
        );
      }
    } else if (resolvedMac != null) {
      output.add(
        '  [${sourceDevice.hostname}] MAC for $targetIpForArp found in ARP Cache.',
      );
    }

    if (resolvedMac == null) {
      output.add('  [${sourceDevice.hostname}] ARP Request timed out.');
      return PingResult(
        success: false,
        sourceIp: sourceIface.ipAddress,
        destIp: destIp,
        steps: steps,
        consoleOutput: output,
      );
    }

    output.add('');
    output.add(
      '  [${sourceDevice.hostname}] ARP resolved! Target MAC is $resolvedMac.',
    );
    output.add(
      '  [${sourceDevice.hostname}] Sending ${protocol.displayName} Segment...',
    );

    PacketType pType;
    if (protocol == AclProtocol.icmp) {
      pType = PacketType.icmpEcho;
    } else if (protocol == AclProtocol.tcp) {
      pType = PacketType.tcp;
    } else {
      pType = PacketType.udp;
    }

    // Create the packet
    final packet = Packet(
      id: IdGenerator.generatePacketId(),
      type: pType,
      sourceIp: sourceIface.ipAddress,
      destIp: destIp,
      sourceMac: sourceIface.macAddress,
      destMac: resolvedMac,
    );

    int currentTick = steps.isEmpty
        ? 0
        : steps.fold<int>(0, (max, step) => step.tick > max ? step.tick : max) +
              1;

    final routeResult = _routePacket(
      packet: packet,
      currentDevice: sourceDevice,
      currentInterface: sourceIface,
      steps: steps,
      output: output,
      tick: currentTick,
    );

    final destDevice = _findDeviceByIp(destIp);

    if (routeResult) {
      if (destDevice != null) {
        output.add(
          '  [${destDevice.hostname}] ${protocol.displayName} packet received successfully.',
        );
      } else {
        output.add(
          '  [Internet] ${protocol.displayName} packet reached external network successfully.',
        );
      }
      output.add('');
      output.add('${protocol.displayName} transmission successful.');
    } else {
      output.add('Transmission failed or packet dropped.');
    }

    return PingResult(
      success: routeResult,
      sourceIp: sourceIface.ipAddress,
      destIp: destIp,
      steps: steps,
      consoleOutput: output,
      hops: packet.hops.length,
    );
  }

  /// Routes a packet from the current device towards its destination.
  bool _routePacket({
    required Packet packet,
    required NetworkDevice currentDevice,
    required NetworkInterface currentInterface,
    required List<SimulationStep> steps,
    required List<String> output,
    int tick = 0,
  }) {
    // Prevent infinite loops.
    if (packet.isTtlExpired) {
      output.add('TTL expired at ${currentDevice.hostname}.');
      packet.status = 'ttl_exceeded';
      return false;
    }

    packet.addHop(currentDevice.id);

    steps.add(
      SimulationStep(
        deviceId: currentDevice.id,
        description: 'Packet at ${currentDevice.hostname}',
        packet: packet.copy(),
        tick: tick,
      ),
    );

    // ─── MAC Learning (For switches/hubs/wireless routers) ────────
    if (currentDevice.type.canSwitch &&
        packet.sourceMac.isNotEmpty &&
        packet.sourceMac != 'FF:FF:FF:FF:FF:FF') {
      if (!currentDevice.macTable.containsKey(packet.sourceMac)) {
        output.add(
          '  [${currentDevice.hostname}] Learned MAC ${packet.sourceMac} on port ${currentInterface.name}.',
        );
      }
      currentDevice.macTable[packet.sourceMac] = MacTableEntry(
        macAddress: packet.sourceMac,
        interfaceName: currentInterface.name,
        timestamp: DateTime.now(),
      );
    }

    // ─── Check if this device IS the destination (IP level) ──────
    bool isDestinationIp = false;
    for (final iface in currentDevice.interfaces) {
      if (iface.ipAddress.isNotEmpty && iface.ipAddress == packet.destIp) {
        isDestinationIp = true;
        break;
      }
    }

    // ─── L2 MAC Check (Drop packets not addressed to this device) ────────
    // 1. Routers drop broadcast packets — ARP is L2 and never crosses L3 boundaries.
    if (currentDevice.type.canRoute &&
        !currentDevice.type.canSwitch &&
        packet.hops.length > 1 &&
        packet.destMac == 'FF:FF:FF:FF:FF:FF') {
      // Allow if it's the destination, or DHCP
      if (!isDestinationIp && packet.destIp != '255.255.255.255') {
        output.add(
          '  [${currentDevice.hostname}] Dropping broadcast at L3 boundary.',
        );
        return false;
      }
    }

    // 2. Layer 3 devices drop L2 Unicast packets NOT addressed to their incoming interface MAC.
    if (currentDevice.type.canRoute &&
        !currentDevice.type.canSwitch &&
        packet.hops.length > 1 &&
        packet.destMac != 'FF:FF:FF:FF:FF:FF') {
      if (currentInterface.macAddress != packet.destMac) {
        output.add(
          '  [${currentDevice.hostname}] Dest MAC mismatch. Dropping flooded packet.',
        );
        return false;
      }
    }

    // 3. End devices that received a packet (not originated) drop it if they are not the L3 destination
    // (We do this later in the destination check, but we can also just drop L2 mismatch here).
    if (!currentDevice.type.canRoute &&
        !currentDevice.type.canSwitch &&
        packet.hops.length > 1) {
      if (currentInterface.macAddress != packet.destMac &&
          packet.destMac != 'FF:FF:FF:FF:FF:FF') {
        output.add(
          '  [${currentDevice.hostname}] Dest MAC mismatch. Dropping flooded packet.',
        );
        return false;
      }
    }

    // ─── ACL Check (Firewall / Router / ISP with ACL rules) ──────────
    if (currentDevice.aclRules.isNotEmpty &&
        currentDevice.type.canRoute &&
        packet.type != PacketType.arp &&
        packet.type != PacketType.arpReply) {
      // Determine protocol
      AclProtocol packetProto = AclProtocol.any;
      if (packet.type == PacketType.icmpEcho ||
          packet.type == PacketType.icmpReply) {
        packetProto = AclProtocol.icmp;
      } else if (packet.type == PacketType.tcp) {
        packetProto = AclProtocol.tcp;
      } else if (packet.type == PacketType.udp) {
        packetProto = AclProtocol.udp;
      }

      bool matched = false;
      for (int i = 0; i < currentDevice.aclRules.length; i++) {
        final rule = currentDevice.aclRules[i];
        if (rule.matches(
          packetSourceIp: packet.sourceIp,
          packetDestIp: packet.destIp,
          packetProtocol: packetProto,
        )) {
          matched = true;
          if (rule.action == AclAction.deny) {
            output.add(
              '  [${currentDevice.hostname}] \u{1F6D1} ACL DENY: ${packet.sourceIp} → ${packet.destIp} (${packetProto.displayName}) — Rule #${i + 1}',
            );

            // Create a blocked packet snapshot for animation
            final blockedPacket = Packet(
              id: packet.id,
              type: PacketType.aclBlocked,
              sourceIp: packet.sourceIp,
              destIp: packet.destIp,
              sourceMac: packet.sourceMac,
              destMac: packet.destMac,
              status: 'blocked',
            );
            steps.add(
              SimulationStep(
                deviceId: currentDevice.id,
                description: 'ACL BLOCKED at ${currentDevice.hostname}',
                packet: blockedPacket.copy(),
                tick: tick,
              ),
            );

            packet.status = 'blocked';
            return false;
          } else {
            output.add(
              '  [${currentDevice.hostname}] \u2705 ACL PERMIT: ${packet.sourceIp} → ${packet.destIp} (${packetProto.displayName}) — Rule #${i + 1}',
            );
            break;
          }
        }
      }

      // If no rule matched, use default policy
      if (!matched) {
        if (currentDevice.aclDefaultDeny) {
          output.add(
            '  [${currentDevice.hostname}] \u{1F6D1} ACL DENY (default policy): ${packet.sourceIp} → ${packet.destIp}',
          );

          final blockedPacket = Packet(
            id: packet.id,
            type: PacketType.aclBlocked,
            sourceIp: packet.sourceIp,
            destIp: packet.destIp,
            sourceMac: packet.sourceMac,
            destMac: packet.destMac,
            status: 'blocked',
          );
          steps.add(
            SimulationStep(
              deviceId: currentDevice.id,
              description: 'ACL BLOCKED (default) at ${currentDevice.hostname}',
              packet: blockedPacket.copy(),
              tick: tick,
            ),
          );

          packet.status = 'blocked';
          return false;
        } else {
          output.add(
            '  [${currentDevice.hostname}] \u2705 ACL PERMIT (default policy): ${packet.sourceIp} → ${packet.destIp}',
          );
        }
      }
    }

    // ─── Check if this device IS the destination ────────────────
    for (final iface in currentDevice.interfaces) {
      if (iface.ipAddress == packet.destIp) {
        output.add(
          '  [${currentDevice.hostname}] Packet arrived at destination.',
        );
        packet.status = 'success';
        return true;
      }
    }

    // ─── ISP Magic: If this is an ISP and destination is external ───
    if (currentDevice.type == DeviceType.isp) {
      final destDevice = _findDeviceByIp(packet.destIp);
      if (destDevice == null) {
        output.add(
          '  [${currentDevice.hostname}] (ISP) Magic Route: Forwarding to Internet for ${packet.destIp}.',
        );
        packet.status = 'success';
        return true;
      }
    }

    // ─── Non-destination devices should drop packets they can't handle ─

    // ─── For end devices (originator): check if dest is in same subnet, else use gateway ─
    if (!currentDevice.type.canRoute && !currentDevice.type.canSwitch) {
      // End device — check same subnet first.
      if (IpUtils.isInSameSubnet(
        currentInterface.ipAddress,
        packet.destIp,
        currentInterface.subnetMask,
      )) {
        output.add(
          '  [${currentDevice.hostname}] Destination in same subnet, forwarding directly.',
        );
        return _forwardDirectly(
          packet: packet,
          currentDevice: currentDevice,
          currentInterface: currentInterface,
          steps: steps,
          output: output,
          tick: tick,
        );
      }

      // Use default gateway.
      if (currentInterface.defaultGateway != null &&
          currentInterface.defaultGateway!.isNotEmpty) {
        output.add(
          '  [${currentDevice.hostname}] Forwarding to gateway ${currentInterface.defaultGateway}.',
        );
        return _forwardToNextHop(
          packet: packet,
          currentDevice: currentDevice,
          nextHopIp: currentInterface.defaultGateway!,
          steps: steps,
          output: output,
          tick: tick,
        );
      }

      output.add(
        '  [${currentDevice.hostname}] No gateway configured. Packet dropped.',
      );
      packet.status = 'unreachable';
      return false;
    }

    // ─── For switches/hubs: forward based on connection ─────────
    if (currentDevice.type.canSwitch) {
      output.add(
        '  [${currentDevice.hostname}] Switching packet to connected ports.',
      );
      return _switchPacket(
        packet: packet,
        currentDevice: currentDevice,
        incomingInterface: currentInterface,
        steps: steps,
        output: output,
        tick: tick,
      );
    }

    // ─── For routers: check routing table ───────────────────────
    if (currentDevice.type.canRoute) {
      // First check directly connected networks.
      for (final iface in currentDevice.interfaces) {
        if (iface.ipAddress.isEmpty || iface.status != InterfaceStatus.up) {
          continue;
        }
        if (IpUtils.isInSameSubnet(
          iface.ipAddress,
          packet.destIp,
          iface.subnetMask,
        )) {
          output.add(
            '  [${currentDevice.hostname}] Destination directly connected via ${iface.name}.',
          );

          packet.sourceMac = iface.macAddress;
          final targetDevice = _findDeviceByIp(packet.destIp);
          if (targetDevice != null) {
            final targetIface = targetDevice.interfaces.firstWhere(
              (i) => i.ipAddress == packet.destIp,
              orElse: () => targetDevice.interfaces.first,
            );
            packet.destMac = targetIface.macAddress;
          }

          return _forwardDirectly(
            packet: packet,
            currentDevice: currentDevice,
            currentInterface: iface,
            steps: steps,
            output: output,
            tick: tick,
          );
        }
      }

      // Check static routes.
      final allRoutes = [
        ...RoutingService.generateConnectedRoutes(currentDevice.interfaces),
        ...currentDevice.routingTable,
      ];

      final route = RoutingService.lookupRoute(allRoutes, packet.destIp);
      if (route != null && route.nextHop != '0.0.0.0') {
        output.add(
          '  [${currentDevice.hostname}] Route found: via ${route.nextHop} → ${route.exitInterface}',
        );
        return _forwardToNextHop(
          packet: packet,
          currentDevice: currentDevice,
          nextHopIp: route.nextHop,
          steps: steps,
          output: output,
          tick: tick,
        );
      }

      output.add(
        '  [${currentDevice.hostname}] No route to ${packet.destIp}. Packet dropped.',
      );
      packet.status = 'unreachable';
      return false;
    }

    packet.status = 'unreachable';
    return false;
  }

  /// Forwards packet directly on the same subnet via the connected link.
  bool _forwardDirectly({
    required Packet packet,
    required NetworkDevice currentDevice,
    required NetworkInterface currentInterface,
    required List<SimulationStep> steps,
    required List<String> output,
    required int tick,
  }) {
    if (currentInterface.status != InterfaceStatus.up) {
      output.add(
        '  [${currentDevice.hostname}] Interface ${currentInterface.name} is down.',
      );
      packet.status = 'unreachable';
      return false;
    }

    // Find the connection on this interface.
    final conn = _findConnectionForInterface(
      currentDevice.id,
      currentInterface.name,
    );
    if (conn == null) {
      output.add(
        '  [${currentDevice.hostname}] No link on ${currentInterface.name}.',
      );
      packet.status = 'unreachable';
      return false;
    }

    final nextDeviceId = conn.getOtherDeviceId(currentDevice.id);
    final nextDevice = _findDevice(nextDeviceId);
    if (nextDevice == null) {
      packet.status = 'unreachable';
      return false;
    }

    final nextIfaceName = conn.getOtherInterfaceName(currentDevice.id);
    final nextIface = nextDevice.getInterface(nextIfaceName);
    if (nextIface == null) {
      packet.status = 'unreachable';
      return false;
    }

    if (nextIface.status != InterfaceStatus.up) {
      output.add(
        '  [${nextDevice.hostname}] Ingress interface ${nextIface.name} is down. Packet dropped.',
      );
      packet.status = 'unreachable';
      return false;
    }

    steps.add(
      SimulationStep(
        deviceId: currentDevice.id,
        description:
            'Forwarding via ${currentInterface.name} → ${nextDevice.hostname}',
        packet: packet.copy(),
        connectionId: conn.id,
        tick: tick + 1,
      ),
    );

    return _routePacket(
      packet: packet,
      currentDevice: nextDevice,
      currentInterface: nextIface,
      steps: steps,
      output: output,
      tick: tick + 1,
    );
  }

  /// Forwards packet to a specific next-hop IP.
  bool _forwardToNextHop({
    required Packet packet,
    required NetworkDevice currentDevice,
    required String nextHopIp,
    required List<SimulationStep> steps,
    required List<String> output,
    required int tick,
  }) {
    // Find the outgoing interface that reaches the next hop.
    NetworkInterface? outIface;
    for (final iface in currentDevice.interfaces) {
      if (!iface.isConnected || iface.status != InterfaceStatus.up) continue;

      if (!currentDevice.type.canRoute && !currentDevice.type.canSwitch) {
        outIface = iface;
        break;
      }

      if (iface.ipAddress.isNotEmpty &&
          IpUtils.isInSameSubnet(
            iface.ipAddress,
            nextHopIp,
            iface.subnetMask,
          )) {
        outIface = iface;
        break;
      }
    }

    if (outIface == null) {
      output.add(
        '  [${currentDevice.hostname}] Cannot find interface to reach next-hop $nextHopIp.',
      );
      packet.status = 'unreachable';
      return false;
    }

    if (currentDevice.type.canRoute && !currentDevice.type.canSwitch) {
      packet.sourceMac = outIface.macAddress;
      final targetDevice = _findDeviceByIp(nextHopIp);
      if (targetDevice != null) {
        final targetIface = targetDevice.interfaces.firstWhere(
          (i) => i.ipAddress == nextHopIp,
          orElse: () => targetDevice.interfaces.first,
        );
        packet.destMac = targetIface.macAddress;
      }
    }

    return _forwardDirectly(
      packet: packet,
      currentDevice: currentDevice,
      currentInterface: outIface,
      steps: steps,
      output: output,
      tick: tick,
    );
  }

  /// Switches packet: MAC learning and L2 forwarding.
  bool _switchPacket({
    required Packet packet,
    required NetworkDevice currentDevice,
    required NetworkInterface incomingInterface,
    required List<SimulationStep> steps,
    required List<String> output,
    required int tick,
  }) {
    // 2. Forwarding Decision
    if (packet.destMac != 'FF:FF:FF:FF:FF:FF' &&
        currentDevice.macTable.containsKey(packet.destMac)) {
      // Unicast
      final entry = currentDevice.macTable[packet.destMac]!;
      final targetIfaceName = entry.interfaceName;
      output.add(
        '  [${currentDevice.hostname}] Unicast forwarding to MAC ${packet.destMac} via $targetIfaceName.',
      );

      return _forwardToSpecificPort(
        packet: packet,
        currentDevice: currentDevice,
        portName: targetIfaceName,
        steps: steps,
        output: output,
        tick: tick,
      );
    } else {
      // Flood (Broadcast or Unknown Unicast)
      if (packet.destMac == 'FF:FF:FF:FF:FF:FF') {
        output.add(
          '  [${currentDevice.hostname}] Flooding broadcast packet to all other ports.',
        );
      } else {
        output.add(
          '  [${currentDevice.hostname}] Unknown MAC ${packet.destMac}. Flooding to all other ports.',
        );
      }

      bool success = false;
      for (final iface in currentDevice.interfaces) {
        if (!iface.isConnected || iface.status != InterfaceStatus.up) continue;
        if (iface.name == incomingInterface.name) {
          continue; // Don't send back where it came from
        }

        final conn = _findConnectionForInterface(currentDevice.id, iface.name);
        if (conn == null) continue;

        final nextDeviceId = conn.getOtherDeviceId(currentDevice.id);
        if (packet.hops.contains(nextDeviceId)) continue;

        final nextDevice = _findDevice(nextDeviceId);
        if (nextDevice == null) continue;

        final nextIfaceName = conn.getOtherInterfaceName(currentDevice.id);
        final nextIface = nextDevice.getInterface(nextIfaceName);
        if (nextIface == null || nextIface.status != InterfaceStatus.up) {
          continue;
        }

        // Copy packet for branch
        final branchPacket = Packet(
          id: IdGenerator.generatePacketId(),
          type: packet.type,
          sourceIp: packet.sourceIp,
          destIp: packet.destIp,
          sourceMac: packet.sourceMac,
          destMac: packet.destMac,
          ttl: packet.ttl,
          hops: List.from(packet.hops),
        );

        steps.add(
          SimulationStep(
            deviceId: currentDevice.id,
            description: 'Switching via ${iface.name} → ${nextDevice.hostname}',
            packet: branchPacket.copy(),
            connectionId: conn.id,
            tick: tick + 1,
          ),
        );

        final result = _routePacket(
          packet: branchPacket,
          currentDevice: nextDevice,
          currentInterface: nextIface,
          steps: steps,
          output: output,
          tick: tick + 1,
        );

        if (result) success = true;
      }
      return success;
    }
  }

  bool _forwardToSpecificPort({
    required Packet packet,
    required NetworkDevice currentDevice,
    required String portName,
    required List<SimulationStep> steps,
    required List<String> output,
    required int tick,
  }) {
    final iface = currentDevice.getInterface(portName);
    if (iface == null ||
        !iface.isConnected ||
        iface.status != InterfaceStatus.up) {
      output.add(
        '  [${currentDevice.hostname}] Target port $portName is down or invalid.',
      );
      return false;
    }

    final conn = _findConnectionForInterface(currentDevice.id, iface.name);
    if (conn == null) return false;

    final nextDeviceId = conn.getOtherDeviceId(currentDevice.id);
    if (packet.hops.contains(nextDeviceId)) return false;

    final nextDevice = _findDevice(nextDeviceId);
    if (nextDevice == null) return false;

    final nextIfaceName = conn.getOtherInterfaceName(currentDevice.id);
    final nextIface = nextDevice.getInterface(nextIfaceName);
    if (nextIface == null || nextIface.status != InterfaceStatus.up) {
      return false;
    }

    steps.add(
      SimulationStep(
        deviceId: currentDevice.id,
        description: 'Switching via ${iface.name} → ${nextDevice.hostname}',
        packet: packet.copy(),
        connectionId: conn.id,
        tick: tick + 1,
      ),
    );

    return _routePacket(
      packet: packet,
      currentDevice: nextDevice,
      currentInterface: nextIface,
      steps: steps,
      output: output,
      tick: tick + 1,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────

  NetworkDevice? _findDevice(String id) {
    try {
      return devices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  NetworkDevice? _findDeviceByIp(String ip) {
    for (final device in devices) {
      for (final iface in device.interfaces) {
        if (iface.ipAddress == ip) return device;
      }
    }
    return null;
  }

  Connection? _findConnectionForInterface(String deviceId, String ifaceName) {
    try {
      final conn = connections.firstWhere(
        (c) =>
            (c.deviceAId == deviceId && c.interfaceAName == ifaceName) ||
            (c.deviceBId == deviceId && c.interfaceBName == ifaceName),
      );

      // --- Cable Logic Validation (Auto-MDIX Enabled) ---
      // As requested by the user, we simulate modern Auto-MDIX behavior.
      // Straight and Crossover cables will work interchangeably on all devices.
      final devA = _findDevice(conn.deviceAId);
      final devB = _findDevice(conn.deviceBId);
      if (devA != null && devB != null) {
        if (conn.cableType == CableType.straight ||
            conn.cableType == CableType.crossover) {
          // Strict MDI/MDI-X validation bypassed for Auto-MDIX simulation.
        }
      }

      return conn;
    } catch (_) {
      return null;
    }
  }


  // ─── DHCP Simulation ───────────────────────────────────────────

  /// Simulates a DHCP Discover broadcast from [sourceDeviceId] on [interfaceName].
  DhcpResult simulateDhcpRequest(String sourceDeviceId, String interfaceName) {
    final steps = <SimulationStep>[];
    final output = <String>[];

    final sourceDevice = _findDevice(sourceDeviceId);
    if (sourceDevice == null) {
      output.add('Error: Source device not found.');
      return DhcpResult(success: false, steps: steps, consoleOutput: output);
    }

    final sourceIface = sourceDevice.getInterface(interfaceName);
    if (sourceIface == null || sourceIface.status != InterfaceStatus.up) {
      output.add('Error: Interface down or not found.');
      return DhcpResult(success: false, steps: steps, consoleOutput: output);
    }

    output.add(
      'Sending DHCP Discover broadcast from ${sourceIface.macAddress}...',
    );

    final packet = Packet(
      id: IdGenerator.generatePacketId(),
      type: PacketType.dhcpDiscover,
      sourceIp: '0.0.0.0',
      destIp: '255.255.255.255',
      sourceMac: sourceIface.macAddress,
      destMac: 'FF:FF:FF:FF:FF:FF',
    );

    packet.addHop(sourceDevice.id);

    // Forward the broadcast out of the interface
    final assignedConfig = _broadcastDhcp(
      packet: packet,
      currentDevice: sourceDevice,
      sourceInterface: sourceIface,
      steps: steps,
      output: output,
      tick: 0,
    );

    if (assignedConfig != null) {
      output.add('DHCP Offer received! Assigned IP: ${assignedConfig['ip']}');
      return DhcpResult(
        success: true,
        assignedIp: assignedConfig['ip'],
        subnetMask: assignedConfig['subnet'],
        defaultGateway: assignedConfig['gateway'],
        dnsServer: assignedConfig['dns'],
        steps: steps,
        consoleOutput: output,
      );
    } else {
      output.add('DHCP Request timed out. No server responded.');
      return DhcpResult(success: false, steps: steps, consoleOutput: output);
    }
  }

  /// Broadcasts a DHCP packet and returns config if a server responds.
  Map<String, String>? _broadcastDhcp({
    required Packet packet,
    required NetworkDevice currentDevice,
    required NetworkInterface sourceInterface,
    required List<SimulationStep> steps,
    required List<String> output,
    required int tick,
  }) {
    if (packet.isTtlExpired) return null;

    // Check if current device IS a DHCP server
    if (currentDevice.type.supportsDhcp &&
        currentDevice.dhcpServerConfig != null &&
        currentDevice.dhcpServerConfig!.isEnabled) {
      output.add(
        '  [${currentDevice.hostname}] Received DHCP Discover. Checking pool...',
      );
      final config = currentDevice.dhcpServerConfig!;
      final allocatedIp = config.allocateNextIp(packet.sourceMac);

      if (allocatedIp != null) {
        // Send DHCP Offer packet back
        final offerPacket = Packet(
          id: IdGenerator.generatePacketId(),
          type: PacketType.dhcpOffer,
          sourceIp: config.defaultGateway, // usually server IP
          destIp: '255.255.255.255', // broadcast back to client
          sourceMac: 'SERVER_MAC', // simplified
          destMac: packet.sourceMac,
        );

        steps.add(
          SimulationStep(
            deviceId: currentDevice.id,
            description: 'DHCP Offer sent from ${currentDevice.hostname}',
            packet: offerPacket.copy(),
            tick: tick + 1,
          ),
        );

        return {
          'ip': allocatedIp,
          'subnet': config.subnetMask,
          'gateway': config.defaultGateway,
          'dns': config.dnsServer,
        };
      } else {
        output.add('  [${currentDevice.hostname}] DHCP Pool exhausted!');
      }
    }

    // Broadcast to all active interfaces EXCEPT the one it came from
    for (final iface in currentDevice.interfaces) {
      if (iface.status != InterfaceStatus.up) continue;

      // If we are a router, we don't forward broadcasts across subnets unless configured (DHCP Relay).
      // For simplicity, we assume routers block broadcasts. Switch forwards them.
      // But if we are the source device, we forward to the specifically connected interface.
      if (currentDevice.type.canRoute &&
          currentDevice.id != packet.hops.first) {
        continue; // Routers/L3 devices don't broadcast
      }

      final conn = _findConnectionForInterface(currentDevice.id, iface.name);
      if (conn == null) continue;

      final nextDeviceId = conn.getOtherDeviceId(currentDevice.id);
      if (packet.hops.contains(nextDeviceId)) continue; // Don't loop back

      final nextDevice = _findDevice(nextDeviceId);
      if (nextDevice == null) continue;

      final nextIfaceName = conn.getOtherInterfaceName(currentDevice.id);
      final nextIface = nextDevice.getInterface(nextIfaceName);
      if (nextIface == null || nextIface.status != InterfaceStatus.up) continue;

      // Copy packet for broadcast branch
      final branchPacket = Packet(
        id: IdGenerator.generatePacketId(),
        type: packet.type,
        sourceIp: packet.sourceIp,
        destIp: packet.destIp,
        sourceMac: packet.sourceMac,
        destMac: packet.destMac,
        ttl: packet.ttl,
        hops: List.from(packet.hops),
      );
      branchPacket.addHop(nextDevice.id);

      steps.add(
        SimulationStep(
          deviceId: currentDevice.id,
          description:
              'Broadcasting via ${iface.name} → ${nextDevice.hostname}',
          packet: branchPacket.copy(),
          connectionId: conn.id,
          tick: tick + 1,
        ),
      );

      final result = _broadcastDhcp(
        packet: branchPacket,
        currentDevice: nextDevice,
        sourceInterface: nextIface,
        steps: steps,
        output: output,
        tick: tick + 1,
      );

      // Return first successful offer
      if (result != null) {
        return result;
      }
    }

    return null;
  }
}
