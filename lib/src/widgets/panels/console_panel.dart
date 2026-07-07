import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme.dart';
import '../../core/utils/ip_utils.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/topology_provider.dart';

/// Terminal-style console panel for running commands (ping, traceroute).
class ConsolePanel extends StatefulWidget {
  /// The device ID to run commands from.
  final String deviceId;
  final VoidCallback? onClose;

  const ConsolePanel({super.key, required this.deviceId, this.onClose});

  @override
  State<ConsolePanel> createState() => _ConsolePanelState();
}

class _ConsolePanelState extends State<ConsolePanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  int _lastConsoleLength = 0;

  @override
  void initState() {
    super.initState();
    // Delay initialization until after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sim = context.read<SimulationProvider>();
      _lastConsoleLength = sim.consoleOutput.length;
      sim.addListener(_onSimulationUpdate);
    });
  }

  void _onSimulationUpdate() {
    if (!mounted) return;
    final sim = context.read<SimulationProvider>();
    if (sim.consoleOutput.length != _lastConsoleLength) {
      _lastConsoleLength = sim.consoleOutput.length;
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Use animateTo to smoothly scroll down
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  late SimulationProvider _simProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _simProvider = context.read<SimulationProvider>();
  }

  @override
  void dispose() {
    _simProvider.removeListener(_onSimulationUpdate);
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulation = context.watch<SimulationProvider>();
    final topology = context.watch<TopologyProvider>();
    final device = topology.devices.firstWhere((d) => d.id == widget.deviceId);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.consoleBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: const Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        children: [
          // ─── Header ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  size: 16,
                  color: AppColors.consoleText,
                ),
                const SizedBox(width: 8),
                Text(
                  '${device.hostname} Console',
                  style: AppTheme.consoleTextStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => simulation.clearConsole(),
                  child: const Icon(
                    Icons.clear_all_rounded,
                    size: 18,
                    color: AppColors.darkTextTertiary,
                  ),
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── Output Area ────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: simulation.consoleOutput.length,
              itemBuilder: (context, index) {
                final line = simulation.consoleOutput[index];
                return Text(
                  line,
                  style: AppTheme.consoleTextStyle.copyWith(
                    color: _getLineColor(line),
                  ),
                );
              },
            ),
          ),

          // ─── Input Area ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.darkBorder)),
            ),
            child: Row(
              children: [
                Text(
                  '${device.hostname}> ',
                  style: AppTheme.consoleTextStyle.copyWith(
                    color: AppColors.consolePrompt,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    style: AppTheme.consoleTextStyle,
                    cursorColor: AppColors.consoleText,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type a command (e.g., ping 192.168.1.1)',
                      hintStyle: TextStyle(
                        color: AppColors.darkTextTertiary,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (command) => _executeCommand(command),
                  ),
                ),
                GestureDetector(
                  onTap: () => _executeCommand(_inputController.text),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: AppColors.primaryCyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _executeCommand(String command) {
    if (command.trim().isEmpty) return;

    final simulation = context.read<SimulationProvider>();
    final topology = context.read<TopologyProvider>();
    final device = topology.devices.firstWhere((d) => d.id == widget.deviceId);

    simulation.addConsoleOutput('${device.hostname}> $command');
    _inputController.clear();

    final parts = command.trim().split(RegExp(r'\s+'));
    final cmd = parts[0].toLowerCase();

    switch (cmd) {
      case 'ping':
        if (parts.length < 2) {
          simulation.addConsoleOutput('Usage: ping <ip-address>');
          break;
        }
        final destIp = parts[1];
        if (!IpUtils.isValidIp(destIp)) {
          simulation.addConsoleOutput('% Invalid IP address: $destIp');
          break;
        }
        simulation.runPing(
          sourceDeviceId: widget.deviceId,
          destIp: destIp,
          devices: topology.devices,
          connections: topology.connections,
        );
        break;

      case 'help':
        simulation.addConsoleOutput('Available commands:');
        simulation.addConsoleOutput('  ping <ip>    - Send ICMP echo request');
        simulation.addConsoleOutput('  clear        - Clear console output');
        simulation.addConsoleOutput('  help         - Show this help message');
        break;

      case 'clear':
        simulation.clearConsole();
        break;

      default:
        simulation.addConsoleOutput(
          '% Unknown command: "$cmd". Type "help" for available commands.',
        );
    }

    // Focus logic
    _focusNode.requestFocus();
  }

  Color _getLineColor(String line) {
    if (line.startsWith('%') ||
        line.contains('Error') ||
        line.contains('dropped')) {
      return AppColors.consoleError;
    }
    if (line.contains('Reply from') || line.contains('success')) {
      return AppColors.consoleText;
    }
    if (line.contains('timed out') || line.contains('unreachable')) {
      return AppColors.consoleWarning;
    }
    if (line.endsWith('>')) {
      return AppColors.consolePrompt;
    }
    return AppColors.consoleText.withValues(alpha: 0.8);
  }
}
