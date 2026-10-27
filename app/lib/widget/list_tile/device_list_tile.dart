import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/list_tile/custom_list_tile.dart';
import 'package:localsend_isolates/model/device.dart';

class DeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;

  /// If not null, this name is used instead of [Device.alias].
  /// This is the case when the device is marked as favorite.
  final String? nameOverride;

  final String? info;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback? onDetailsTap;
  final VoidCallback? onLongPress;

  const DeviceListTile({
    required this.device,
    this.isFavorite = false,
    this.nameOverride,
    this.info,
    this.progress,
    this.onTap,
    this.onDetailsTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final details = [?device.deviceModel, if (device.ip != null) 'Wi-Fi' else 'WebRTC'].join(' · ');
    return CustomListTile(
      icon: CircleAvatar(
        radius: 24,
        backgroundColor: colors.surfaceContainerHigh,
        child: Icon(device.deviceType.icon, size: 26, color: colors.onSurface),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(nameOverride ?? device.alias, style: textTheme.titleMedium),
          if (isFavorite) ...[
            const SizedBox(width: 6),
            // Favorites are the trusted devices.
            Tooltip(
              message: t.trust.trusted,
              child: Icon(Icons.verified_user_rounded, size: 16, color: colors.primary),
            ),
          ],
        ],
      ),
      trailing: onDetailsTap != null
          ? IconButton(
              tooltip: t.deviceDetailsPage.title,
              icon: Icon(Icons.info_outline_rounded, color: colors.outline),
              onPressed: onDetailsTap,
            )
          : null,
      subTitle: info != null
          ? Text(info!, style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant))
          : progress != null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: CustomProgressBar(progress: progress!),
            )
          : Text(details, style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
