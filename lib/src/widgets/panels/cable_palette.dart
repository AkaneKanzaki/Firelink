import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/cable_type.dart';

/// Horizontal palette at the bottom of the workspace screen to select cable types.
class CablePalette extends StatelessWidget {
  final CableType selectedCableType;
  final void Function(CableType) onCableSelected;

  const CablePalette({
    super.key,
    required this.selectedCableType,
    required this.onCableSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 100, // Slightly shorter than DevicePalette
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
          const SizedBox(height: 4),
          // Cable list
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: CableType.values.where((t) => t != CableType.wireless).length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final visibleTypes = CableType.values.where((t) => t != CableType.wireless).toList();
                final type = visibleTypes[index];
                return _CablePaletteItem(
                  type: type,
                  isDark: isDark,
                  isSelected: type == selectedCableType,
                  onTap: () => onCableSelected(type),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CablePaletteItem extends StatelessWidget {
  final CableType type;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  const _CablePaletteItem({
    required this.type,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Parse the hex color string to Color
    final hexColor = type.colorHex.replaceAll('#', '');
    final color = Color(int.parse('FF$hexColor', radix: 16));

    IconData icon;
    switch (type) {
      case CableType.straight:
        icon = Icons.timeline_rounded;
        break;
      case CableType.crossover:
        icon = Icons.insights_rounded;
        break;
      case CableType.console:
        icon = Icons.power_rounded;
        break;
      case CableType.wireless:
        icon = Icons.wifi_rounded;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected 
                    ? color.withValues(alpha: 0.2) 
                    : color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              type.displayName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
