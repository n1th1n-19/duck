import 'dart:async';

import 'package:flutter/material.dart';

const _duration = Duration(milliseconds: 1100);
const _waves = 3;
const _stagger = 0.12; // fraction of the duration between waves

/// Plays an AirDrop-like wave rolling down from the top edge, where the two phones touch.
///
/// The global `timeDilation` set by animationProvider makes this instant when animations are disabled.
/// No-op without a [context], e.g. while the engine runs headless.
void showTapRipple(BuildContext? context) {
  final overlay = context == null ? null : Overlay.maybeOf(context, rootOverlay: true);
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

    for (var i = 0; i < _waves; i++) {
      final local = ((t - i * _stagger) / (1 - (_waves - 1) * _stagger)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) {
        continue;
      }
      final eased = Curves.easeOutCubic.transform(local);
      final radius = maxRadius * eased;
      final alpha = 0.9 * (1 - local);
      // flat rings, no gradients
      canvas.drawCircle(
        origin,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) => oldDelegate.color != color;
}
