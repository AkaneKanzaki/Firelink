import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/device_icons.dart';
import '../../core/enums/device_type.dart';
import '../../core/enums/interface_status.dart';
import '../../providers/topology_provider.dart';

/// Slide-up panel showing the selected device's properties (hostname, interfaces, IPs).
class PropertiesPanel extends StatelessWidget {
  final VoidCallback? onClose;

  const PropertiesPanel({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    final topology = context.watch<TopologyProvider>();
    final device = topology.selectedDevice;
    if (device == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = DeviceIcons.getColor(device.type);

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    DeviceIcons.getIcon(device.type),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.hostname,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${device.type.displayName} • ${device.connectedPortCount}/${device.interfaces.length} ports used',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded, size: 20),
                  onPressed: () => _openDeviceConfig(context, device.id),
                  tooltip: 'Configure',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    onClose?.call();
                  },
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ─── Interfaces List ────────────────────────────────────
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: device.interfaces.length,
              itemBuilder: (context, index) {
                final iface = device.interfaces[index];
                return _InterfaceRow(
                  iface: iface,
                  isDark: isDark,
                  onConfigure: () => _openDeviceConfig(context, device.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDeviceConfig(BuildContext context, String deviceId) {
    Navigator.pushNamed(context, '/device-config', arguments: deviceId);
  }
}

class _InterfaceRow extends StatelessWidget {
  final dynamic iface;
  final bool isDark;
  final VoidCallback onConfigure;

  const _InterfaceRow({
    required this.iface,
    required this.isDark,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(iface.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                if (iface.status == InterfaceStatus.up)
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Interface name
          SizedBox(
            width: 130,
            child: Text(
              iface.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // IP address
          Expanded(
            child: Text(
              iface.ipAddress.isEmpty ? 'Not configured' : iface.ipAddress,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: iface.ipAddress.isEmpty
                    ? (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary)
                    : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
              ),
            ),
          ),
          // Connected indicator
          if (iface.isConnected)
            Icon(
              Icons.link_rounded,
              size: 14,
              color: AppColors.linkUp.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(InterfaceStatus status) {
    switch (status) {
      case InterfaceStatus.up:
        return AppColors.linkUp;
      case InterfaceStatus.down:
        return AppColors.linkDown;
      case InterfaceStatus.disabled:
        return AppColors.linkDisabled;
    }
  }
}
