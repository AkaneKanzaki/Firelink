import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/device_icons.dart';
import '../core/enums/acl_enums.dart';
import '../core/enums/device_type.dart';
import '../core/enums/interface_status.dart';
import '../core/utils/ip_utils.dart';
import '../models/acl_rule.dart';
import '../models/routing_entry.dart';
import '../providers/simulation_provider.dart';
import '../providers/topology_provider.dart';

/// Full-screen device configuration with tabs for Interfaces, Routing, and Info.
class DeviceConfigScreen extends StatefulWidget {
  final String deviceId;

  const DeviceConfigScreen({super.key, required this.deviceId});

  @override
  State<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends State<DeviceConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topology = context.watch<TopologyProvider>();
    final device = topology.devices
        .where((d) => d.id == widget.deviceId)
        .firstOrNull;

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device Not Found')),
        body: const Center(child: Text('This device has been removed.')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = DeviceIcons.getColor(device.type);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(DeviceIcons.getIcon(device.type), color: color, size: 22),
            const SizedBox(width: 10),
            Text(device.hostname),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: color,
          labelColor: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          unselectedLabelColor: isDark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
          tabs: [
            const Tab(text: 'Interfaces'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Routing'),
                  if (!device.type.canRoute) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock_outline,
                      size: 12,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Services'),
                  if (!device.type.hasServices) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock_outline,
                      size: 12,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Info'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InterfacesTab(deviceId: widget.deviceId),
          _RoutingTab(deviceId: widget.deviceId),
          _ServicesTab(deviceId: widget.deviceId),
          _InfoTab(deviceId: widget.deviceId),
        ],
      ),
    );
  }
}

// ─── Interfaces Tab ───────────────────────────────────────────────────────────

class _InterfacesTab extends StatelessWidget {
  final String deviceId;
  const _InterfacesTab({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final topology = context.watch<TopologyProvider>();
    final device = topology.devices.firstWhere((d) => d.id == deviceId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: device.interfaces.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final iface = device.interfaces[index];
        return _InterfaceCard(
          deviceId: deviceId,
          deviceType: device.type,
          iface: iface,
          isDark: isDark,
        );
      },
    );
  }
}

class _InterfaceCard extends StatefulWidget {
  final String deviceId;
  final DeviceType deviceType;
  final dynamic iface;
  final bool isDark;

  const _InterfaceCard({
    required this.deviceId,
    required this.deviceType,
    required this.iface,
    required this.isDark,
  });

  @override
  State<_InterfaceCard> createState() => _InterfaceCardState();
}

class _InterfaceCardState extends State<_InterfaceCard> {
  late TextEditingController _ipController;
  late TextEditingController _maskController;
  late TextEditingController _gatewayController;
  late TextEditingController _dnsController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.iface.ipAddress);
    _maskController = TextEditingController(text: widget.iface.subnetMask);
    _gatewayController = TextEditingController(
      text: widget.iface.defaultGateway ?? '',
    );
    _dnsController = TextEditingController(text: widget.iface.dnsServer ?? '');
  }

  @override
  void didUpdateWidget(covariant _InterfaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iface.ipAddress != widget.iface.ipAddress) {
      _ipController.text = widget.iface.ipAddress;
    }
    if (oldWidget.iface.subnetMask != widget.iface.subnetMask) {
      _maskController.text = widget.iface.subnetMask;
    }
    if (oldWidget.iface.defaultGateway != widget.iface.defaultGateway) {
      _gatewayController.text = widget.iface.defaultGateway ?? '';
    }
    if (oldWidget.iface.dnsServer != widget.iface.dnsServer) {
      _dnsController.text = widget.iface.dnsServer ?? '';
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _maskController.dispose();
    _gatewayController.dispose();
    _dnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.iface.status == InterfaceStatus.up
        ? AppColors.linkUp
        : widget.iface.status == InterfaceStatus.down
        ? AppColors.linkDown
        : AppColors.linkDisabled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.iface.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // Status toggle
                Switch(
                  value: widget.iface.status == InterfaceStatus.up,
                  onChanged: (value) {
                    context.read<TopologyProvider>().configureInterface(
                      widget.deviceId,
                      widget.iface.name,
                      status: value
                          ? InterfaceStatus.up
                          : InterfaceStatus.disabled,
                    );
                  },
                ),
              ],
            ),
            if (widget.iface.isConnected) ...[
              const SizedBox(height: 4),
              Text(
                'Connected',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.linkUp.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            // Device Type Logic:
            // L2: Switch, Hub, Access Point (No IP Config)
            // L3: Router, Firewall, ISP, Wireless Router (IP, Subnet)
            // End Device: PC, Laptop, Server, Smartphone, Printer, IP Phone (IP, Subnet, Gateway)
            const SizedBox(height: 16),

            if (widget.deviceType.isLayer2Only) ...[
              // Layer 2 Devices
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Layer 2 Port (No IP Configuration Required)',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              // Layer 3 and End Devices
              if (widget.deviceType.requiresDefaultGateway) ...[
                // IP Configuration Mode (Static vs DHCP)
                Row(
                  children: [
                    const Text(
                      'IP Configuration: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Static'),
                        ),
                        ButtonSegment<bool>(value: true, label: Text('DHCP')),
                      ],
                      selected: <bool>{widget.iface.isDhcpClient},
                      onSelectionChanged: (Set<bool> newSelection) {
                        context.read<TopologyProvider>().configureInterface(
                          widget.deviceId,
                          widget.iface.name,
                          isDhcpClient: newSelection.first,
                        );
                      },
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                if (widget.iface.isDhcpClient) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.wifi_find, size: 16),
                      label: const Text('Request DHCP'),
                      onPressed:
                          widget.iface.isConnected &&
                              widget.iface.status == InterfaceStatus.up
                          ? () async {
                              // Trigger animation & backend simulation
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Requesting DHCP IP...'),
                                ),
                              );
                              final result = await context
                                  .read<SimulationProvider>()
                                  .startDhcpRequest(
                                    sourceDeviceId: widget.deviceId,
                                    interfaceName: widget.iface.name,
                                    devices: context
                                        .read<TopologyProvider>()
                                        .devices,
                                    connections: context
                                        .read<TopologyProvider>()
                                        .connections,
                                  );

                              if (result.success && context.mounted) {
                                context
                                    .read<TopologyProvider>()
                                    .configureInterface(
                                      widget.deviceId,
                                      widget.iface.name,
                                      ipAddress: result.assignedIp,
                                      subnetMask: result.subnetMask,
                                      defaultGateway: result.defaultGateway,
                                      dnsServer: result.dnsServer,
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'DHCP Successful: ${result.assignedIp}',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'DHCP Request Failed or Timed Out.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],

              // IP Address field
              _buildIpField(
                context,
                label: 'IP Address',
                controller: _ipController,
                readOnly: widget.iface.isDhcpClient,
                onSubmitted: (value) {
                  if (!widget.iface.isDhcpClient &&
                      (value.isEmpty || IpUtils.isValidIp(value))) {
                    context.read<TopologyProvider>().configureInterface(
                      widget.deviceId,
                      widget.iface.name,
                      ipAddress: value,
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              // Subnet Mask field
              _buildIpField(
                context,
                label: 'Subnet Mask',
                controller: _maskController,
                readOnly: widget.iface.isDhcpClient,
                onSubmitted: (value) {
                  if (!widget.iface.isDhcpClient &&
                      IpUtils.isValidSubnetMask(value)) {
                    context.read<TopologyProvider>().configureInterface(
                      widget.deviceId,
                      widget.iface.name,
                      subnetMask: value,
                    );
                  }
                },
              ),

              // Default Gateway
              if (widget.deviceType.requiresDefaultGateway) ...[
                const SizedBox(height: 12),
                _buildIpField(
                  context,
                  label: 'Default Gateway',
                  controller: _gatewayController,
                  readOnly: widget.iface.isDhcpClient,
                  onSubmitted: (value) {
                    if (!widget.iface.isDhcpClient &&
                        (value.isEmpty || IpUtils.isValidIp(value))) {
                      context.read<TopologyProvider>().configureInterface(
                        widget.deviceId,
                        widget.iface.name,
                        defaultGateway: value,
                      );
                    }
                  },
                ),
              ],

              // DNS Server
              if (widget.deviceType.requiresDnsServer) ...[
                const SizedBox(height: 12),
                _buildIpField(
                  context,
                  label: 'DNS Server',
                  controller: _dnsController,
                  readOnly: widget.iface.isDhcpClient,
                  onSubmitted: (value) {
                    if (!widget.iface.isDhcpClient &&
                        (value.isEmpty || IpUtils.isValidIp(value))) {
                      context.read<TopologyProvider>().configureInterface(
                        widget.deviceId,
                        widget.iface.name,
                        dnsServer: value,
                      );
                    }
                  },
                ),
              ],
            ],

            const SizedBox(height: 16),
            // MAC Address display
            Text(
              'MAC: ${widget.iface.macAddress}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onSubmitted,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        hintText: '0.0.0.0',
      ),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      onSubmitted: (value) {
        onSubmitted(value);
        FocusScope.of(context).unfocus();
      },
      onEditingComplete: () {
        onSubmitted(controller.text);
        FocusScope.of(context).unfocus();
      },
    );
  }
}

// ─── Routing Tab ──────────────────────────────────────────────────────────────

class _RoutingTab extends StatelessWidget {
  final String deviceId;
  const _RoutingTab({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final topology = context.watch<TopologyProvider>();
    final device = topology.devices.firstWhere((d) => d.id == deviceId);

    if (!device.type.canRoute) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Routing not available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${device.type.displayName} devices cannot perform routing.\nOnly Routers support routing tables.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // Add route button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAddRouteDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Static Route'),
            ),
          ),
        ),
        // Routing table
        if (device.routingTable.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alt_route_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Static Routes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a route to direct traffic to other networks.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: device.routingTable.length,
            itemBuilder: (context, index) {
              final entry = device.routingTable[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.route, size: 20),
                  title: Text(
                    '${entry.destination}/${IpUtils.maskToCidr(entry.subnetMask)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    'via ${entry.nextHop} → ${entry.exitInterface}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.linkDown,
                    ),
                    onPressed: () {
                      device.routingTable.removeAt(index);
                      // Force rebuild
                      topology.configureInterface(
                        deviceId,
                        device.interfaces.first.name,
                      );
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showAddRouteDialog(BuildContext context) {
    final destCtrl = TextEditingController();
    final maskCtrl = TextEditingController();
    final hopCtrl = TextEditingController();
    final ifaceCtrl = TextEditingController();

    final topology = context.read<TopologyProvider>();
    final device = topology.devices.firstWhere((d) => d.id == deviceId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Add Static Route'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: destCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination Network',
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maskCtrl,
                  decoration: const InputDecoration(labelText: 'Subnet Mask'),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hopCtrl,
                  decoration: const InputDecoration(labelText: 'Next Hop'),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Exit Interface',
                  ),
                  items: device.interfaces
                      .map(
                        (iface) => DropdownMenuItem(
                          value: iface.name,
                          child: Text(
                            iface.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => ifaceCtrl.text = value ?? '',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (IpUtils.isValidIp(destCtrl.text) &&
                  IpUtils.isValidSubnetMask(maskCtrl.text) &&
                  IpUtils.isValidIp(hopCtrl.text) &&
                  ifaceCtrl.text.isNotEmpty) {
                device.routingTable.add(
                  RoutingEntry(
                    destination: destCtrl.text,
                    subnetMask: maskCtrl.text,
                    nextHop: hopCtrl.text,
                    exitInterface: ifaceCtrl.text,
                  ),
                );
                // Force topology rebuild
                topology.configureInterface(
                  deviceId,
                  device.interfaces.first.name,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Route'),
          ),
        ],
      ),
    ).then((_) {
      destCtrl.dispose();
      maskCtrl.dispose();
      hopCtrl.dispose();
      ifaceCtrl.dispose();
    });
  }
}

// ─── Services Tab ─────────────────────────────────────────────────────────────

class _ServicesTab extends StatelessWidget {
  final String deviceId;
  const _ServicesTab({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final topology = context.watch<TopologyProvider>();
    final device = topology.devices.firstWhere((d) => d.id == deviceId);
    
    final showDhcp = device.type.supportsDhcp;
    final showAcl = device.type.supportsAcl;

    if (!device.type.hasServices && device.type != DeviceType.isp) {
      return const Center(
        child: Text('Services not available on this device type.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (device.type == DeviceType.isp) ...[
          const ListTile(
            title: Text('Internet/Cloud Services', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'This ISP node automatically routes traffic to the simulated internet.\n'
              'To test internet connectivity, use the PDU tool from any configured PC and ping an external IP (e.g., 8.8.8.8) or setup a route pointing to this ISP.'
            ),
          ),
          const Divider(),
          const SizedBox(height: 16),
        ],

        if (showDhcp && device.dhcpServerConfig != null) ...[
          const Text(
            'DHCP Server',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable DHCP Server'),
            subtitle: const Text(
              'Automatically assign IP addresses to clients.',
            ),
            value: device.dhcpServerConfig!.isEnabled,
            onChanged: (val) {
              device.dhcpServerConfig!.isEnabled = val;
              topology.configureInterface(
                deviceId,
                device.interfaces.first.name,
              ); // hack to notify
            },
          ),
          if (device.dhcpServerConfig!.isEnabled) ...[
            const Divider(),
            _buildTextField(
              'Pool Start IP',
              device.dhcpServerConfig!.poolStartIp,
              (val) => device.dhcpServerConfig!.poolStartIp = val,
              topology,
              deviceId,
            ),
            _buildTextField(
              'Pool End IP',
              device.dhcpServerConfig!.poolEndIp,
              (val) => device.dhcpServerConfig!.poolEndIp = val,
              topology,
              deviceId,
            ),
            _buildTextField(
              'Subnet Mask',
              device.dhcpServerConfig!.subnetMask,
              (val) => device.dhcpServerConfig!.subnetMask = val,
              topology,
              deviceId,
            ),
            _buildTextField(
              'Default Gateway',
              device.dhcpServerConfig!.defaultGateway,
              (val) => device.dhcpServerConfig!.defaultGateway = val,
              topology,
              deviceId,
            ),
            _buildTextField(
              'DNS Server',
              device.dhcpServerConfig!.dnsServer,
              (val) => device.dhcpServerConfig!.dnsServer = val,
              topology,
              deviceId,
            ),
            const SizedBox(height: 16),
            const Text(
              'Leased IPs:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...device.dhcpServerConfig!.leasedIps.entries.map(
              (e) => ListTile(
                dense: true,
                title: Text(e.value),
                subtitle: Text('MAC: ${e.key}'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
        ],

        if (showAcl) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Access Control List (ACL)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAddAclRuleDialog(context, device),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Rule'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Default Policy: Deny All'),
            subtitle: Text(
              device.aclDefaultDeny
                  ? 'Traffic not matching any rule will be DENIED.'
                  : 'Traffic not matching any rule will be PERMITTED.',
            ),
            value: device.aclDefaultDeny,
            onChanged: (val) {
              topology.toggleAclDefaultPolicy(deviceId);
            },
          ),
          const SizedBox(height: 12),
          if (device.aclRules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No ACL rules configured. Defaults apply.'),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: device.aclRules.length,
              onReorderItem: (oldIndex, newIndex) {
                topology.reorderAclRules(deviceId, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final rule = device.aclRules[index];
                return Card(
                  key: ValueKey(rule.id),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(
                        Icons.drag_indicator,
                        color: Colors.grey,
                      ),
                    ),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: rule.action == AclAction.permit
                                ? AppColors.linkUp
                                : AppColors.linkDown,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rule.action.displayName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${rule.sourceIp == 'any' ? 'any' : '${rule.sourceIp}/${rule.sourceWildcard}'} \u2192 ${rule.destIp == 'any' ? 'any' : '${rule.destIp}/${rule.destWildcard}'}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text('Protocol: ${rule.protocol.displayName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: rule.isEnabled,
                          onChanged: (val) {
                            topology.updateAclRule(
                              deviceId,
                              rule.id,
                              rule.copyWith(isEnabled: val),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.linkDown,
                          ),
                          onPressed: () {
                            topology.removeAclRule(deviceId, rule.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  void _showAddAclRuleDialog(BuildContext context, dynamic device) {
    final topology = context.read<TopologyProvider>();
    AclAction selectedAction = AclAction.permit;
    AclProtocol selectedProtocol = AclProtocol.any;

    final srcIpCtrl = TextEditingController(text: 'any');
    final srcMaskCtrl = TextEditingController(text: '0.0.0.0');
    final dstIpCtrl = TextEditingController(text: 'any');
    final dstMaskCtrl = TextEditingController(text: '0.0.0.0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: const Text('Add ACL Rule'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AclAction>(
                  initialValue: selectedAction,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: AclAction.values
                      .map(
                        (a) => DropdownMenuItem(
                          value: a,
                          child: Text(a.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => selectedAction = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: srcIpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Source IP (or "any")',
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                if (srcIpCtrl.text != 'any') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: srcMaskCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Source Wildcard Mask',
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: dstIpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination IP (or "any")',
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                if (dstIpCtrl.text != 'any') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: dstMaskCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Destination Wildcard Mask',
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<AclProtocol>(
                  initialValue: selectedProtocol,
                  decoration: const InputDecoration(labelText: 'Protocol'),
                  items: AclProtocol.values
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final rule = AclRule.create(
                  action: selectedAction,
                  protocol: selectedProtocol,
                  sourceIp: srcIpCtrl.text,
                  sourceWildcard: srcMaskCtrl.text,
                  destIp: dstIpCtrl.text,
                  destWildcard: dstMaskCtrl.text,
                );
                topology.addAclRule(device.id, rule);
                Navigator.pop(ctx);
              },
              child: const Text('Add Rule'),
            ),
          ],
        ),
      ),
    ).then((_) {
      srcIpCtrl.dispose();
      srcMaskCtrl.dispose();
      dstIpCtrl.dispose();
      dstMaskCtrl.dispose();
    });
  }

  Widget _buildTextField(
    String label,
    String value,
    Function(String) onChanged,
    TopologyProvider topology,
    String deviceId,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        style: const TextStyle(fontFamily: 'monospace'),
        onChanged: onChanged,
      ),
    );
  }
}

// ─── Info Tab ─────────────────────────────────────────────────────────────────

class _InfoTab extends StatefulWidget {
  final String deviceId;
  const _InfoTab({required this.deviceId});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> {
  late TextEditingController _hostnameCtrl;

  @override
  void initState() {
    super.initState();
    final topology = context.read<TopologyProvider>();
    final device = topology.devices.firstWhere((d) => d.id == widget.deviceId);
    _hostnameCtrl = TextEditingController(text: device.hostname);
  }

  @override
  void dispose() {
    _hostnameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topology = context.watch<TopologyProvider>();
    final device = topology.devices.firstWhere((d) => d.id == widget.deviceId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hostname
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hostname',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _hostnameCtrl,
                  decoration: const InputDecoration(hintText: 'Enter hostname'),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      topology.updateHostname(widget.deviceId, value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Device Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Information',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 12),
                _infoRow('Type', device.type.displayName),
                _infoRow('Device ID', device.id.substring(0, 8)),
                _infoRow('Total Ports', '${device.interfaces.length}'),
                _infoRow('Connected Ports', '${device.connectedPortCount}'),
                _infoRow('Can Route', device.type.canRoute ? 'Yes' : 'No'),
                _infoRow('Can Switch', device.type.canSwitch ? 'Yes' : 'No'),
                _infoRow(
                  'Position',
                  '(${device.position.dx.toInt()}, ${device.position.dy.toInt()})',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
