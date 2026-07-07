import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/canvas_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/topology_provider.dart';
import '../../models/device.dart';
import '../../core/enums/acl_enums.dart';
import 'connection_painter.dart';
import 'device_painter.dart';
import 'grid_painter.dart';
import 'blueprint_painter.dart';
import 'animated_packet_overlay.dart';
import '../../providers/simulation_provider.dart';

/// Main canvas widget that renders the topology with devices, connections, and grid.
///
/// Uses InteractiveViewer for pinch-to-zoom and pan, with gesture detection
/// for device selection, dragging, and connection creation.
class TopologyCanvas extends StatefulWidget {
  final VoidCallback? onDeviceDoubleTap;
  final VoidCallback? onCanvasTap;

  const TopologyCanvas({super.key, this.onDeviceDoubleTap, this.onCanvasTap});

  static final GlobalKey canvasKey = GlobalKey();

  @override
  State<TopologyCanvas> createState() => _TopologyCanvasState();
}

class _TopologyCanvasState extends State<TopologyCanvas> with SingleTickerProviderStateMixin {
  String? _draggingDeviceId;
  Offset? _pendingConnectionEndPoint;

  DateTime? _lastTapTime;
  String? _lastTappedDeviceId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final topology = context.watch<TopologyProvider>();
    final canvasState = context.watch<CanvasProvider>();

    return Stack(
      key: TopologyCanvas.canvasKey,
      children: [
        InteractiveViewer(
          constrained: false,
          transformationController: canvasState.transformController,
          minScale: 0.3,
          maxScale: 3.0,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          onInteractionUpdate: (details) {
            // Update canvas provider with current scale.
            final scale = canvasState.transformController.value
                .getMaxScaleOnAxis();
            canvasState.setScale(scale);
          },
          child: GestureDetector(
            onTapDown: (details) => _handleTap(details, topology, canvasState),
            onPanStart: (details) =>
                _handleDragStart(details, topology, canvasState),
            onPanUpdate: (details) =>
                _handleDragUpdate(details, topology, canvasState),
            onPanEnd: (_) => _handleDragEnd(topology),
            child: SizedBox(
              width: 10000,
              height: 10000,
              child: Stack(
                children: [
                  if (canvasState.showGrid)
                    CustomPaint(
                      size: const Size(10000, 10000),
                      painter: GridPainter(
                        isDark: isDark,
                        transform: canvasState.transformController.value,
                        viewportSize: MediaQuery.of(context).size,
                      ),
                    ),
                  if (topology.currentTutorial != null)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(10000, 10000),
                          painter: BlueprintPainter(
                            level: topology.currentTutorial!,
                            stageIndex: topology.currentTutorialStageIndex,
                            isDark: isDark,
                            opacity: _pulseAnimation.value,
                          ),
                        );
                      },
                    ),
                  CustomPaint(
                    size: const Size(10000, 10000),
                    painter: _TopologyCombinedPainter(
                      devices: topology.devices,
                      connections: topology.connections,
                      selectedConnectionId: topology.selectedConnectionId,
                      isDark: isDark,
                      pendingFromDeviceId: topology.connectionSourceDeviceId,
                      pendingEndPoint: _pendingConnectionEndPoint,
                    ),
                  ),
                  // Packet animation layer
                  AnimatedPacketOverlay(isDark: isDark),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Converts a global position to canvas-local position.
  Offset _toCanvasPosition(Offset globalPosition, CanvasProvider canvasState) {
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(globalPosition);
    final matrix = canvasState.transformController.value.clone()..invert();
    return MatrixUtils.transformPoint(matrix, localPosition);
  }

  void _handleTap(
    TapDownDetails details,
    TopologyProvider topology,
    CanvasProvider canvasState,
  ) {
    final canvasPos = _toCanvasPosition(details.globalPosition, canvasState);
    final hitDevice = topology.hitTestDevice(canvasPos);

    if (topology.isPduMode || topology.isComplexPduMode) {
      if (hitDevice != null) {
        if (topology.pduSourceDeviceId == null) {
          topology.setPduSourceDevice(hitDevice.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Source selected: ${hitDevice.hostname}. Now tap destination.',
              ),
            ),
          );
        } else {
          final sourceId = topology.pduSourceDeviceId!;

          if (sourceId == hitDevice.id) {
            topology.isComplexPduMode
                ? topology.cancelComplexPduMode()
                : topology.cancelPduMode();
            return;
          }

          // Get first configured IP of destination
          final destIp = hitDevice.interfaces
              .map((i) => i.ipAddress)
              .firstWhere((ip) => ip.isNotEmpty, orElse: () => '');

          if (destIp.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Destination ${hitDevice.hostname} has no IP address!',
                ),
              ),
            );
          } else {
            if (topology.isComplexPduMode) {
              _showComplexPduDialog(context, sourceId, hitDevice, destIp);
            } else {
              final simulation = context.read<SimulationProvider>();
              final result = simulation.runPing(
                sourceDeviceId: sourceId,
                destIp: destIp,
                devices: topology.devices,
                connections: topology.connections,
              );

              if (result.steps.isEmpty &&
                  !result.success &&
                  result.consoleOutput.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.consoleOutput.last.trim())),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Pinging $destIp from source...')),
                );
              }
            }
          }

          topology.isComplexPduMode
              ? topology.cancelComplexPduMode()
              : topology.cancelPduMode();
        }
      } else {
        topology.isComplexPduMode
            ? topology.cancelComplexPduMode()
            : topology.cancelPduMode();
      }
      return;
    }

    switch (canvasState.mode) {
      case CanvasMode.select:
        if (hitDevice != null) {
          final now = DateTime.now();
          if (_lastTapTime != null &&
              now.difference(_lastTapTime!) <
                  const Duration(milliseconds: 300) &&
              _lastTappedDeviceId == hitDevice.id) {
            // It's a double tap!
            topology.selectDevice(hitDevice.id);
            widget.onDeviceDoubleTap?.call();
            _lastTapTime = null; // reset
            return;
          }

          _lastTapTime = now;
          _lastTappedDeviceId = hitDevice.id;

          topology.selectDevice(hitDevice.id);
        } else {
          _lastTapTime = null;
          _lastTappedDeviceId = null;
          topology.clearSelection();
          widget.onCanvasTap?.call();
        }
        break;

      case CanvasMode.connect:
        if (hitDevice != null) {
          _showInterfaceSelectionMenu(
            context,
            hitDevice,
            details.globalPosition,
            (interfaceName) {
              if (topology.connectionSourceDeviceId == null) {
                topology.startConnection(hitDevice.id, interfaceName);
              } else {
                final sourceId = topology.connectionSourceDeviceId!;
                final sourceInterface = topology.connectionSourceInterfaceName!;

                // Prevent connecting to self on the same interface, or even same device.
                if (sourceId == hitDevice.id) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cannot connect a device to itself'),
                    ),
                  );
                  topology.cancelConnection();
                  setState(() => _pendingConnectionEndPoint = null);
                  return;
                }

                final connection = topology.connectDevices(
                  sourceId,
                  sourceInterface,
                  hitDevice.id,
                  interfaceName,
                  cableType: canvasState.selectedCableType,
                );

                if (connection != null) {
                  HapticFeedback.lightImpact();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to connect devices')),
                  );
                }
                setState(() => _pendingConnectionEndPoint = null);
              }
            },
            onCanceled: () {
              if (topology.connectionSourceDeviceId != null) {
                topology.cancelConnection();
                setState(() => _pendingConnectionEndPoint = null);
              }
            },
          );
        } else {
          topology.cancelConnection();
          setState(() => _pendingConnectionEndPoint = null);
        }
        break;

      case CanvasMode.delete:
        if (hitDevice != null) {
          _showDeleteConfirmation(context, () {
            topology.removeDevice(hitDevice.id);
          });
        } else {
          final hitConnection = topology.hitTestConnection(canvasPos);
          if (hitConnection != null) {
            _showDeleteConnectionConfirmation(context, () {
              topology.removeConnection(hitConnection.id);
            });
          }
        }
        break;
    }
  }

  void _handleDragStart(
    DragStartDetails details,
    TopologyProvider topology,
    CanvasProvider canvasState,
  ) {
    if (canvasState.mode != CanvasMode.select) return;

    final canvasPos = _toCanvasPosition(details.globalPosition, canvasState);
    final hitDevice = topology.hitTestDevice(canvasPos);

    if (hitDevice != null) {
      HapticFeedback.selectionClick();
      _draggingDeviceId = hitDevice.id;
      topology.selectDevice(hitDevice.id);
    }
  }

  void _handleDragUpdate(
    DragUpdateDetails details,
    TopologyProvider topology,
    CanvasProvider canvasState,
  ) {
    if (canvasState.mode == CanvasMode.connect &&
        topology.connectionSourceDeviceId != null) {
      // Update pending connection end point for preview line.
      setState(() {
        _pendingConnectionEndPoint = _toCanvasPosition(
          details.globalPosition,
          canvasState,
        );
      });
      return;
    }

    if (_draggingDeviceId != null && canvasState.mode == CanvasMode.select) {
      final canvasPos = _toCanvasPosition(details.globalPosition, canvasState);
      topology.moveDevice(
        _draggingDeviceId!,
        canvasPos,
        snap: canvasState.snapToGrid,
      );
    } else if (_draggingDeviceId == null &&
        canvasState.mode == CanvasMode.select) {
      // Pan the canvas manually when dragging on empty space
      final matrix = canvasState.transformController.value.clone();
      final scale = matrix.getMaxScaleOnAxis();
      matrix.multiply(
        Matrix4.translationValues(
          details.delta.dx / scale,
          details.delta.dy / scale,
          0.0,
        ),
      );
      canvasState.transformController.value = matrix;
    }
  }

  void _handleDragEnd(TopologyProvider topology) {
    _draggingDeviceId = null;
  }

  void _showComplexPduDialog(
    BuildContext context,
    String sourceId,
    dynamic destDevice,
    String destIp,
  ) {
    AclProtocol selectedProtocol = AclProtocol.tcp;
    final topology = context.read<TopologyProvider>();
    final sourceDevice = topology.devices.firstWhere((d) => d.id == sourceId);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Complex PDU Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Source: ${sourceDevice.hostname}'),
              Text('Destination: ${destDevice.hostname} ($destIp)'),
              const SizedBox(height: 16),
              DropdownButtonFormField<AclProtocol>(
                initialValue: selectedProtocol,
                decoration: const InputDecoration(labelText: 'Protocol'),
                items: [AclProtocol.icmp, AclProtocol.tcp, AclProtocol.udp]
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => selectedProtocol = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                final simulation = context.read<SimulationProvider>();
                final result = simulation.runCustomPdu(
                  sourceDeviceId: sourceId,
                  destIp: destIp,
                  protocol: selectedProtocol,
                  devices: topology.devices,
                  connections: topology.connections,
                );

                if (result.steps.isEmpty &&
                    !result.success &&
                    result.consoleOutput.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.consoleOutput.last.trim())),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Sending ${selectedProtocol.displayName} packet to $destIp...',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Send PDU'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInterfaceSelectionMenu(
    BuildContext context,
    NetworkDevice device,
    Offset globalPosition,
    void Function(String interfaceName) onSelected, {
    VoidCallback? onCanceled,
  }) {
    final availableInterfaces = device.interfaces
        .where((i) => i.connectedToConnectionId == null)
        .toList();

    if (availableInterfaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No available interfaces on ${device.hostname}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      onCanceled?.call();
      return;
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: availableInterfaces.map((iface) {
        return PopupMenuItem<String>(
          value: iface.name,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors
                      .linkDown, // Unconnected port is 'down' technically until connected
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(iface.name, style: const TextStyle(fontSize: 14)),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        onSelected(value);
      } else {
        onCanceled?.call();
      }
    });
  }

  void _showDeleteConfirmation(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Device'),
        content: const Text(
          'Are you sure you want to delete this device? All its connections will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.linkDown),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConnectionConfirmation(
    BuildContext context,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cable'),
        content: const Text('Are you sure you want to delete this cable?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.linkDown),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Combined painter that draws connections first, then devices on top.
class _TopologyCombinedPainter extends CustomPainter {
  final List devices;
  final List connections;
  final String? selectedConnectionId;
  final bool isDark;
  final String? pendingFromDeviceId;
  final Offset? pendingEndPoint;

  _TopologyCombinedPainter({
    required this.devices,
    required this.connections,
    this.selectedConnectionId,
    required this.isDark,
    this.pendingFromDeviceId,
    this.pendingEndPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connections first (behind devices).
    ConnectionPainter(
      connections: connections.cast(),
      devices: devices.cast(),
      selectedConnectionId: selectedConnectionId,
      isDark: isDark,
      pendingFromDeviceId: pendingFromDeviceId,
      pendingEndPoint: pendingEndPoint,
    ).paint(canvas, size);

    // Draw devices on top.
    DevicePainter(devices: devices.cast(), isDark: isDark).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _TopologyCombinedPainter oldDelegate) {
    return true;
  }
}
