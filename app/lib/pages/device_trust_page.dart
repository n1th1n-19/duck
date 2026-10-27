import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/provider/device_trust_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Manage trusted devices (favorites) and blocked devices.
class DeviceTrustPage extends StatelessWidget {
  const DeviceTrustPage();

  @override
  Widget build(BuildContext context) {
    final trusted = context.watch(favoritesProvider);
    final blocked = context.watch(blockedDevicesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.trust.title)),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          _Header(t.trust.trustedDevices),
          if (trusted.isEmpty) _Empty(t.trust.noTrusted),
          for (final device in trusted)
            _DeviceRow(
              device: device,
              icon: Icons.verified_user,
              actionLabel: t.trust.untrust,
              onAction: () async => context.global.dispatchAsync(UntrustDeviceAction(device.fingerprint)),
            ),
          const SizedBox(height: 20),
          _Header(t.trust.blockedDevices),
          if (blocked.isEmpty) _Empty(t.trust.noBlocked),
          for (final device in blocked)
            _DeviceRow(
              device: device,
              icon: Icons.block,
              actionLabel: t.trust.unblock,
              onAction: () async => context.global.dispatchAsync(UnblockDeviceAction(device.fingerprint)),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final FavoriteDevice device;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;

  const _DeviceRow({required this.device, required this.icon, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(device.alias),
      // Short fingerprint, enough to tell devices with the same name apart.
      subtitle: Text(device.fingerprint.length > 16 ? '${device.fingerprint.substring(0, 16)}…' : device.fingerprint),
      trailing: TextButton(onPressed: onAction, child: Text(actionLabel)),
    );
  }
}
