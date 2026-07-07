import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A circular icon button used in the canvas toolbar for mode switching.
class ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const ToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.primaryCyan : AppColors.primaryTeal;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? activeColor.withValues(alpha: 0.15)
                : (isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant),
            border: Border.all(
              color: isActive
                  ? activeColor
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive
                ? activeColor
                : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}
