import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/device_trust_provider.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Long-press menu of a nearby device: trust / remove trust, block.
Future<void> showDeviceTrustSheet(BuildContext context, Device device) async {
  final trusted = isTrustedDevice(context.ref, device.fingerprint);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(device.alias, style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          ListTile(
            leading: Icon(trusted ? Icons.remove_moderator : Icons.verified_user),
            title: Text(trusted ? t.trust.untrust : t.trust.trust),
            subtitle: trusted ? null : Text(t.trust.explanation),
            onTap: () async {
              Navigator.pop(sheetContext);
              await context.global.dispatchAsync(trusted ? UntrustDeviceAction(device.fingerprint) : TrustDeviceAction(device));
            },
          ),
          ListTile(
            leading: Icon(Icons.block, color: Theme.of(sheetContext).colorScheme.error),
            title: Text(t.trust.block),
            onTap: () async {
              Navigator.pop(sheetContext);
              await context.global.dispatchAsync(BlockDeviceAction(device));
              if (context.mounted) {
                context.showSnackBar(t.trust.blockedSnack(alias: device.alias));
              }
            },
          ),
        ],
      ),
    ),
  );
}
