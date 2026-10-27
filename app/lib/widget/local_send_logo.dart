import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// The Duck Share "Glide" mark, drawn from the same geometry as support/branding/duck.py.
/// [animate]: the duck bobs and the wake drifts, for "waiting for a transfer".
class LocalSendLogo extends StatefulWidget {
  final bool withText;
  final bool animate;
  final double size;

  const LocalSendLogo({required this.withText, this.animate = false, this.size = 200});

  @override
  State<LocalSendLogo> createState() => _LocalSendLogoState();
}

class _LocalSendLogoState extends State<LocalSendLogo> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LocalSendLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.animate && !_controller.isAnimating) {
      unawaited(_controller.repeat());
    } else if (!widget.animate && _controller.isAnimating) {
      // settle in the rest pose instead of freezing mid-bob
      unawaited(
        _controller.animateTo(1, duration: Duration(milliseconds: ((1 - _controller.value) * 600).round())).then((_) => _controller.value = 0),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Semantics(
      label: 'Duck Share',
      image: true,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _GlidePainter(_controller, Theme.of(context).colorScheme.primary),
      ),
    );

    if (!widget.withText) {
      return logo;
    }
    return Column(
      children: [
        logo,
        Text('Duck Share', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
      ],
    );
  }
}

class _GlidePainter extends CustomPainter {
  final Animation<double> t;
  final Color color;

  _GlidePainter(this.t, this.color) : super(repaint: t);

  // duck.py paths, in its 512 box (before the centring translate(-4 -52))
  static final _body = Path()
    ..moveTo(118, 232)
    ..quadraticBezierTo(116, 214, 134, 220)
    ..cubicTo(168, 236, 212, 256, 262, 256)
    ..cubicTo(322, 256, 370, 262, 394, 290)
    ..cubicTo(412, 312, 404, 342, 380, 358)
    ..cubicTo(350, 378, 310, 386, 262, 386)
    ..cubicTo(190, 386, 138, 362, 126, 320)
    ..cubicTo(118, 292, 116, 262, 118, 232)
    ..close();
  static final _head = Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: const Offset(320, 206), radius: 64))
    ..addOval(Rect.fromCircle(center: const Offset(336, 198), radius: 13));
  static final _bill = Path()
    ..moveTo(372, 198)
    ..cubicTo(394, 188, 424, 192, 436, 208)
    ..cubicTo(424, 226, 396, 232, 374, 224)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t.value * 2 * pi;
    canvas.scale(size.width / 512, size.height / 512);
    canvas.translate(-4, -52);

    final fill = Paint()..color = color;
    final wake = Paint()
      ..color = color
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;
    // the two wake lines slide in opposite phase, like water passing under the duck
    final d1 = sin(phase) * 14;
    final d2 = sin(phase + pi) * 14;
    canvas.drawLine(Offset(84 + d1, 426), Offset(196 + d1, 426), wake);
    canvas.drawLine(Offset(140 + d2, 462), Offset(236 + d2, 462), wake);

    canvas.save();
    // bob up and down with a slight nose tilt
    canvas.translate(0, sin(phase) * -8);
    canvas.translate(262, 300);
    canvas.rotate(sin(phase + pi / 2) * 0.03);
    canvas.translate(-262, -300);
    canvas.drawPath(_body, fill);
    canvas.drawPath(_head, fill);
    canvas.drawPath(_bill, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlidePainter old) => old.color != color;
}
