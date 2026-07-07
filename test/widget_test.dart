import 'package:flutter_test/flutter_test.dart';
import 'package:firelink/src/core/utils/ip_utils.dart';

void main() {
  group('IpUtils', () {
    test('validates correct IP addresses', () {
      expect(IpUtils.isValidIp('192.168.1.1'), true);
      expect(IpUtils.isValidIp('10.0.0.1'), true);
      expect(IpUtils.isValidIp('255.255.255.255'), true);
      expect(IpUtils.isValidIp('0.0.0.0'), true);
    });

    test('rejects invalid IP addresses', () {
      expect(IpUtils.isValidIp(''), false);
      expect(IpUtils.isValidIp('256.1.1.1'), false);
      expect(IpUtils.isValidIp('1.2.3'), false);
      expect(IpUtils.isValidIp('abc.def.ghi.jkl'), false);
    });

    test('checks same subnet correctly', () {
      expect(
        IpUtils.isInSameSubnet('192.168.1.1', '192.168.1.2', '255.255.255.0'),
        true,
      );
      expect(
        IpUtils.isInSameSubnet('192.168.1.1', '192.168.2.1', '255.255.255.0'),
        false,
      );
    });

    test('calculates network address', () {
      expect(
        IpUtils.getNetworkAddress('192.168.1.100', '255.255.255.0'),
        '192.168.1.0',
      );
    });
  });
}
