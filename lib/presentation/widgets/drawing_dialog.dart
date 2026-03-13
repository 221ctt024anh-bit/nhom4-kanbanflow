import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class DrawingDialog extends StatefulWidget {
  const DrawingDialog({super.key});

  @override
  State<DrawingDialog> createState() => _DrawingDialogState();
}

class _DrawingDialogState extends State<DrawingDialog> {
  final List<Offset?> _points = [];

  Future<Uint8List?> _capturePng() async {
    if (_points.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(const Offset(0, 0), const Offset(500, 500)),
    );

    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) {
        canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(500, 500);
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return pngBytes?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bản vẽ mới'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: Colors.white,
            ),
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  RenderBox renderBox = context.findRenderObject() as RenderBox;
                  _points.add(renderBox.globalToLocal(details.globalPosition));
                });
              },
              onPanEnd: (details) => _points.add(null),
              child: CustomPaint(
                painter: _DrawingPainter(points: _points),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Vẽ hình ảnh của bạn vào ô trên',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () async {
            final bytes = await _capturePng();
            if (mounted) Navigator.pop(context, bytes);
          },
          child: const Text('Lưu bản vẽ'),
        ),
      ],
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<Offset?> points;

  _DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
