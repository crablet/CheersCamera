import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:image_editor/image_editor.dart';

enum CropPosition {
  full,
  leftHalf,
  rightHalf,
  topHalf,
  bottomHalf,
}

class CropResult {
  const CropResult(this.result, this.imageWidth, this.imageHeight);

  final Uint8List? result;
  final int imageWidth;
  final int imageHeight;
}

class ImageCropper extends StatefulWidget {
  const ImageCropper({
    Key? key,
    this.boundaryMargin = EdgeInsets.zero,
    required this.image,
  }) : super(key: key);

  // 准备被裁剪的图像
  final Image image;

  final EdgeInsets boundaryMargin;

  @override
  ImageCropperState createState() => ImageCropperState();

  /// 裁剪框中的图片并将其转成png格式输出，表示为 [Uint8List]
  /// 裁剪部件需要用其key引用
  static Future<CropResult> crop({
    required GlobalKey cropperKey,
    double pixelRatio = 3,
    CropPosition cropPosition = CropPosition.full
  }) async {
    // 获取裁剪后的图像
    final renderObject = cropperKey.currentContext!.findRenderObject();
    final boundary = renderObject as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    // 将图片转化为PNG格式，并返回
    final byteData = await image.toByteData(
      format: ImageByteFormat.png,
    );
    final Uint8List? pngBytes = byteData?.buffer.asUint8List();

    if (pngBytes != null) {
      switch (cropPosition) {
        case CropPosition.full:
          final editorOption = ImageEditorOption()
            ..addOption(ClipOption(x: 0, y: 0, width: image.width, height: image.height))
            ..outputFormat = const OutputFormat.png();
          return CropResult(await ImageEditor.editImage(image: pngBytes, imageEditorOption: editorOption), image.width, image.height);

        case CropPosition.leftHalf:
          final editorOption = ImageEditorOption()
            ..addOption(ClipOption(x: 0, y: 0, width: image.width / 2, height: image.height))
            ..outputFormat = const OutputFormat.png();
          return CropResult(await ImageEditor.editImage(image: pngBytes, imageEditorOption: editorOption), image.width ~/ 2, image.height);

        case CropPosition.rightHalf:
          final editorOption = ImageEditorOption()
            ..addOption(ClipOption(x: image.width / 2, y: 0, width: image.width / 2, height: image.height))
            ..outputFormat = const OutputFormat.png();
          return CropResult(await ImageEditor.editImage(image: pngBytes, imageEditorOption: editorOption), image.width ~/ 2, image.height);

        case CropPosition.topHalf:
          final editorOption = ImageEditorOption()
            ..addOption(ClipOption(x: 0, y: 0, width: image.width, height: image.height / 2))
            ..outputFormat = const OutputFormat.png();
          return CropResult(await ImageEditor.editImage(image: pngBytes, imageEditorOption: editorOption), image.width, image.height ~/ 2);

        case CropPosition.bottomHalf:
          final editorOption = ImageEditorOption()
            ..addOption(ClipOption(x: 0, y: image.height / 2, width: image.width, height: image.height / 2))
            ..outputFormat = const OutputFormat.png();
          return CropResult(await ImageEditor.editImage(image: pngBytes, imageEditorOption: editorOption), image.width, image.height ~/ 2);
      }
    }

    return CropResult(pngBytes, image.width, image.height);
  }
}

class ImageCropperState extends State<ImageCropper> {
  late TransformationController transformationController;

  // 为了避免不必要的刷新，用该变量表示状态变化后新旧widget是否改变了待裁剪的图像
  late bool _hasImageUpdate;

  // 是否需要设置图像初始比例
  bool _shouldSetInitialScale = false;

  // 用于将图像流监听器加在图像上的图像配置
  final _imageConfiguration = const ImageConfiguration();

  // 图像流监听器是用作指明图像是否完成加载的
  // 这可以帮助[InteractiveView]决定初始缩放比例，我们希望缩放至尽可能填充预览窗口
  late final _imageStreamListener = ImageStreamListener(
    (_, __) {
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        setState(() {
          _shouldSetInitialScale = true;
        });
      });
    }
  );

  @override
  void initState() {
    super.initState();
    _hasImageUpdate = true;
    transformationController = TransformationController();
  }

  @override
  void didUpdateWidget(covariant ImageCropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _hasImageUpdate = oldWidget.image.image != widget.image.image;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
        child: LayoutBuilder(
          builder: (_, constraint) {
            return InteractiveViewer(
              boundaryMargin: widget.boundaryMargin,
              transformationController: transformationController,
              constrained: false,
              minScale: 0.053,
              child: Builder(
                builder: (context) {
                  final imageStream = widget.image.image.resolve(
                    _imageConfiguration,
                  );
                  if (_hasImageUpdate && _shouldSetInitialScale) {
                    imageStream.removeListener(_imageStreamListener);
                    _setInitialScale(context, constraint.smallest);
                  } else if (_hasImageUpdate && !_shouldSetInitialScale) {
                    imageStream.addListener(_imageStreamListener);
                  }

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
        transformationController.value = Matrix4.identity() * _getCoverRatio(parentSize, childSize);
      }

      _shouldSetInitialScale = false;
    });
  }

  @override
  void dispose() {
    transformationController.dispose();
    super.dispose();
  }
}
