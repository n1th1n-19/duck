import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Typical phone back when Android does not report its antenna: 72 x 160 mm, NFC upper middle.
const _fallbackDevice = Size(72, 160);
const _fallbackSpot = Offset(36, 104);

/// Asked once per app run; the hardware does not change.
Future<({Size device, List<Offset> antennas})?>? _antenna;

/// The back of this phone with a pulsing spot where its NFC antenna is.
class NfcSpotGuide extends StatefulWidget {
  final double height;

  /// Show the explanation below the phone.
  final bool withCaption;

  const NfcSpotGuide({this.height = 200, this.withCaption = true});

  @override
  State<NfcSpotGuide> createState() => _NfcSpotGuideState();
}

class _NfcSpotGuideState extends State<NfcSpotGuide> with SingleTickerProviderStateMixin, Refena {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  final _future = _antenna ??= getNfcAntennaAndroid().catchError((_) => null);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch(animationProvider)) {
      if (!_pulse.isAnimating) {
        unawaited(_pulse.repeat());
      }
    } else {
      _pulse.stop();
      _pulse.value = 0.35;
    }

    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        final antenna = snapshot.data;
        final device = antenna?.device ?? _fallbackDevice;
        // seen from the back, left and right swap
        final spots = (antenna?.antennas ?? const [_fallbackSpot]).map((a) => Offset(device.width - a.dx, device.height - a.dy)).toList();
        final colors = Theme.of(context).colorScheme;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: t.tapShare.guide.back,
              image: true,
              child: CustomPaint(
                size: Size(widget.height * device.width / device.height, widget.height),
                painter: _PhoneBackPainter(_pulse, device, spots, colors),
              ),
            ),
            if (widget.withCaption) ...[
              const SizedBox(height: 16),
              Text(
                antenna != null ? t.tapShare.guide.exact : t.tapShare.guide.approximate,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PhoneBackPainter extends CustomPainter {
  final Animation<double> pulse;
  final Size device;
  final List<Offset> spots;
  final ColorScheme colors;

  _PhoneBackPainter(this.pulse, this.device, this.spots, this.colors) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final mm = size.height / device.height;
    final body = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(9 * mm));
    canvas.drawRRect(body, Paint()..color = colors.surfaceContainerHigh);
    canvas.drawRRect(
      body.deflate(1),
      Paint()
        ..color = colors.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // camera, top left as seen from the back on most phones
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(7 * mm, 7 * mm, 16 * mm, 16 * mm), Radius.circular(5 * mm)),
      Paint()..color = colors.outlineVariant,
    );

    final ring = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final spot in spots) {
      final center = Offset(spot.dx * mm, spot.dy * mm);
      for (var i = 0; i < 3; i++) {
        final t = (pulse.value + i / 3) % 1;
        ring.color = colors.primary.withValues(alpha: (1 - t) * 0.8);
        canvas.drawCircle(center, (6 + t * 22) * mm, ring);
      }
      canvas.drawCircle(center, 6 * mm, Paint()..color = colors.primary);
      // small radio arcs, the NFC glyph
      final arc = Paint()
        ..color = colors.onPrimary
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(1.5, 0.9 * mm);
      for (final r in [1.6, 3.2]) {
        canvas.drawArc(Rect.fromCircle(center: center.translate(-1.6 * mm, 0), radius: r * mm), -pi / 4, pi / 2, false, arc);
      }
    }
  }

  @override
  bool shouldRepaint(_PhoneBackPainter old) => old.device != device || old.spots != spots || old.colors != colors;
}

/// Bottom sheet: where to touch the phones.
Future<void> showNfcSpotGuide(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.tapShare.guide.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            const NfcSpotGuide(height: 240),
          ],
        ),
      ),
    ),
  );
}
