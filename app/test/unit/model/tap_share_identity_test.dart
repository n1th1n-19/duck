import 'dart:convert';

import 'package:localsend_app/model/tap_share_identity.dart';
import 'package:test/test.dart';

void main() {
  final fingerprint = 'A' * 64;

  test('round-trips', () {
    final identity = TapShareIdentity(alias: 'Phone', fingerprint: fingerprint, port: 53317, https: true, ips: ['192.168.1.2']);
    final decoded = TapShareIdentity.decode(identity.encode());

    expect(decoded.alias, 'Phone');
    expect(decoded.fingerprint, fingerprint);
    expect(decoded.port, 53317);
    expect(decoded.https, true);
    expect(decoded.ips, ['192.168.1.2']);
  });

  test('only accepts local network addresses', () {
    for (final ip in ['192.168.1.2', '10.0.0.1', '172.20.1.1', '169.254.3.4', '100.91.5.171', 'fe80::1%3', 'fd12::1']) {
      expect(isLanAddress(ip), true, reason: ip);
    }
    for (final ip in ['8.8.8.8', '172.32.0.1', '127.0.0.1', '2001:db8::1', 'example.com', '']) {
      expect(isLanAddress(ip), false, reason: ip);
    }
  });

  test('fits into one APDU with a long alias and many addresses', () {
    final identity = TapShareIdentity(
      alias: '😀 Very long device name ' * 10,
      fingerprint: fingerprint,
      port: 53317,
      https: true,
      ips: ['192.168.100.200', '10.100.200.100', '172.16.100.200', '192.168.1.1'],
    );
    final encoded = identity.encode();
    final decoded = TapShareIdentity.decode(encoded);

    expect(utf8.encode(encoded).length, lessThanOrEqualTo(TapShareIdentity.maxBytes));
    expect(decoded.ips, hasLength(TapShareIdentity.maxIps));
    expect(decoded.fingerprint, fingerprint);
    expect(decoded.alias, isNotEmpty);
  });
}
