import 'dart:convert';

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
