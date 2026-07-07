import 'dart:math';

/// Utility class for IP address operations used in network simulation.
class IpUtils {
  IpUtils._();

  /// Validates whether [ip] is a valid IPv4 address.
  static bool isValidIp(String ip) {
    if (ip.isEmpty) return false;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  /// Validates whether [mask] is a valid subnet mask.
  static bool isValidSubnetMask(String mask) {
    if (!isValidIp(mask)) return false;
    final binary = _ipToBinary(mask);
    // A valid subnet mask has contiguous 1s followed by contiguous 0s.
    final regex = RegExp(r'^1*0*$');
    return regex.hasMatch(binary);
  }

  /// Checks if [ip1] and [ip2] are in the same subnet given [mask].
  static bool isInSameSubnet(String ip1, String ip2, String mask) {
    final net1 = getNetworkAddress(ip1, mask);
    final net2 = getNetworkAddress(ip2, mask);
    return net1 == net2;
  }

  /// Computes the network address from an [ip] and [mask].
  static String getNetworkAddress(String ip, String mask) {
    try {
      if (ip.isEmpty || mask.isEmpty) return '';
      final ipParts = ip.split('.').map(int.parse).toList();
      final maskParts = mask.split('.').map(int.parse).toList();
      if (ipParts.length != 4 || maskParts.length != 4) return '';

      final networkParts = List.generate(4, (i) => ipParts[i] & maskParts[i]);
      return networkParts.join('.');
    } catch (_) {
      return '';
    }
  }

  /// Computes the broadcast address from an [ip] and [mask].
  static String getBroadcastAddress(String ip, String mask) {
    try {
      if (ip.isEmpty || mask.isEmpty) return '';
      final ipParts = ip.split('.').map(int.parse).toList();
      final maskParts = mask.split('.').map(int.parse).toList();
      if (ipParts.length != 4 || maskParts.length != 4) return '';

      final broadcastParts = List.generate(
        4,
        (i) => ipParts[i] | (~maskParts[i] & 0xFF),
      );
      return broadcastParts.join('.');
    } catch (_) {
      return '';
    }
  }

  /// Generates a random MAC address (format AA:BB:CC:DD:EE:FF).
  static String generateMacAddress() {
    final rng = Random();
    final bytes = List.generate(6, (_) => rng.nextInt(256));
    // Set locally administered bit and clear multicast bit.
    bytes[0] = (bytes[0] | 0x02) & 0xFE;
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  /// Converts a CIDR prefix length (e.g., 24) to a subnet mask string.
  static String cidrToMask(int prefix) {
    if (prefix < 0 || prefix > 32) return '255.255.255.0';
    final mask = prefix == 0 ? 0 : (~0 << (32 - prefix)) & 0xFFFFFFFF;
    return [
      (mask >> 24) & 0xFF,
      (mask >> 16) & 0xFF,
      (mask >> 8) & 0xFF,
      mask & 0xFF,
    ].join('.');
  }

  /// Converts a subnet mask to CIDR prefix length.
  static int maskToCidr(String mask) {
    final binary = _ipToBinary(mask);
    return binary.replaceAll('0', '').length;
  }

  /// Converts an IP address to a 32-character binary string.
  static String _ipToBinary(String ip) {
    return ip
        .split('.')
        .map((part) => int.parse(part).toRadixString(2).padLeft(8, '0'))
        .join();
  }

  /// Converts an IP address string to a 32-bit integer for comparison.
  static int ipToInt(String ip) {
    final parts = ip.split('.').map(int.parse).toList();
    return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
  }

  /// Converts a 32-bit integer back to an IP address string.
  static String intToIp(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ].join('.');
  }
}
