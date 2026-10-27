import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

const _duration = Duration(milliseconds: 1100);
const _waves = 3;
const _stagger = 0.12; // fraction of the duration between waves

/// Plays an AirDrop-like wave rolling down from the top edge, where the two phones touch.
///
/// The global `timeDilation` set by animationProvider makes this instant when animations are disabled.
void showTapRipple(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _TapRipple(onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _TapRipple extends StatefulWidget {
  final VoidCallback onDone;

  const _TapRipple({required this.onDone});

  @override
  State<_TapRipple> createState() => _TapRippleState();
}

class _TapRippleState extends State<_TapRipple> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: _duration);

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward().whenComplete(widget.onDone));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _RipplePainter(_controller, Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;

  _RipplePainter(this.progress, this.color) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, 0);
    final maxRadius = size.height * 1.4;
    final t = progress.value;

    // Soft glow along the top edge at the moment of contact.
    final glow = (1 - t * 2).clamp(0.0, 1.0);
    if (glow > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              color.withValues(alpha: 0.35 * glow),
              color.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    for (var i = 0; i < _waves; i++) {
      final local = ((t - i * _stagger) / (1 - (_waves - 1) * _stagger)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) {
        continue;
      }
      final eased = Curves.easeOutCubic.transform(local);
      final radius = maxRadius * eased;
      final alpha = 0.9 * (1 - local);
      final width = 24.0 + 40 * eased;
      canvas.drawCircle(
        origin,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0),
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
            stops: [max(0, (radius - width) / (radius + width)), radius / (radius + width), 1],
          ).createShader(Rect.fromCircle(center: origin, radius: radius + width)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) => oldDelegate.color != color;
}
