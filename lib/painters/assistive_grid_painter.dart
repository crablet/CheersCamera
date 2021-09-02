import 'package:flutter/material.dart';

/// 拍照辅助线，九宫格
class AssistiveGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke  // 线
      ..color = Colors.white
      ..strokeWidth = 0.53;

    // 画横线
    for (int i = 1; i < 3; ++i) {
      double dy = rect.top + rect.height / 3 * i;
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), paint);
    }
    // 画竖线
    for (int i = 1; i < 3; ++i) {
      double dx = rect.left + rect.width / 3 * i;
      canvas.drawLine(Offset(dx, rect.top), Offset(dx, rect.bottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}