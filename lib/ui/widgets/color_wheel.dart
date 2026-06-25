import 'dart:math' as math;

import 'package:flutter/material.dart';

class ColorWheel extends StatelessWidget {
  final double hue;
  final double saturation;
  final double brightness;
  final ValueChanged<double> onHueChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<double> onBrightnessChanged;

  const ColorWheel({
    super.key,
    required this.hue,
    required this.saturation,
    required this.brightness,
    required this.onHueChanged,
    required this.onSaturationChanged,
    required this.onBrightnessChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: _WheelCanvas(
            hue: hue,
            saturation: saturation,
            onChanged: (h, s) {
              onHueChanged(h);
              onSaturationChanged(s);
            },
          ),
        ),
        const SizedBox(height: 16),
        _BrightnessSlider(value: brightness, onChanged: onBrightnessChanged),
      ],
    );
  }
}

class _WheelCanvas extends StatefulWidget {
  final double hue;
  final double saturation;
  final void Function(double hue, double sat) onChanged;

  const _WheelCanvas({required this.hue, required this.saturation, required this.onChanged});

  @override
  State<_WheelCanvas> createState() => _WheelCanvasState();
}

class _WheelCanvasState extends State<_WheelCanvas> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final center = size / 2;
        final radius = center - 4;

        return GestureDetector(
          onPanStart: (d) => _pick(d.localPosition, center, radius),
          onPanUpdate: (d) => _pick(d.localPosition, center, radius),
          child: CustomPaint(
            size: Size(size, size),
            painter: _WheelPainter(hue: widget.hue, saturation: widget.saturation, center: center, radius: radius),
          ),
        );
      },
    );
  }

  void _pick(Offset pos, double center, double radius) {
    final dx = pos.dx - center;
    final dy = pos.dy - center;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist > radius) return;

    final angle = math.atan2(dy, dx);
    final degrees = (angle * 180 / math.pi + 360) % 360;
    final sat = (dist / radius).clamp(0.0, 1.0);

    widget.onChanged(degrees, sat);
  }
}

class _WheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double center;
  final double radius;

  _WheelPainter({required this.hue, required this.saturation, required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final ringWidth = radius * 0.28;
    final innerRadius = radius - ringWidth;

    // Draw hue ring
    final ringPaint = Paint()
      ..shader = const SweepGradient(center: Alignment.center, colors: [
        Color(0xFFFF0000), Color(0xFFFF00FF), Color(0xFF0000FF),
        Color(0xFF00FFFF), Color(0xFF00FF00), Color(0xFFFFFF00),
        Color(0xFFFF0000),
      ]).createShader(Rect.fromCircle(center: Offset(center, center), radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;
    canvas.drawCircle(Offset(center, center), radius - ringWidth / 2, ringPaint);

    // White overlay for saturation (inner area)
    final innerRect = Rect.fromCircle(center: Offset(center, center), radius: innerRadius);
    final satPaint = Paint()
      ..shader = const RadialGradient(center: Alignment.center, colors: [Colors.white, Colors.transparent])
          .createShader(innerRect);
    canvas.drawCircle(Offset(center, center), innerRadius, satPaint);

    // Draw selector dot
    final angle = (hue - 90) * math.pi / 180;
    final dist = saturation * radius;
    final dotX = center + dist * math.cos(angle);
    final dotY = center + dist * math.sin(angle);

    canvas.drawCircle(Offset(dotX, dotY), 8, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(dotX, dotY), 6, Paint()..color = HSVColor.fromAHSV(1, hue, saturation, 1).toColor());
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.hue != hue || old.saturation != saturation;
}

class _BrightnessSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _BrightnessSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('明度', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 24,
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 24,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
              ),
              child: Slider(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
