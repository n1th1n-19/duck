import 'dart:async';

import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Device trust: favorites are the trusted devices, plus an explicit blocklist.
///
/// Trusted devices send without a prompt and without the receive PIN, and their
/// text messages go straight to the clipboard. Blocked devices are declined and
/// hidden from the nearby list. Both are keyed by the TLS certificate fingerprint.
final blockedDevicesProvider = ReduxProvider<BlockedDevicesService, List<FavoriteDevice>>((ref) {
  return BlockedDevicesService(ref.read(persistenceProvider));
});

/// Stores blocked devices. Reuses [FavoriteDevice] because it holds the same fields.
class BlockedDevicesService extends ReduxNotifier<List<FavoriteDevice>> {
  final PersistenceService _persistence;

  BlockedDevicesService(this._persistence);

  @override
  List<FavoriteDevice> init() => _persistence.getBlockedDevices();
}

bool isTrustedDevice(Ref ref, String fingerprint) => ref.read(favoritesProvider).any((e) => e.fingerprint == fingerprint);

bool isBlockedDevice(Ref ref, String fingerprint) => ref.read(blockedDevicesProvider).any((e) => e.fingerprint == fingerprint);

FavoriteDevice _entry(Device device) => FavoriteDevice.fromValues(
  fingerprint: device.fingerprint,
  ip: device.ip ?? '',
  port: device.port,
  alias: device.alias,
);

/// Trusts [device]: adds it to favorites and lifts a block.
class TrustDeviceAction extends AsyncGlobalAction {
  final Device device;

  TrustDeviceAction(this.device);

  @override
  Future<void> reduce() async {
    await ref.redux(blockedDevicesProvider).dispatchAsync(_UnblockAction(device.fingerprint));
    if (!isTrustedDevice(ref, device.fingerprint)) {
      await ref.redux(favoritesProvider).dispatchAsync(AddFavoriteAction(_entry(device)));
    }
  }
}

/// Removes the trust (the favorite) of [fingerprint].
class UntrustDeviceAction extends AsyncGlobalAction {
  final String fingerprint;

  UntrustDeviceAction(this.fingerprint);

  @override
  Future<void> reduce() async {
    await ref.redux(favoritesProvider).dispatchAsync(RemoveFavoriteAction(deviceFingerprint: fingerprint));
  }
}

/// Blocks [device]. A blocked device cannot be trusted at the same time.
class BlockDeviceAction extends AsyncGlobalAction {
  final Device device;

  BlockDeviceAction(this.device);

  @override
  Future<void> reduce() async {
    await ref.redux(favoritesProvider).dispatchAsync(RemoveFavoriteAction(deviceFingerprint: device.fingerprint));
    await ref.redux(blockedDevicesProvider).dispatchAsync(_BlockAction(_entry(device)));
  }
}

class UnblockDeviceAction extends AsyncGlobalAction {
  final String fingerprint;

  UnblockDeviceAction(this.fingerprint);

  @override
  Future<void> reduce() async {
    await ref.redux(blockedDevicesProvider).dispatchAsync(_UnblockAction(fingerprint));
  }
}

class _BlockAction extends AsyncReduxAction<BlockedDevicesService, List<FavoriteDevice>> {
  final FavoriteDevice device;

  _BlockAction(this.device);

  @override
  Future<List<FavoriteDevice>> reduce() async {
    final updated = List<FavoriteDevice>.unmodifiable([
      ...state.where((e) => e.fingerprint != device.fingerprint),
      device,
    ]);
    await notifier._persistence.setBlockedDevices(updated);
    return updated;
  }
}

class _UnblockAction extends AsyncReduxAction<BlockedDevicesService, List<FavoriteDevice>> {
  final String fingerprint;

  _UnblockAction(this.fingerprint);

  @override
  Future<List<FavoriteDevice>> reduce() async {
    if (!state.any((e) => e.fingerprint == fingerprint)) {
      return state;
    }
    final updated = List<FavoriteDevice>.unmodifiable(state.where((e) => e.fingerprint != fingerprint));
    await notifier._persistence.setBlockedDevices(updated);
    return updated;
  }
}

/// Mirrors the trusted fingerprints into the Rust server, which lets them skip the PIN.
final _trustedFingerprintsProvider = ViewProvider<List<String>>(
  (ref) => ref.watch(favoritesProvider).map((e) => e.fingerprint).toList(),
  onChanged: (_, next, ref) => ref.redux(parentIsolateProvider).dispatch(IsolateHttpServerTrustedFingerprintsAction(fingerprints: next)),
);

/// Pushes the trusted fingerprints to the server isolate and keeps them in sync.
/// Call once after the isolates are set up.
void initDeviceTrust(Ref ref) {
  ref.redux(parentIsolateProvider).dispatch(IsolateHttpServerTrustedFingerprintsAction(fingerprints: ref.read(_trustedFingerprintsProvider)));
}
