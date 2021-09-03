import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SpiritLevelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke  // 线
      ..color = Colors.white
      ..strokeWidth = 0.53;

    double dy = rect.top + rect.height / 2;
    canvas.drawLine(Offset(rect.left + 53, dy), Offset(rect.right - 53, dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class SpiritLevel extends StatefulWidget {
  const SpiritLevel({Key? key}) : super(key: key);

  @override
  _SpiritLevelState createState() => _SpiritLevelState();
}

class _SpiritLevelState extends State<SpiritLevel> {

  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  double _xInclination = 0.0;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -_xInclination,  // 朝反方向转动
      child: IgnorePointer(
        child: SizedBox.expand(
          child: CustomPaint(
            painter: SpiritLevelPainter(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    _streamSubscriptions.add(
      accelerometerEvents.listen(
        (AccelerometerEvent event) {
          setState(() {
            // 根据重力加速度在x轴上的分量来计算其水平偏移角度
            double x = event.x;
            double y = event.y;
            double z = event.z;
            double normOfG = sqrt(x * x + y * y + z * z);
            x /= normOfG;
            _xInclination = -asin(x); // 水平偏移角度
          });
        }
      )
    );
  }
}

