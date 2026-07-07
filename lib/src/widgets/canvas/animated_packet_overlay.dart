import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/packet_type.dart';
import '../../core/utils/canvas_utils.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/topology_provider.dart';
import '../../services/network_engine.dart';

class AnimatedPacketOverlay extends StatefulWidget {
  final bool isDark;

  const AnimatedPacketOverlay({super.key, required this.isDark});

  @override
  State<AnimatedPacketOverlay> createState() => _AnimatedPacketOverlayState();
}

class _AnimatedPacketOverlayState extends State<AnimatedPacketOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _lastStepIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 600,
      ), // Slightly faster than the 800ms timer
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulation = context.watch<SimulationProvider>();
    final topology = context.watch<TopologyProvider>();

    if (!simulation.isSimulating) {
      return const SizedBox.shrink();
    }

    if (simulation.currentStepIndex >= 0 &&
        simulation.currentStepIndex < simulation.groupedSteps.length) {
      final currentSteps = simulation.groupedSteps[simulation.currentStepIndex];

      if (simulation.currentStepIndex != _lastStepIndex) {
        _lastStepIndex = simulation.currentStepIndex;
        _controller.forward(from: 0.0);
      }

      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: currentSteps.map((step) {
              if (step.connectionId != null) {
                return _buildMovingPacket(step, topology);
              } else {
                return _buildDevicePulse(step, topology);
              }
            }).toList(),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMovingPacket(SimulationStep step, TopologyProvider topology) {
    final conn = topology.connections.firstWhere(
      (c) => c.id == step.connectionId,
    );
    final sourceDevice = topology.devices.firstWhere(
      (d) => d.id == step.deviceId,
    );
    final destDeviceId = conn.getOtherDeviceId(sourceDevice.id);
    final destDevice = topology.devices.firstWhere((d) => d.id == destDeviceId);

    // The interface names in the Connection object are strictly tied to deviceA and deviceB.
    final sourceInterface = sourceDevice.id == conn.deviceAId
        ? conn.interfaceAName
        : conn.interfaceBName;
    final destInterface = destDevice.id == conn.deviceAId
        ? conn.interfaceAName
        : conn.interfaceBName;

    final actualStartPos = CanvasUtils.getInterfacePosition(
      sourceDevice,
      sourceInterface,
    );
    final actualEndPos = CanvasUtils.getInterfacePosition(
      destDevice,
      destInterface,
    );

    // Animation curve
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    final currentPos = Offset.lerp(actualStartPos, actualEndPos, curve.value)!;

    final isDhcp =
        step.packet.type == PacketType.dhcpDiscover ||
        step.packet.type == PacketType.dhcpOffer;
    final isArp =
        step.packet.type == PacketType.arp ||
        step.packet.type == PacketType.arpReply;
    final isBlocked = step.packet.type == PacketType.aclBlocked;

    Color color;
    IconData iconData;

    if (isBlocked) {
      color = Colors.redAccent;
      iconData = Icons.block_rounded;
    } else if (isDhcp) {
      color = Colors.blue;
      iconData = Icons.wifi_find;
    } else if (isArp) {
      color = Colors.purpleAccent;
      iconData = Icons.search;
    } else {
      color = widget.isDark ? AppColors.accentAmber : Colors.orange;
      iconData = Icons.mail_outline_rounded;
    }

    return Positioned(
      left: currentPos.dx - 12,
      top: currentPos.dy - 12,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(iconData, size: 14, color: Colors.white),
      ),
    );
  }

  Widget _buildDevicePulse(SimulationStep step, TopologyProvider topology) {
    try {
      final device = topology.devices.firstWhere((d) => d.id == step.deviceId);
      final pos = device.position;

      final isDhcp =
          step.packet.type == PacketType.dhcpDiscover ||
          step.packet.type == PacketType.dhcpOffer;
      final isBlocked = step.packet.type == PacketType.aclBlocked;
      final color = isBlocked
          ? Colors.redAccent
          : isDhcp
          ? Colors.blue
          : (widget.isDark ? AppColors.primaryCyan : AppColors.primaryTeal);

      return Positioned(
        left: pos.dx - 40,
        top: pos.dy - 40,
        child: IgnorePointer(
          child: Transform.scale(
            scale: 1.0 + (_controller.value * 0.5), // 1.0 -> 1.5
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(
                    alpha: 0.8 * (1.0 - _controller.value),
                  ),
                  width: 3 * (1.0 - _controller.value),
                ),
                color: color.withValues(alpha: 0.3 * (1.0 - _controller.value)),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}
