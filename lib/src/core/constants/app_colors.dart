import 'package:flutter/material.dart';

/// Firelink color palette for dark and light themes.
class AppColors {
  AppColors._();

  // ─── Dark Theme ───────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceVariant = Color(0xFF1C2333);
  static const Color darkCard = Color(0xFF1E2636);
  static const Color darkBorder = Color(0xFF30363D);
  static const Color darkTextPrimary = Color(0xFFE6EDF3);
  static const Color darkTextSecondary = Color(0xFF8B949E);
  static const Color darkTextTertiary = Color(0xFF6E7681);

  // ─── Light Theme ──────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF6F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F3F6);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFD0D7DE);
  static const Color lightTextPrimary = Color(0xFF1F2328);
  static const Color lightTextSecondary = Color(0xFF656D76);
  static const Color lightTextTertiary = Color(0xFF8C959F);

  // ─── Brand / Accent ───────────────────────────────────────────
  static const Color primaryCyan = Color(0xFF00D4AA);
  static const Color primaryCyanDark = Color(0xFF00B894);
  static const Color primaryTeal = Color(0xFF0891B2);
  static const Color secondaryViolet = Color(0xFF7C3AED);
  static const Color secondaryVioletLight = Color(0xFF8B5CF6);
  static const Color accentAmber = Color(0xFFF59E0B);

  // ─── Status Colors ────────────────────────────────────────────
  static const Color linkUp = Color(0xFF10B981);
  static const Color linkDown = Color(0xFFEF4444);
  static const Color linkDisabled = Color(0xFF6B7280);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ─── Device Type Colors (for canvas icons) ────────────────────
  static const Color routerColor = Color(0xFF3B82F6);
  static const Color switchColor = Color(0xFF10B981);
  static const Color hubColor = Color(0xFFF59E0B);
  static const Color pcColor = Color(0xFF8B5CF6);
  static const Color serverColor = Color(0xFFEF4444);
  static const Color laptopColor = Color(0xFF06B6D4);

  static const Color ispColor = Color(0xFF6366F1); // Indigo
  static const Color smartphoneColor = Color(0xFFEC4899); // Pink
  static const Color accessPointColor = Color(0xFF14B8A6); // Teal
  static const Color wirelessRouterColor = Color(
    0xFF3B82F6,
  ); // Blue same as router
  static const Color printerColor = Color(0xFF8B949E); // Grey
  static const Color ipPhoneColor = Color(0xFFF97316); // Orange
  static const Color firewallColor = Color(0xFFDC2626); // Red darker

  // ─── Canvas ───────────────────────────────────────────────────
  static const Color canvasDarkGrid = Color(0xFF21262D);
  static const Color canvasLightGrid = Color(0xFFE1E4E8);
  static const Color connectionActive = Color(0xFF10B981); // Green
  static const Color connectionInactive = Color(0xFFEF4444); // Red
  static const Color connectionDisabled = Color(0xFF6B7280); // Grey
  static const Color connectionUnconfigured = Color(0xFFF59E0B); // Orange
  static const Color selectionGlow = Color(0xFF00D4AA);

  // ─── Console ──────────────────────────────────────────────────
  static const Color consoleBackground = Color(0xFF0A0E14);
  static const Color consoleText = Color(0xFF00D4AA);
  static const Color consolePrompt = Color(0xFF7C3AED);
  static const Color consoleError = Color(0xFFEF4444);
  static const Color consoleWarning = Color(0xFFF59E0B);
}
