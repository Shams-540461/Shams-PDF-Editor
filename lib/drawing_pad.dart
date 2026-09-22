import 'package:flutter/material.dart';

class InkDrawing {
  InkDrawing(List<List<Offset>> input)
      : strokes = input.map((s) => List<Offset>.unmodifiable(s)).toList();
  static const canvasSize = Size(480, 240);
  final List<List<Offset>> strokes;
}

class DrawingPad extends StatefulWidget {
  const DrawingPad({super.key});
  @override
  State<DrawingPad> createState() => _DrawingPadState();
}

class _DrawingPadState extends State<DrawingPad> {
  final List<List<Offset>> _strokes = [];
  Offset _point(Offset p, Size size) => Offset(
    (p.dx / size.width * 480).clamp(0.0, 480.0).toDouble(),
    (p.dy / size.height * 240).clamp(0.0, 240.0).toDouble(),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Draw or sign'),
    content: SizedBox(width: 480, child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Draw below. Your drawing will be placed at the selected spot.'),
        const SizedBox(height: 12),
        AspectRatio(aspectRatio: 2, child: LayoutBuilder(builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          return ClipRect(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => setState(() => _strokes.add([_point(d.localPosition, size)])),
            onPanUpdate: (d) => setState(() {
              if (_strokes.isNotEmpty) _strokes.last.add(_point(d.localPosition, size));
            }),
            onTapUp: (d) => setState(() => _strokes.add([_point(d.localPosition, size)])),
            child: CustomPaint(painter: _InkPainter(_strokes), size: size),
          ));
        })),
      ],
    )),
    actions: [
      TextButton(onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
        child: const Text('Clear')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _strokes.isEmpty ? null : () => Navigator.pop(context, InkDrawing(_strokes)),
        child: const Text('Insert drawing')),
    ],
  );
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes);
  final List<List<Offset>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.srcOver);
    canvas.save();
    canvas.scale(size.width / 480, size.height / 240);
    final paint = Paint()..color = const Color(0xFF14283C)
      ..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (final stroke in strokes) {
      if (stroke.length == 1) canvas.drawCircle(stroke.first, 1, paint);
      for (var i = 1; i < stroke.length; i++) {
        canvas.drawLine(stroke[i - 1], stroke[i], paint);
      }
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) => true;
}
