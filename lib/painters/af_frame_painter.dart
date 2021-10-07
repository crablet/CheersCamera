import 'package:flutter/material.dart';

class AFFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke  // 线
      ..color = Colors.white
      ..strokeWidth = 2 * 0.53;

    canvas.drawCircle(Offset(rect.width / 2, rect.height / 2), rect.width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
