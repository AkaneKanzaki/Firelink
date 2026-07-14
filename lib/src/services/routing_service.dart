import '../core/utils/ip_utils.dart';
import '../models/routing_entry.dart';

/// Handles static route lookup with longest-prefix-match algorithm.
class RoutingService {
  RoutingService._();

  /// Looks up the best matching route in [routingTable] for [destIp].
  ///
  /// Uses longest-prefix-match: the route with the most specific subnet mask wins.
  /// Returns null if no matching route is found.
  static RoutingEntry? lookupRoute(
    List<RoutingEntry> routingTable,
    String destIp,
  ) {
    if (!IpUtils.isValidIp(destIp)) return null;

    RoutingEntry? bestMatch;
    int bestPrefix = -1;

    for (final entry in routingTable) {
      if (IpUtils.isInSameSubnet(destIp, entry.destination, entry.subnetMask)) {
        final prefix = IpUtils.maskToCidr(entry.subnetMask);
        if (prefix > bestPrefix) {
          bestPrefix = prefix;
          bestMatch = entry;
        }
      }
    }

    return bestMatch;
  }

  /// Generates "connected" routes automatically from active interfaces.
  ///
  /// For each interface with a configured IP address, creates a routing entry
  /// for its directly-connected network.
  static List<RoutingEntry> generateConnectedRoutes(List<dynamic> interfaces) {
    final routes = <RoutingEntry>[];

    for (final iface in interfaces) {
      if (iface.ipAddress.isNotEmpty &&
          iface.status.toString().endsWith('up')) {
        final networkAddr = IpUtils.getNetworkAddress(
          iface.ipAddress,
          iface.subnetMask,
        );
        routes.add(
          RoutingEntry(
            destination: networkAddr,
            subnetMask: iface.subnetMask,
            nextHop: '0.0.0.0', // Directly connected
            exitInterface: iface.name,
          ),
        );
      }
    }

    return routes;
  }
}
