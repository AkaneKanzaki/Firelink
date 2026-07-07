import 'package:flutter/material.dart';

import '../enums/device_type.dart';
import 'app_colors.dart';

/// Maps device types to their visual representation (icon + color).
class DeviceIcons {
  DeviceIcons._();

  /// Returns the Material icon for a given device type.
  static IconData getIcon(DeviceType type) {
    switch (type) {
      case DeviceType.router:
        return Icons.router;
      case DeviceType.switchDevice:
        return Icons.device_hub;
      case DeviceType.hub:
        return Icons.hub;
      case DeviceType.pc:
        return Icons.desktop_windows;
      case DeviceType.server:
        return Icons.dns;
      case DeviceType.laptop:
        return Icons.laptop;
      case DeviceType.isp:
        return Icons.cloud;
      case DeviceType.smartphone:
        return Icons.smartphone;
      case DeviceType.accessPoint:
        return Icons.wifi_tethering;
      case DeviceType.wirelessRouter:
        return Icons.wifi;
      case DeviceType.printer:
        return Icons.print;
      case DeviceType.ipPhone:
        return Icons.phone_in_talk;
      case DeviceType.firewall:
        return Icons.security;
    }
  }

  /// Returns the accent color for a given device type.
  static Color getColor(DeviceType type) {
    switch (type) {
      case DeviceType.router:
        return AppColors.routerColor;
      case DeviceType.switchDevice:
        return AppColors.switchColor;
      case DeviceType.hub:
        return AppColors.hubColor;
      case DeviceType.pc:
        return AppColors.pcColor;
      case DeviceType.server:
        return AppColors.serverColor;
      case DeviceType.laptop:
        return AppColors.laptopColor;
      case DeviceType.isp:
        return AppColors.ispColor;
      case DeviceType.smartphone:
        return AppColors.smartphoneColor;
      case DeviceType.accessPoint:
        return AppColors.accessPointColor;
      case DeviceType.wirelessRouter:
        return AppColors.wirelessRouterColor;
      case DeviceType.printer:
        return AppColors.printerColor;
      case DeviceType.ipPhone:
        return AppColors.ipPhoneColor;
      case DeviceType.firewall:
        return AppColors.firewallColor;
    }
  }

  /// Categorized device types available in the palette.
  static const Map<String, List<DeviceType>> paletteCategories = {
    'Network': [DeviceType.router, DeviceType.switchDevice, DeviceType.hub],
    'End Devices': [
      DeviceType.pc,
      DeviceType.laptop,
      DeviceType.server,
      DeviceType.smartphone,
      DeviceType.printer,
      DeviceType.ipPhone,
    ],
    'Wireless': [DeviceType.accessPoint, DeviceType.wirelessRouter],
    'WAN/Security': [DeviceType.firewall, DeviceType.isp],
  };
}
