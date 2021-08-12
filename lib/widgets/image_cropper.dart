import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

class ImageCropper extends StatefulWidget {
  const ImageCropper({
    Key? key,
    required this.cropperKey,
    required this.image,
  }) : super(key: key);

  // 准备被裁剪的图像
  final Image image;

  // 使用crop要用到的key
  final GlobalKey? cropperKey;

  @override
  _ImageCropperState createState() => _ImageCropperState();

  /// 裁剪框中的图片并将其转成png格式输出，表示为 [Uint8List]
  //. 裁剪部件需要用其key引用
  static Future<Uint8List?> crop({
    required GlobalKey cropperKey,
    double pixelRatio = 3,
  }) async {
    // 获取裁剪后的图像
    final renderObject = cropperKey.currentContext!.findRenderObject();
    final boundary = renderObject as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);

    // 将图片转化为PNG格式，并返回
    final byteData = await image.toByteData(
      format: ImageByteFormat.png,
    );
    final pngBytes = byteData?.buffer.asUint8List();

    return pngBytes;
  }
}

class _ImageCropperState extends State<ImageCropper> {

  // 初始化变换控制器
  final _transformationController = TransformationController();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
        child: LayoutBuilder(
          builder: (_, constraint) {
            return InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              minScale: 0.053,
              child: Builder(
                builder: (context) {
                  // 有图片被加载了，设置初始比例
                  _setInitialScale(context, constraint.biggest);
                  return widget.image;
                },
              ),
            );
          },
        )
    );
  }

  // 基于外部以及内部（图像）的约束计算比例
  double _getCoverRatio(Size outside, Size inside) {
    return outside.width / outside.height > inside.width / inside.height
        ? outside.width / inside.width
        : outside.height / inside.height;
  }

  // 设置图像的初始比例
  void _setInitialScale(BuildContext context, Size parentSize) {
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      final renderBox = context.findRenderObject() as RenderBox?;
      final childSize = renderBox?.size ?? Size.zero;
      if (childSize != Size.zero) {
        _transformationController.value = Matrix4.identity() * _getCoverRatio(parentSize, childSize);
      }
    });
  }
}
