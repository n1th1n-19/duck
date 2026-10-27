import 'dart:convert';
import 'dart:io';

/// Private, link-local or CGNAT (e.g. Tailscale) address. Anything else is not "the phone next to me".
bool isLanAddress(String ip) {
  final addr = InternetAddress.tryParse(ip.split('%').first);
  if (addr == null) {
    return false;
  }
  final b = addr.rawAddress;
  if (addr.type == InternetAddressType.IPv4) {
    return b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168) ||
        (b[0] == 169 && b[1] == 254) ||
        (b[0] == 100 && b[1] >= 64 && b[1] <= 127);
  }
  return (b[0] == 0xFE && (b[1] & 0xC0) == 0x80) || (b[0] & 0xFE) == 0xFC; // fe80::/10, fc00::/7
}

/// The identity a receiver hands out over NFC on "Tap to share".
///
/// Keys are short because the whole JSON must fit into a single short APDU response (< 256 bytes).
class TapShareIdentity {
  static const maxIps = 3;
  static const maxBytes = 240;

  final String alias;
  final String fingerprint;
  final int port;
  final bool https;
  final List<String> ips;

  const TapShareIdentity({
    required this.alias,
    required this.fingerprint,
    required this.port,
    required this.https,
    required this.ips,
  });

  /// Encodes at most [maxIps] addresses and shortens the alias until the JSON fits into [maxBytes].
  String encode() {
    var alias = this.alias;
    while (true) {
      final json = jsonEncode({
        'v': 1,
        'a': alias,
        'f': fingerprint,
        'p': port,
        'h': https,
        'i': ips.take(maxIps).toList(),
      });
      if (utf8.encode(json).length <= maxBytes || alias.isEmpty) {
        return json;
      }
      // Drop a whole code point so an emoji is never cut in half.
      alias = String.fromCharCodes(alias.runes.take(alias.runes.length - 1));
    }
  }

  factory TapShareIdentity.decode(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return TapShareIdentity(
      alias: map['a'] as String,
      fingerprint: map['f'] as String,
      port: map['p'] as int,
      https: map['h'] as bool,
      ips: (map['i'] as List).cast<String>(),
    );
  }
}
