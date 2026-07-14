import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/enums/device_type.dart';
import '../models/topology.dart';
import '../models/tutorial_level.dart';
import '../providers/canvas_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/topology_provider.dart';
import '../providers/locale_provider.dart';
import '../services/file_service.dart';
import '../widgets/canvas/topology_canvas.dart';
import '../widgets/common/tool_button.dart';
import '../widgets/panels/console_panel.dart';
import '../widgets/panels/device_palette.dart';
import '../widgets/panels/cable_palette.dart';
import '../widgets/panels/properties_panel.dart';

/// Main workspace screen with the topology canvas, toolbar, and device palette.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  bool _showPalette = true;
  bool _showConsole = false;
  bool _showProperties = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerViewport();
    });
  }

  void _centerViewport() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final canvasState = context.read<CanvasProvider>();
    final topology = context.read<TopologyProvider>();
    
    if (topology.currentTutorial != null) {
      // Gather all blueprint offsets
      final Set<Offset> offsets = {};
      for (var stage in topology.currentTutorial!.stages) {
        for (var device in stage.targetDevices) {
          offsets.add(device.position);
        }
      }
      if (offsets.isNotEmpty) {
        canvasState.centerOnOffsets(offsets.toList(), size);
      } else {
        canvasState.resetToCenter(size);
      }
    } else if (topology.devices.isNotEmpty) {
      final offsets = topology.devices.map((d) => d.position).toList();
      canvasState.centerOnOffsets(offsets, size);
    } else {
      canvasState.resetToCenter(size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final canvasState = context.watch<CanvasProvider>();
    final topology = context.watch<TopologyProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _requestExit(context);
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        body: SafeArea(
          child: Stack(
            children: [
              // ─── Canvas (full screen) ─────────────────────────────
              Positioned.fill(
                child: DragTarget<DeviceType>(
                  onAcceptWithDetails: (details) {
                    final renderContext = TopologyCanvas.canvasKey.currentContext;
                    if (renderContext == null) return;

                    final renderBox = renderContext.findRenderObject() as RenderBox;
                    final localPosition = renderBox.globalToLocal(details.offset);

                    final matrix = canvasState.transformController.value.clone()..invert();
                    final canvasPosition = MatrixUtils.transformPoint(matrix, localPosition);

                    topology.addDevice(details.data, canvasPosition);
                    HapticFeedback.mediumImpact();
                  },
                  builder: (context, candidateData, rejectedData) {
                    return TopologyCanvas(
                      onDeviceDoubleTap: () {
                        setState(() => _showProperties = true);
                      },
                      onCanvasTap: () {
                        setState(() => _showProperties = false);
                      },
                    );
                  },
                ),
              ),

              // ─── Top App Bar ──────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildAppBar(context, isDark, topology),
              ),

              // ─── Left Toolbar ─────────────────────────────────────
              Positioned(
                left: 12,
                top: 72, // Clear AppBar
                bottom: 116, // Clear Device Palette
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildToolbar(context, isDark, canvasState),
                ),
              ),

              // ─── Mode Indicator ───────────────────────────────────
              if (canvasState.mode != CanvasMode.select)
                Positioned(
                  top: 72,
                  right: 16,
                  child: _buildModeIndicator(context, canvasState),
                ),

              // ─── Connection Source Indicator ─────────────────────
              if (topology.connectionSourceDeviceId != null)
                Positioned(
                  top: 90,
                  left: 0,
                  right: 0,
                  child: _buildConnectionHint(context, topology),
                ),

              // ─── Tutorial Guide Card ──────────────────────────────
              if (topology.currentTutorial != null)
                Positioned(
                  top: 72,
                  left: 60, // Clear the toolbar
                  child: _buildTutorialGuide(context, topology, isDark),
                ),

              // ─── Bottom Device/Cable Palette ────────────────────────────
              if (_showPalette)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: canvasState.mode == CanvasMode.connect
                      ? CablePalette(
                          selectedCableType: canvasState.selectedCableType,
                          onCableSelected: (type) {
                            canvasState.setSelectedCableType(type);
                            HapticFeedback.lightImpact();
                          },
                        )
                      : const DevicePalette(),
                ),

              // ─── Properties Panel (when double tapped) ───────────
              if (_showProperties && topology.selectedDevice != null)
                Positioned(
                  bottom: _showPalette ? 100 : 0,
                  left: 0,
                  right: 0,
                  child: PropertiesPanel(
                    onClose: () {
                      setState(() => _showProperties = false);
                    },
                  ),
                ),

              // ─── Console Panel ────────────────────────────────────
              if (_showConsole && topology.selectedDevice != null)
                Positioned(
                  bottom: _showPalette ? 100 : 0,
                  left: 0,
                  right: 0,
                  height: 280,
                  child: ConsolePanel(
                    deviceId: topology.selectedDevice!.id,
                    onClose: () => setState(() => _showConsole = false),
                  ),
                ),

              // ─── Palette Toggle ───────────────────────────────────
              Positioned(
                bottom: _showPalette ? 108 : 16,
                right: 16,
                child: _buildPaletteToggle(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _requestExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = context.watch<ThemeProvider>().isDarkMode;
        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          title: Text(
            'Keluar Workspace?',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Pastikan project Anda sudah tersimpan sebelum keluar. Tetap keluar?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.linkDown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
    return shouldExit ?? false;
  }

  Widget _buildAppBar(
    BuildContext context,
    bool isDark,
    TopologyProvider topology,
  ) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkSurface : AppColors.lightSurface)
            .withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: () async {
              if (await _requestExit(context)) {
                topology.exitTutorial();
                if (context.mounted) Navigator.pop(context);
              }
            },
            tooltip: 'Back to Home',
          ),
          const SizedBox(width: 4),
          // Title
          Expanded(
            child: Text(
              'Firelink Workspace',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Device count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.primaryCyan : AppColors.primaryTeal)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${topology.devices.length} devices',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.primaryCyan : AppColors.primaryTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Save Button
          IconButton(
            icon: const Icon(Icons.save_outlined, size: 20),
            onPressed: () => _saveTopology(context, topology),
          ),

          // Load Button
          IconButton(
            icon: const Icon(Icons.folder_open_outlined, size: 20),
            tooltip: 'Load Workspace',
            onPressed: () => _loadTopology(context, topology),
          ),

          const SizedBox(width: 4),

          // PDU Mode Toggle
          IconButton(
            icon: Icon(
              topology.isPduMode
                  ? Icons.mail_rounded
                  : Icons.mail_outline_rounded,
              size: 20,
              color: topology.isPduMode ? AppColors.accentAmber : null,
            ),
            onPressed: () => topology.togglePduMode(),
            tooltip: 'Simple PDU (Packet Mailing)',
          ),

          // Complex PDU Mode Toggle
          IconButton(
            icon: Icon(
              topology.isComplexPduMode
                  ? Icons.mark_email_unread_rounded
                  : Icons.outgoing_mail,
              size: 20,
              color: topology.isComplexPduMode ? AppColors.accentAmber : null,
            ),
            onPressed: () => topology.toggleComplexPduMode(),
            tooltip: 'Complex PDU (TCP/UDP/ICMP)',
          ),

          const SizedBox(width: 4),
          // Theme toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    bool isDark,
    CanvasProvider canvasState,
  ) {
    return Container(
      width: 56, // Fixed width to prevent horizontal clipping
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkSurface : AppColors.lightSurface)
            .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToolButton(
                icon: Icons.near_me_rounded,
                tooltip: 'Select',
                isActive: canvasState.mode == CanvasMode.select,
                onTap: () => canvasState.setMode(CanvasMode.select),
              ),
              const SizedBox(height: 8),
              ToolButton(
                icon: Icons.timeline_rounded,
                tooltip: 'Connect',
                isActive: canvasState.mode == CanvasMode.connect,
                onTap: () {
                  canvasState.setMode(CanvasMode.connect);
                  context.read<TopologyProvider>().cancelConnection();
                },
              ),
              const SizedBox(height: 8),
              ToolButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete',
                isActive: canvasState.mode == CanvasMode.delete,
                onTap: () {
                  canvasState.setMode(CanvasMode.delete);
                  context.read<TopologyProvider>().cancelConnection();
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, thickness: 1),
              ),
              ToolButton(
                icon: Icons.grid_4x4_rounded,
                tooltip: 'Toggle Grid',
                isActive: canvasState.showGrid,
                onTap: () => canvasState.toggleGrid(),
              ),
              const SizedBox(height: 8),
              ToolButton(
                icon: Icons.zoom_in_rounded,
                tooltip: 'Zoom In',
                isActive: false,
                onTap: () => _zoom(1.2, canvasState),
              ),
              const SizedBox(height: 8),
              ToolButton(
                icon: Icons.zoom_out_rounded,
                tooltip: 'Zoom Out',
                isActive: false,
                onTap: () => _zoom(1 / 1.2, canvasState),
              ),
              const SizedBox(height: 8),
              ToolButton(
                icon: Icons.restore_rounded,
                tooltip: 'Reset View',
                isActive: false,
                onTap: () => _resetZoom(context, canvasState),
              ),
              const SizedBox(height: 8),
              ToolButton(
                icon: Icons.terminal_rounded,
                tooltip: 'Console',
                isActive: _showConsole,
                onTap: () => setState(() => _showConsole = !_showConsole),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _zoom(double factor, CanvasProvider canvasState) {
    final matrix = canvasState.transformController.value.clone();

    final renderBox = context.findRenderObject() as RenderBox;
    final center = renderBox.size.center(Offset.zero);

    final sceneCenter = MatrixUtils.transformPoint(
      matrix.clone()..invert(),
      center,
    );
    matrix.multiply(Matrix4.diagonal3Values(factor, factor, 1.0));
    final newSceneCenter = MatrixUtils.transformPoint(
      matrix.clone()..invert(),
      center,
    );

    matrix.multiply(
      Matrix4.translationValues(
        newSceneCenter.dx - sceneCenter.dx,
        newSceneCenter.dy - sceneCenter.dy,
        0.0,
      ),
    );

    canvasState.transformController.value = matrix;
    canvasState.setScale(matrix.getMaxScaleOnAxis());
  }

  void _resetZoom(BuildContext context, CanvasProvider canvasState) {
    final topology = context.read<TopologyProvider>();
    final viewportSize = MediaQuery.of(context).size;
    
    if (topology.devices.isNotEmpty) {
      canvasState.centerOnOffsets(
        topology.devices.map((d) => d.position).toList(),
        viewportSize,
      );
    } else {
      canvasState.resetToCenter(viewportSize);
    }
  }

  Widget _buildModeIndicator(BuildContext context, CanvasProvider canvasState) {
    final mode = canvasState.mode;
    final isComplexPdu = context.watch<TopologyProvider>().isComplexPduMode;
    final isPdu = context.watch<TopologyProvider>().isPduMode;

    if (mode == CanvasMode.select && !isComplexPdu && !isPdu) {
      return const SizedBox.shrink();
    }

    Color color;
    String label;
    IconData icon;

    if (mode == CanvasMode.delete) {
      color = AppColors.linkDown;
      label = 'Delete Mode — Tap a device to remove';
      icon = Icons.delete_outline_rounded;
    } else if (mode == CanvasMode.connect) {
      color = AppColors.primaryCyan;
      label = 'Connection Mode — Tap two devices to connect';
      icon = Icons.timeline_rounded;
    } else if (isComplexPdu) {
      color = AppColors.accentAmber;
      label = 'Complex PDU Mode — Select Source then Destination';
      icon = Icons.outgoing_mail;
    } else {
      color = AppColors.accentAmber;
      label = 'PDU Mode — Select Source then Destination';
      icon = Icons.mail_outline_rounded;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                canvasState.setMode(CanvasMode.select);
                context.read<TopologyProvider>().cancelConnection();
              },
              child: Icon(Icons.close_rounded, size: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionHint(BuildContext context, TopologyProvider topology) {
    final source = topology.devices.firstWhere(
      (d) => d.id == topology.connectionSourceDeviceId,
      orElse: () => topology.devices.first,
    );

    final ifaceText = topology.connectionSourceInterfaceName != null
        ? ' (${topology.connectionSourceInterfaceName})'
        : '';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accentAmber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accentAmber.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          'From: ${source.hostname}$ifaceText — Tap destination device',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.accentAmber,
          ),
        ),
      ),
    );
  }

  Future<void> _saveTopology(
    BuildContext context,
    TopologyProvider topology,
  ) async {
    final t = Topology(
      name: 'Firelink Project',
      devices: topology.devices.toList(),
      connections: topology.connections.toList(),
    );
    final path = await FileService.saveTopology(t);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path != null ? 'Saved to: $path' : 'Failed to save project.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _loadTopology(
    BuildContext context,
    TopologyProvider topology,
  ) async {
    final t = await FileService.loadTopologyFromPicker();

    if (t != null) {
      topology.loadFromTopology(t);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project loaded successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildPaletteToggle(bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _showPalette = !_showPalette),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(
          _showPalette
              ? Icons.keyboard_arrow_down_rounded
              : Icons.keyboard_arrow_up_rounded,
          size: 20,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildTutorialGuide(BuildContext context, TopologyProvider topology, bool isDark) {
    final level = topology.currentTutorial!;
    final completed = topology.tutorialCompleted;
    final loc = context.watch<LocaleProvider>();

    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed ? AppColors.linkUp : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                completed ? Icons.check_circle_rounded : Icons.school_rounded,
                color: completed ? AppColors.linkUp : AppColors.primaryCyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.get(level.title),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            completed 
                ? 'Great job! You have completed this tutorial level.' 
                : loc.get(level.stages[topology.currentTutorialStageIndex].description),
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          if (completed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: () {
                        topology.exitTutorial();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: const Text('Levels', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () {
                        final allLevels = TutorialLevel.allLevels;
                        final currentIndex = allLevels.indexWhere((l) => l.id == level.id);
                        if (currentIndex != -1 && currentIndex + 1 < allLevels.length) {
                          topology.startTutorial(allLevels[currentIndex + 1]);
                          // Give a brief frame for the topology to update before centering
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _centerViewport();
                          });
                        } else {
                          topology.exitTutorial();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryCyan,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Next', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
