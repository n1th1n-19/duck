import 'dart:async';

import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/tap_share_identity.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/http_provider.dart';
import 'package:localsend_app/provider/last_devices.provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/security_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/animations/tap_ripple_overlay.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/rust/api/model.dart';
import 'package:localsend_isolates/util/rust.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

final _logger = Logger('TapShare');

/// A tapped sender is auto-accepted when its upload request arrives within this window.
const tapShareAcceptWindow = Duration(seconds: 60);

/// The receiver may still be starting its server, so keep trying for a while.
const _registerTimeout = Duration(seconds: 10);
const _registerRetryInterval = Duration(milliseconds: 500);

class TapShareState {
  /// The device has NFC with host card emulation.
  final bool available;
  final bool enabled;
  final bool autoAccept;

  const TapShareState({required this.available, required this.enabled, required this.autoAccept});

  TapShareState copyWith({bool? enabled, bool? autoAccept}) {
    return TapShareState(available: available, enabled: enabled ?? this.enabled, autoAccept: autoAccept ?? this.autoAccept);
  }
}

/// "Tap to share" on Android: hold two phones together to send the selected files.
///
/// The native side (TapShareState.kt) owns the settings because the Quick Settings tile
/// and the NFC service must work without Flutter. This provider mirrors them.
final tapShareProvider = ReduxProvider<TapShareService, TapShareState>((ref) => TapShareService());

class TapShareService extends ReduxNotifier<TapShareState> {
  @override
  TapShareState init() => const TapShareState(available: false, enabled: false, autoAccept: false);
}

/// The identity this phone answers taps with; null while it cannot receive.
final _identityProvider = ViewProvider<String?>(
  (ref) {
    final enabled = ref.watch(tapShareProvider.select((s) => s.available && s.enabled));
    final server = ref.watch(serverProvider);
    if (!enabled || server == null) {
      return null;
    }
    return TapShareIdentity(
      alias: server.alias,
      fingerprint: ref.watch(securityProvider).certificateHash,
      port: server.port,
      https: server.https,
      ips: ref.watch(localIpProvider).localIps,
    ).encode();
  },
  onChanged: (_, next, ref) => unawaited(setTapShareIdentityAndroid(next)),
);

/// Our fingerprint while this phone should send on tap (files selected); null otherwise.
final _senderProvider = ViewProvider<String?>(
  (ref) {
    final enabled = ref.watch(tapShareProvider.select((s) => s.available && s.enabled));
    final hasFiles = ref.watch(selectedSendingFilesProvider.select((files) => files.isNotEmpty));
    if (!enabled || !hasFiles) {
      return null;
    }
    return ref.watch(securityProvider).certificateHash;
  },
  onChanged: (_, next, ref) => unawaited(setTapShareSenderAndroid(next)),
);

/// Loads the native state and starts syncing. Call once on app start (Android only).
Future<void> initTapShare(Ref ref) async {
  final (available, enabled, autoAccept) = await getTapShareStateAndroid();
  ref.redux(tapShareProvider).dispatch(_SetStateAction(TapShareState(available: available, enabled: enabled, autoAccept: autoAccept)));
  setTapShareHandlersAndroid(
    onRead: (json) => ref.global.dispatchAsync(TapShareSendAction(TapShareIdentity.decode(json))),
    onTapped: (fingerprint) {
      _logger.info('Tapped by $fingerprint');
      unawaited(HapticFeedback.heavyImpact());
      showTapRipple(Routerino.context);
    },
    onEnabledChanged: (enabled) => ref.redux(tapShareProvider).dispatch(_SetStateAction(ref.read(tapShareProvider).copyWith(enabled: enabled))),
  );

  // Reading initializes the view providers; later changes are pushed by their onChanged.
  await setTapShareIdentityAndroid(ref.read(_identityProvider));
  await setTapShareSenderAndroid(ref.read(_senderProvider));
}

class _SetStateAction extends ReduxAction<TapShareService, TapShareState> {
  final TapShareState newState;

  _SetStateAction(this.newState);

  @override
  TapShareState reduce() => newState;
}

class SetTapShareEnabledAction extends AsyncReduxAction<TapShareService, TapShareState> {
  final bool enabled;

  SetTapShareEnabledAction(this.enabled);

  @override
  Future<TapShareState> reduce() async {
    await setTapShareEnabledAndroid(enabled);
    return state.copyWith(enabled: enabled);
  }
}

class SetTapShareAutoAcceptAction extends AsyncReduxAction<TapShareService, TapShareState> {
  final bool autoAccept;

  SetTapShareAutoAcceptAction(this.autoAccept);

  @override
  Future<TapShareState> reduce() async {
    await setTapShareAutoAcceptAndroid(autoAccept);
    return state.copyWith(autoAccept: autoAccept);
  }
}

/// Whether an upload request from [senderFingerprint] follows a tap and may skip the prompt.
Future<bool> isRecentlyTappedSender(Ref ref, String senderFingerprint) async {
  final state = ref.read(tapShareProvider);
  if (!state.available || !state.enabled || !state.autoAccept) {
    return false;
  }
  final lastTap = await getTapShareLastTapAndroid();
  return lastTap != null && lastTap.$1 == senderFingerprint && DateTime.now().difference(lastTap.$2) < tapShareAcceptWindow;
}

/// We read the identity of a tapped phone: send the selected files to it.
class TapShareSendAction extends AsyncGlobalAction {
  final TapShareIdentity identity;

  TapShareSendAction(this.identity);

  @override
  Future<void> reduce() async {
    final files = ref.read(selectedSendingFilesProvider);
    if (files.isEmpty) {
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
    showTapRipple(Routerino.context);

    final device = await _register();
    // Routerino.context is the navigator's current context, so it is fresh after the await.
    final context = Routerino.context;
    if (device == null) {
      if (context.mounted) {
        context.showSnackBar(t.tapShare.unreachable(alias: identity.alias));
      }
      return;
    }

    ref.redux(lastDevicesProvider).dispatch(AddLastDeviceAction(device));
    if (context.mounted) {
      context.showSnackBar(t.tapShare.sending(alias: device.alias));
    }

    // The first tap opens the send page; further taps (more receivers) run in the background.
    final background = ref.read(sendProvider).values.any((s) => !s.background);
    await ref.notifier(sendProvider).startSession(target: device, files: files, background: background);
  }

  /// Finds the address the receiver answers on. The client is pinned to the fingerprint read over NFC.
  Future<Device?> _register() async {
    final client = ref.read(httpProvider).pinnedTo(identity.fingerprint);
    final payload = ref.read(deviceFullInfoProvider).toRegisterDto();
    final protocol = identity.https ? ProtocolType.https : ProtocolType.http;
    final deadline = DateTime.now().add(_registerTimeout);

    while (DateTime.now().isBefore(deadline)) {
      for (final ip in identity.ips) {
        try {
          final response = await client.register(protocol: protocol, ip: ip, port: identity.port, payload: payload);
          return response.body.toDevice(ip, identity.port, identity.https);
        } catch (e) {
          _logger.fine('Register at $ip failed', e);
        }
      }
      await Future.delayed(_registerRetryInterval);
    }
    return null;
  }
}
