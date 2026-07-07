import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/device_icons.dart';
import '../../core/enums/device_type.dart';

/// Horizontal scrollable palette at the bottom of the workspace screen.
/// Users drag devices from this palette onto the canvas.
class DevicePalette extends StatefulWidget {
  /// Callback when a device type is dragged and dropped onto the canvas.
  final void Function(DeviceType type)? onDeviceTap;

  const DevicePalette({super.key, this.onDeviceTap});

  @override
  State<DevicePalette> createState() => _DevicePaletteState();
}

class _DevicePaletteState extends State<DevicePalette> {
  String _selectedCategory = DeviceIcons.paletteCategories.keys.first;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentDevices =
        DeviceIcons.paletteCategories[_selectedCategory] ?? [];

    return Container(
      height: 140, // Increased height to accommodate category chips
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle indicator
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Categories
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: DeviceIcons.paletteCategories.keys.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = DeviceIcons.paletteCategories.keys.elementAt(
                  index,
                );
                final isSelected = category == _selectedCategory;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                                ? AppColors.primaryTeal.withValues(alpha: 0.2)
                                : AppColors.primaryTeal.withValues(alpha: 0.1))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryTeal
                            : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primaryTeal
                              : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Device list for selected category
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: currentDevices.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final type = currentDevices[index];
                return _DevicePaletteItem(
                  type: type,
                  isDark: isDark,
                  onTap: widget.onDeviceTap != null
                      ? () => widget.onDeviceTap!(type)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicePaletteItem extends StatelessWidget {
  final DeviceType type;
  final bool isDark;
  final VoidCallback? onTap;

  const _DevicePaletteItem({
    required this.type,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = DeviceIcons.getColor(type);
    final icon = DeviceIcons.getIcon(type);

    return Draggable<DeviceType>(
      data: type,
      feedback: Material(
        color: Colors.transparent,
        child: _buildDragFeedback(color, icon),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildItem(color, icon)),
      child: GestureDetector(onTap: onTap, child: _buildItem(color, icon)),
    );
  }

  Widget _buildItem(Color color, IconData icon) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            type.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDragFeedback(Color color, IconData icon) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }
}
