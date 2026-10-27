import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

part 'android_channel.mapper.dart';

const _methodChannel = MethodChannel('org.localsend.localsend_app/localsend');
final _logger = Logger('AndroidSaf');

/// From Android 10 and above, we need to use the Storage Access Framework (SAF) to access files due to the scoped storage.
/// SAF itself is available from Android 4.4 (API level 19).
/// We implemented our own algorithm to build encode and decode content URIs.
/// Older versions might also work but the encoded content URI is not guaranteed to work with our algorithm.
const contentUriMinSdk = 27;

Future<PickDirectoryResult?> pickDirectoryAndroid() async {
  final result = await _methodChannel.invokeMethod<Map>('pickDirectory');
  if (result == null) {
    return null;
  }

  return PickDirectoryResultMapper.fromJson({
    'directoryUri': result['directoryUri'],
    'files': (result['files'] as List).map((e) => FileInfoMapper.fromJson((e as Map).cast<String, dynamic>())).toList(),
  });
}

Future<String?> pickDirectoryPathAndroid() async {
  final result = await _methodChannel.invokeMethod<String>('pickDirectoryPath');
  return result;
}

Future<List<FileInfo>?> pickFilesAndroid() async {
  final result = await _methodChannel.invokeMethod<List>('pickFiles');
  if (result == null) {
    return null;
  }

  return result.map((e) => FileInfoMapper.fromJson((e as Map).cast<String, dynamic>())).toList();
}

/// Returns the global "Download" directory, e.g. /storage/emulated/0/Download.
Future<String?> getDownloadsDirectoryAndroid() async {
  try {
    return await _methodChannel.invokeMethod<String>('getDownloadsDirectory');
  } catch (e) {
    _logger.warning('Could not get downloads directory', e);
    return null;
  }
}

Future<bool> getSystemAnimationsStatusAndroid() async {
  return await _methodChannel.invokeMethod('isAnimationsEnabled') ?? true;
}

/// Requests the "Nearby devices" permission gating local network access on Android 17+.
/// Returns true when granted or when running on an older Android version.
Future<bool> requestLocalNetworkPermissionAndroid() async {
  try {
    return await _methodChannel.invokeMethod<bool>('requestLocalNetworkPermission') ?? false;
  } catch (e) {
    _logger.warning('Could not request local network permission', e);
    return false;
  }
}

Future<void> openContentUri({
  required String uri,
}) async {
  _logger.info('Opening content URI: $uri');
  await _methodChannel.invokeMethod('openContentUri', {
    'uri': uri,
  });
}

/// Tells MainActivity that the Dart side is now subscribed to the share_handler media stream,
/// so share intents that were held back during app start can be replayed.
Future<void> flushPendingShareIntentsAndroid() async {
  try {
    await _methodChannel.invokeMethod('shareIntentReady');
  } catch (e) {
    _logger.warning('Could not flush pending share intents', e);
  }
}

Future<void> openGallery() async {
  _logger.info('Opening gallery');
  await _methodChannel.invokeMethod('openGallery');
}

/// Callbacks MainActivity invokes for "Tap to share".
void setTapShareHandlersAndroid({
  required void Function(String identityJson) onRead,
  required void Function(String senderFingerprint) onTapped,
  required void Function(bool enabled) onEnabledChanged,
  required void Function() onSendPending,
  required void Function(String sessionId) onOpenSession,
}) {
  _methodChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onTapShareRead':
        onRead(call.arguments as String);
      case 'onTapShareTapped':
        onTapped(call.arguments as String);
      case 'onTapShareEnabledChanged':
        onEnabledChanged(call.arguments as bool);
      case 'onTapShareSendPending':
        onSendPending();
      case 'onTapShareOpenSession':
        onOpenSession(call.arguments as String);
    }
  });
}

/// The send the share sheet (TapShareActivity) is waiting for, as JSON {identity, files, text}, or null.
Future<String?> takeTapSharePendingSendAndroid() => _methodChannel.invokeMethod<String>('tapShareTakePendingSend');

/// Tells the share sheet how its send ended.
Future<void> reportTapShareSendResultAndroid({required String alias, required bool ok}) =>
    _methodChannel.invokeMethod('tapShareSendResult', {'alias': alias, 'ok': ok});

/// Progress of the share sheet send, for the sheet's progress bar.
Future<void> reportTapShareSendProgressAndroid({required String sessionId, required String alias, required int sent, required int total}) =>
    _methodChannel.invokeMethod('tapShareSendProgress', {'sessionId': sessionId, 'alias': alias, 'sent': sent, 'total': total});

/// Where the NFC antennas sit (Android 14+): device size and antenna centres in mm,
/// origin bottom-left as seen from the screen. Null when the phone does not say.
Future<({Size device, List<Offset> antennas})?> getNfcAntennaAndroid() async {
  final result = await _methodChannel.invokeMethod<Map>('tapShareGetAntenna');
  if (result == null) {
    return null;
  }
  final antennas = (result['antennas'] as List).cast<List>().map((a) => Offset((a[0] as num).toDouble(), (a[1] as num).toDouble())).toList();
  if (antennas.isEmpty) {
    return null;
  }
  return (device: Size((result['width'] as num).toDouble(), (result['height'] as num).toDouble()), antennas: antennas);
}

Future<bool> isNfcOnAndroid() async => await _methodChannel.invokeMethod<bool>('tapShareIsNfcOn') ?? false;

Future<void> openNfcSettingsAndroid() => _methodChannel.invokeMethod('tapShareOpenNfcSettings');

/// Asks to add the Tap to share Quick Settings tile (Android 13+). True once the tile is there.
Future<bool> requestTapShareTileAndroid() async => await _methodChannel.invokeMethod<bool>('tapShareRequestTile') ?? false;

/// A viewable content URI for a received file (gallery saves have no usable path), or null.
Future<String?> resolveReceivedFileAndroid({required String? path, required String name, required bool gallery}) =>
    _methodChannel.invokeMethod<String>('resolveReceivedFile', {'path': path, 'name': name, 'gallery': gallery});

/// JPEG preview of an image or video (content URI or file path) from Android 10+, else null.
Future<Uint8List?> loadThumbnailAndroid({required String source, required bool video, int size = 192}) =>
    _methodChannel.invokeMethod<Uint8List>('loadThumbnail', {'source': source, 'video': video, 'size': size});

/// Returns (available, enabled, autoAccept).
Future<(bool, bool, bool)> getTapShareStateAndroid() async {
  final result = (await _methodChannel.invokeMethod<Map>('tapShareGetState'))!;
  return (result['available'] as bool, result['enabled'] as bool, result['autoAccept'] as bool);
}

Future<void> setTapShareEnabledAndroid(bool enabled) => _methodChannel.invokeMethod('tapShareSetEnabled', enabled);

Future<void> setTapShareAutoAcceptAndroid(bool autoAccept) => _methodChannel.invokeMethod('tapShareSetAutoAccept', autoAccept);

/// The JSON this phone answers taps with, or null to stop answering.
Future<void> setTapShareIdentityAndroid(String? identityJson) => _methodChannel.invokeMethod('tapShareSetIdentity', identityJson);

/// Enables NFC reader mode (this phone sends) with our fingerprint, or disables it with null.
Future<void> setTapShareSenderAndroid(String? fingerprint) => _methodChannel.invokeMethod('tapShareSetSender', fingerprint);

/// Whether [fingerprint] tapped this (unlocked) phone moments ago. Single use: a match clears the tap.
Future<bool> consumeTapShareTapAndroid(String fingerprint) async {
  return await _methodChannel.invokeMethod<bool>('tapShareConsumeTap', fingerprint) ?? false;
}

@MappableClass()
class PickDirectoryResult with PickDirectoryResultMappable {
  final String directoryUri;
  final List<FileInfo> files;

  PickDirectoryResult({
    required this.directoryUri,
    required this.files,
  });
}

@MappableClass()
class FileInfo with FileInfoMappable {
  final String name;
  final int size;
  final String uri;

  /// RFC 3339 in UTC. Null when the document provider does not know it.
  final String? lastModified;

  FileInfo({
    required this.name,
    required this.size,
    required this.uri,
    required this.lastModified,
  });
}

/// Notification for a request that arrived while no UI exists (engine started headless by a tap).
Future<void> notifyIncomingAndroid(String text) => _methodChannel.invokeMethod('tapShareNotifyIncoming', text);

/// Result notification (with vibration) for a transfer received while no UI was on screen.
/// [path], [name] and [gallery] describe a single received file, which tapping the notification opens.
Future<void> notifyReceivedAndroid({required bool ok, required String text, String? path, String? name, bool gallery = false}) =>
    _methodChannel.invokeMethod('tapShareNotifyReceived', {'ok': ok, 'text': text, 'path': path, 'name': name, 'gallery': gallery});
