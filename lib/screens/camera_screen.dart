import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cheers_camera/painters/af_frame_painter.dart';
import 'package:cheers_camera/painters/assistive_grid_painter.dart';
import 'package:cheers_camera/screens/preview_screen.dart';
import 'package:cheers_camera/screens/settings_screen.dart';
import 'package:cheers_camera/widgets/image_cropper.dart' as ic;
import 'package:cheers_camera/widgets/preview_mask.dart';
import 'package:cheers_camera/widgets/spirit_level.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cheers_camera/main.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as image;
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../globals.dart';
import '../i18n/camera_screen.i18n.dart';

enum PickImageWidgetPosition {
  left,
  right,
  top,
  bottom,
}

class MergeImageParam {
  final List<int> imageFromSelect;
  final List<int> imageFromCamera;
  final PickImageWidgetPosition currentPickImageWidgetPosition;

  MergeImageParam(
      this.imageFromSelect,
      this.imageFromCamera,
      this.currentPickImageWidgetPosition,
  );
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
  with WidgetsBindingObserver {

  final GlobalKey _cropperKeyForSelectPictureWidget =
    GlobalKey(debugLabel: "cropperKeyForSelectPictureWidget");

  final GlobalKey _cropperKeyForTakePictureWidget =
    GlobalKey(debugLabel: "cropperKeyForTakePictureWidget");

  final GlobalKey<PreviewMaskState> _previewMaskKey =
    GlobalKey(debugLabel: "previewMaskKey");

  late PreviewMaskTransformationController _transformationController;

  CameraController? controller;

  File? _imageFile;

  bool _hasSelectedPicture = false;
  bool _hasTakenPicture = false;
  File? _selectedFile;

  bool _isCameraInitialized = false;
  bool _isRearCameraSelected = true;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  bool _showFlashChoiceWidget = false;
  bool _showChangeExposureWidget = false;
  bool _showSelectPickImagePositionWidget = false;

  // 当前屏幕上有多少手指正在触摸（触点个数），用于处理缩放
  int _pointers = 0;

  final ResolutionPreset currentResolutionPreset = ResolutionPreset.max;

  double _baseScale = 1.0;
  double _currentZoomLevel = 1.0;
  double _currentExposureOffset = 0.0;
  FlashMode _currentFlashMode = FlashMode.auto;

  List<File> allFileList = [];

  PickImageWidgetPosition _currentPickImageWidgetPosition = PickImageWidgetPosition.left;

  double _autofocusFrameX = 0;
  double _autofocusFrameY = 0;
  bool _showAutofocusFrame = false;

  Future<XFile?> _takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController!.value.isTakingPicture) {
      // 正在拍照就直接返回
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      debugPrint("Error occurred while taking picture: $e");
      return null;
    }
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg
    );

    await previousCameraController?.dispose();

    resetCameraValues();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // 当controller更新好了UI也要跟着刷新
    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController.getMinExposureOffset().then((value) => _minAvailableExposureOffset = value),
        cameraController.getMaxExposureOffset().then((value) => _maxAvailableExposureOffset = value),
        cameraController.getMaxZoomLevel().then((value) => _maxAvailableZoom = value),
        cameraController.getMinZoomLevel().then((value) => _minAvailableZoom = value)
      ]);

      _currentFlashMode = controller!.value.flashMode;
    } on CameraException catch (e) {
      debugPrint("Error initializing camera: $e");
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  void resetCameraValues() async {
    _currentZoomLevel = 1.0;
    _currentExposureOffset = 0.0;
  }

  @override
  void initState() {
    // 初始化相机
    onNewCameraSelected(cameras.first);
    _transformationController = PreviewMaskTransformationController();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;
    // 还没初始化好之前就有APP状态变化（切前后台等）就直接退出函数，不进行后续处理
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {  // 不可见状态
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {  // 可见状态
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
          body: _isCameraInitialized
            ? _buildLoadedCamera()
            : _buildLoadingCamera(),
        )
    );
  }

  Widget _buildLoadedCamera() {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1 / controller!.value.aspectRatio,
          child: Stack(
            children: [
              _buildCameraPreviewWidget(),
              if (_hasSelectedPicture && _selectedFile != null)
                _buildPreviewMaskWidget(),
              _buildSelectPictureWidget(),
              if (_hasTakenPicture && _imageFile != null)
                _buildCropCameraImageWidget(),
              if (App.showAssistiveGridWidget)
                _buildAssistiveGridWidget(),
              if (App.showSpiritLevelWidget)
                const SpiritLevel(),
              if (_hasSelectedPicture)
                _buildReselectImageWidget(),
              Positioned(
                left: _autofocusFrameX,
                top: _autofocusFrameY,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showAutofocusFrame ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 530),
                    child: CustomPaint(
                      size: const Size.square(2 * 53),
                      painter: AFFramePainter(),
                    )
                  ),
                )
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        _buildShowZoomLevelWidget(),
                        _buildChangeZoomLevelWidget(),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSelectRearCameraWidget(),
                        _hasSelectedPicture && _hasTakenPicture
                            ? _buildMergePictureWidget()
                            : _buildTakePictureWidget(),
                        _buildPreviewPictureWidget()
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
        _buildToolboxWidget(),
        _buildToolBoxDetailWidget(),
      ],
    );
  }

  Widget _buildAssistiveGridWidget() {
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: AssistiveGridPainter(),
        ),
      ),
    );
  }

  Widget _buildPreviewMaskWidget() {
    return IgnorePointer(
      child: SizedBox.expand(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (_, constraint) {
              return PreviewMask(
                transformationController: _transformationController,
                key: _previewMaskKey,
                child: Builder(
                  builder: (context) {
                    _setInitialScale(context, constraint.smallest);
                    return Image.file(_selectedFile!);
                  },
                ),
                constrained: false,
                minScale: 0.053,
              );
            },
          ),
        )
      ),
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

      // _shouldSetInitialScale = false;
    });
  }

  Widget _buildToolBoxDetailWidget() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: _showFlashChoiceWidget ? _buildFlashChoiceWidget() :
             _showChangeExposureWidget ? _buildChangeExposureWidget() :
             _showSelectPickImagePositionWidget ? _buildSelectPickImagePositionWidget() :
             Container()
    );
  }

  Widget _buildToolboxWidget() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 2 * 2 * 53),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return ScaleTransition(child: child, scale: animation);
                    },
                    child: _buildCurrentFlashModeIcon(),
                  ),
                  onTap: () {
                    setState(() {
                      _showFlashChoiceWidget = !_showFlashChoiceWidget;
                      _showChangeExposureWidget = false;
                      _showSelectPickImagePositionWidget = false;
                    });
                  },
                ),
                InkWell(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 2 * 2 * 53),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return ScaleTransition(child: child, scale: animation);
                    },
                    child: _buildCurrentPositionIcon(),
                  ),
                  onTap: () {
                    setState(() {
                      _showSelectPickImagePositionWidget = !_showSelectPickImagePositionWidget;
                      _showChangeExposureWidget = false;
                      _showFlashChoiceWidget = false;
                    });
                  },
                ),
                InkWell(
                  child: const Icon(Icons.exposure, color: Colors.grey),
                  onTap: () {
                    setState(() {
                      _showChangeExposureWidget = !_showChangeExposureWidget;
                      _showFlashChoiceWidget = false;
                      _showSelectPickImagePositionWidget = false;
                    });
                  },
                ),
                InkWell(
                  child: const Icon(Icons.settings, color: Colors.grey),
                  onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const SettingsScreen()
                        )
                    ).then((res) {
                      setState(() {});  // 强制刷新状态，后面应该要引入状态管理
                    });
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPreviewPictureWidget() {
    return InkWell(
      onTap: _imageFile != null
        ? () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PreviewScreen(imageFile: _imageFile!, fileList: allFileList)
            )
          );
        }
        : null,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          image: _imageFile != null
            ? DecorationImage(
                image: FileImage(_imageFile!),
                fit: BoxFit.cover,
            )
            : null
        ),
      ),
    );
  }

  Widget _buildTakePictureWidget() {
    return InkWell(
      onTap: () async {
        if (!_hasSelectedPicture) {
          Fluttertoast.showToast(
            msg: "Please select a picture first.🍻".i18n,
            backgroundColor: const Color(0xffffecb3),
            textColor: Colors.black,
            toastLength: Toast.LENGTH_SHORT,
          );
        } else {
          EasyLoading.show();

          XFile? rawImage = await _takePicture();
          _imageFile = File(rawImage!.path);
          String fileFormat = _imageFile!.path.split('.').last;
          final currentUnix = DateTime.now().microsecondsSinceEpoch;
          final fileName = "$currentUnix.$fileFormat";  // 目前暂定为"时间戳.后缀"的命名，后续会改
          await ImageGallerySaver.saveFile(_imageFile!.path, name: fileName); // 保存到相册中

          setState(() {
            _hasTakenPicture = true;
          });

          EasyLoading.dismiss();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: const [
          Icon(
            Icons.circle,
            color: Colors.white38,
            size: 80,
          ),
          Icon(
            Icons.circle,
            color: Colors.white,
            size: 65,
          ),
        ],
      ),
    );
  }

  Widget _buildMergePictureWidget() {
    return InkWell(
      onTap: () async {
        EasyLoading.show();

        final croppedImageFromSelect =
          await ic.ImageCropper.crop(cropperKey: _cropperKeyForSelectPictureWidget);
        final croppedImageFromCamera =
          await ic.ImageCropper.crop(cropperKey: _cropperKeyForTakePictureWidget);
        if (croppedImageFromSelect != null && croppedImageFromCamera != null) {
          final mergedImage = await compute(
              _mergeImage,
              MergeImageParam(croppedImageFromSelect, croppedImageFromCamera, _currentPickImageWidgetPosition)
          );

          if (mergedImage != null) {
            final currentUnix = DateTime.now().microsecondsSinceEpoch;
            final croppedFileName = "{$currentUnix}_cropped.png";
            await ImageGallerySaver.saveImage(
                mergedImage,
                quality: 100,
                name: "new_{$croppedFileName}"
            );

            showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text("Image Saved".i18n),
                    content: Text("Further edit?".i18n),
                    backgroundColor: const Color(0xffffecb3),
                    actions: [
                      TextButton(
                        child: Text("cancel".i18n),
                        style: TextButton.styleFrom(
                          primary: Colors.black,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        child: Text("edit".i18n),
                        style: TextButton.styleFrom(
                          primary: Colors.black,
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          final editedImage = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageEditor(
                                image: mergedImage,
                              ),
                            ),
                          );
                          await ImageGallerySaver.saveImage(
                              editedImage,
                              quality: 100,
                              name: "new_{$croppedFileName}"
                          );
                        },
                      ),
                    ],
                  );
                }
            );
          }
        }

        EasyLoading.dismiss();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.circle,
            color: Colors.white38,
            size: 80,
          ),
          const Icon(
            Icons.done,
            color: Colors.white,
            size: 53,
          ),
          Container(),
        ],
      ),
    );
  }

  static _mergeImage(MergeImageParam param) async {
    final imageFromCamera = image.decodeImage(param.imageFromCamera);
    final imageFromSelected = image.decodeImage(param.imageFromSelect);
    if (imageFromCamera != null && imageFromSelected != null) {
      switch (param.currentPickImageWidgetPosition) {
        case PickImageWidgetPosition.left:
          final mergedImage = image.Image(imageFromCamera.width * 2, imageFromCamera.height);
          image.copyInto(mergedImage, imageFromSelected, blend: false);
          image.copyInto(
              mergedImage,
              imageFromCamera,
              dstX: imageFromSelected.width,
              blend: false
          );
          return image.encodePng(mergedImage);

        case PickImageWidgetPosition.right:
          final mergedImage = image.Image(imageFromCamera.width * 2, imageFromCamera.height);
          image.copyInto(mergedImage, imageFromCamera, blend: false);
          image.copyInto(
              mergedImage,
              imageFromSelected,
              dstX: imageFromCamera.width,
              blend: false
          );
          return image.encodePng(mergedImage);

        case PickImageWidgetPosition.top:
          final mergedImage = image.Image(imageFromCamera.width, imageFromCamera.height * 2);
          image.copyInto(mergedImage, imageFromSelected, blend: false);
          image.copyInto(
              mergedImage,
              imageFromCamera,
              dstY: imageFromSelected.height,
              blend: false
          );
          return image.encodePng(mergedImage);

        case PickImageWidgetPosition.bottom:
          final mergedImage = image.Image(imageFromCamera.width, imageFromCamera.height * 2);
          image.copyInto(mergedImage, imageFromCamera, blend: false);
          image.copyInto(
              mergedImage,
              imageFromSelected,
              dstY: imageFromCamera.height,
              blend: false
          );
          return image.encodePng(mergedImage);
      }
    }
  }

  Widget _buildSelectRearCameraWidget() {
    return InkWell(
      onTap: () {
        setState(() {
          _isCameraInitialized = false;
        });
        onNewCameraSelected(cameras[_isRearCameraSelected ? 1 : 0]);
        setState(() {
          _isRearCameraSelected = !_isRearCameraSelected;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.circle,
            color: Colors.black38,
            size: 60,
          ),
          Icon(
            _isRearCameraSelected ? Icons.camera_front : Icons.camera_rear,
            color: Colors.white,
            size: 30,
          )
        ],
      ),
    );
  }

  Widget _buildShowZoomLevelWidget() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            _currentZoomLevel.toStringAsFixed(1) + 'x',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildChangeZoomLevelWidget() {
    return Expanded(
      child: Slider(
        value: _currentZoomLevel,
        min: _minAvailableZoom,
        max: _maxAvailableZoom,
        activeColor: Colors.white,
        inactiveColor: Colors.white30,
        onChanged: (value) async {
          setState(() {
            _currentZoomLevel = value;
          });
          await controller!.setZoomLevel(value);
        },
      )
    );
  }

  Widget _buildSelectPickImagePositionWidget() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPositionLeftWidget(),
                _buildPositionRightWidget(),
                _buildPositionTopWidget(),
                _buildPositionBottomWidget(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPositionLeftWidget() {
    return InkWell(
      onTap: () async {
        setState(() {
          _currentPickImageWidgetPosition = PickImageWidgetPosition.left;
        });
      },
      child: Icon(
        Icons.align_horizontal_left,
        color: _currentPickImageWidgetPosition == PickImageWidgetPosition.left
            ? const Color(0xffffecb3)
            : Colors.grey,
      ),
    );
  }

  Widget _buildPositionRightWidget() {
    return InkWell(
      onTap: () async {
        setState(() {
          _currentPickImageWidgetPosition = PickImageWidgetPosition.right;
        });
      },
      child: Icon(
        Icons.align_horizontal_right,
        color: _currentPickImageWidgetPosition == PickImageWidgetPosition.right
            ? const Color(0xffffecb3)
            : Colors.grey,
      ),
    );
  }

  Widget _buildPositionTopWidget() {
    return InkWell(
      onTap: () async {
        setState(() {
          _currentPickImageWidgetPosition = PickImageWidgetPosition.top;
        });
      },
      child: Icon(
        Icons.align_vertical_top,
        color: _currentPickImageWidgetPosition == PickImageWidgetPosition.top
            ? const Color(0xffffecb3)
            : Colors.grey,
      ),
    );
  }

  Widget _buildPositionBottomWidget() {
    return InkWell(
      onTap: () async {
        setState(() {
          _currentPickImageWidgetPosition = PickImageWidgetPosition.bottom;
        });
      },
      child: Icon(
        Icons.align_vertical_bottom,
        color: _currentPickImageWidgetPosition == PickImageWidgetPosition.bottom
            ? const Color(0xffffecb3)
            : Colors.grey,
      ),
    );
  }

  Widget _buildCurrentPositionIcon() {
    return Icon(
      _currentPickImageWidgetPosition == PickImageWidgetPosition.left ? Icons.align_horizontal_left :
      _currentPickImageWidgetPosition == PickImageWidgetPosition.right ? Icons.align_horizontal_right :
      _currentPickImageWidgetPosition == PickImageWidgetPosition.top ? Icons.align_vertical_top :
      _currentPickImageWidgetPosition == PickImageWidgetPosition.bottom ? Icons.align_vertical_bottom : Icons.error,
      color: Colors.grey,
      key: ValueKey<PickImageWidgetPosition>(_currentPickImageWidgetPosition),
    );
  }

  Widget _buildChangeExposureOffsetWidget() {
    return Expanded(
      child: SizedBox(
        width: 30,
        child: Slider(
          value: _currentExposureOffset,
          min: _minAvailableExposureOffset,
          max: _maxAvailableExposureOffset,
          onChanged: (value) async {
            setState(() {
              _currentExposureOffset = value;
            });
            await controller!.setExposureOffset(value);
          },
        ),
      )
    );
  }

  Widget _buildShowExposureOffsetWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 5.3, right: 5.3),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xffffecb3),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            _currentExposureOffset.toStringAsFixed(1) + 'x',
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentFlashModeIcon() {
    return Icon(
      _currentFlashMode == FlashMode.always ? Icons.flash_on :
      _currentFlashMode == FlashMode.auto ? Icons.flash_auto :
      _currentFlashMode == FlashMode.off ? Icons.flash_off : Icons.error,
      color: Colors.grey,
      key: ValueKey<FlashMode>(_currentFlashMode),
    );
  }

  Widget _buildFlashOnWidget() {
    return InkWell(
      onTap: () async {
        setState(() {
          _currentFlashMode = FlashMode.always;
        });
        await controller!.setFlashMode(FlashMode.always);
      },
      child: Icon(
        Icons.flash_on,
        color: _currentFlashMode == FlashMode.always
          ? const Color(0xffffecb3)
          : Colors.grey,
      ),
    );
  }

  Widget _buildFlashAutoWidget() {
    return InkWell(
      onTap: () async {
        setState(() {
          _currentFlashMode = FlashMode.auto;
        });
        await controller!.setFlashMode(FlashMode.auto);
      },
      child: Icon(
        Icons.flash_auto,
        color: _currentFlashMode == FlashMode.auto
          ? const Color(0xffffecb3)
          : Colors.grey,
      ),
    );
  }

  Widget _buildFlashChoiceWidget() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFlashOffWidget(),
                _buildFlashAutoWidget(),
                _buildFlashOnWidget(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFlashOffWidget() {
    return InkWell(
      onTap: () async {
        setState(() {
          _currentFlashMode = FlashMode.off;
        });
        await controller!.setFlashMode(FlashMode.off);
      },
      child: Icon(
        Icons.flash_off,
        color: _currentFlashMode == FlashMode.off
          ? const Color(0xffffecb3)
          : Colors.grey,
      ),
    );
  }

  Widget _buildChangeExposureWidget() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildShowExposureOffsetWidget(),
                _buildChangeExposureOffsetWidget(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLoadingCamera() {
    return Center(
      child: LoadingAnimationWidget.threeRotatingDots(
          color: Colors.white,
          size: 53
      ),
    );
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final CameraController cameraController = controller!;
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentZoomLevel;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // 两根手指才是缩放的动作，不是的话就不处理该手势
    if (controller == null || _pointers != 2) {
      return;
    }

    _currentZoomLevel = (_baseScale * details.scale).clamp(_minAvailableZoom, _maxAvailableZoom);
    setState(() {});
    await controller!.setZoomLevel(_currentZoomLevel);
  }

  Widget _buildCameraPreviewWidget() {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return _buildLoadedCamera();
    } else {
      return Listener(
        onPointerDown: (_) => ++_pointers,
        onPointerUp: (_) => --_pointers,
        child: CameraPreview(
          controller!,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onTapUp: (event) {
                  // 手指松开后开始展示聚焦框
                  setState(() {
                    _showAutofocusFrame = true;
                    _autofocusFrameX = event.localPosition.dx - 53; // 因为框大小是2 * 53，为了让中心对准按压地点，所以偏移减个一半框的大小
                    _autofocusFrameY = event.localPosition.dy - 53;
                  });

                  // 松开一段时间后结束展示聚焦框
                  Timer(const Duration(milliseconds: 530), () {
                    setState(() {
                      _showAutofocusFrame = false;
                    });
                  });
                },
                onTapDown: (details) => onViewFinderTap(details, constraints),
              );
            },
          ),
        ),
      );
    }
  }

  Widget _buildSelectPictureWidget() {
    return SizedBox.expand(
      child: FractionallySizedBox(
          alignment: _positionEnumToAlignment(_currentPickImageWidgetPosition),
          widthFactor: _positionEnumToWidthFactor(_currentPickImageWidgetPosition),
          heightFactor: _positionEnumToHeightFactor(_currentPickImageWidgetPosition),
          child: !_hasSelectedPicture
            ? Container(
                color: Colors.black38,
                child: InkWell(
                  child: const Icon(Icons.add_a_photo, color: Colors.white,),
                  onTap: () async {
                    XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
                    setState(() {
                      if (file == null) {
                        _selectedFile = null;
                        _hasSelectedPicture = false;
                      } else {
                        _selectedFile = File(file.path);
                        _hasSelectedPicture = true;
                      }
                    });
                  },
                ),
              )
            : DragTarget<PickImageWidgetPosition>(
                builder: (context, candidateData, rejectedData) {
                  return LongPressDraggable<PickImageWidgetPosition>(
                    child: ic.ImageCropper(
                      cropperKey: _cropperKeyForSelectPictureWidget,
                      previewMaskKey: _previewMaskKey,
                      image: Image.file(_selectedFile!),
                    ),
                    feedback: _buildThumbnailOfImage(_selectedFile!),
                    data: _currentPickImageWidgetPosition,
                  );
                },
                onAccept: (data) {
                  setState(() {
                    switch (_currentPickImageWidgetPosition) {
                      case PickImageWidgetPosition.left:
                        _currentPickImageWidgetPosition = PickImageWidgetPosition.right;
                        break;
                      case PickImageWidgetPosition.right:
                        _currentPickImageWidgetPosition = PickImageWidgetPosition.left;
                        break;
                      case PickImageWidgetPosition.top:
                        _currentPickImageWidgetPosition = PickImageWidgetPosition.bottom;
                        break;
                      case PickImageWidgetPosition.bottom:
                        _currentPickImageWidgetPosition = PickImageWidgetPosition.top;
                        break;
                    }
                  });
                },
              )
        )
      );
  }

  Widget _buildThumbnailOfImage(File file) {
    return Opacity(
      opacity: 0.53,
      child: Image.file(
        file,
        scale: 2 * 5.3,
      ),
    );
  }

  Widget _buildReselectImageWidget() {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2 * 2 * 5.3, left: 2 * 2 * 5.3),
        child: ElevatedButton(
          child: const Icon(Icons.undo),
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
          ),
          onPressed: () async {
            if (_hasSelectedPicture && !_hasTakenPicture) {
              XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
              setState(() {
                if (file == null) {
                  _selectedFile = null;
                  _hasSelectedPicture = false;
                } else {
                  _selectedFile = File(file.path);
                  _hasSelectedPicture = true;
                }
              });
            } else if (_hasSelectedPicture && _hasTakenPicture) {
              setState(() {
                _hasTakenPicture = false;
                _imageFile = null;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildCropCameraImageWidget() {
    return SizedBox.expand(
      child: FractionallySizedBox(
        alignment: _positionEnumToCropCameraImageAlignment(_currentPickImageWidgetPosition),
        widthFactor: _positionEnumToCropCameraImageWidthFactor(_currentPickImageWidgetPosition),
        heightFactor: _positionEnumToCropCameraImageHeightFactor(_currentPickImageWidgetPosition),
        child: DragTarget<PickImageWidgetPosition>(
          builder: (context, candidateData, rejectedData) {
            return LongPressDraggable<PickImageWidgetPosition>(
              child: ic.ImageCropper(
                cropperKey: _cropperKeyForTakePictureWidget,
                image: Image.file(_imageFile!),
              ),
              feedback: _buildThumbnailOfImage(_imageFile!),
              data: _currentPickImageWidgetPosition,
            );
          },
          onAccept: (data) {
            setState(() {
              switch (_currentPickImageWidgetPosition) {
                case PickImageWidgetPosition.left:
                  _currentPickImageWidgetPosition = PickImageWidgetPosition.right;
                  break;
                case PickImageWidgetPosition.right:
                  _currentPickImageWidgetPosition = PickImageWidgetPosition.left;
                  break;
                case PickImageWidgetPosition.top:
                  _currentPickImageWidgetPosition = PickImageWidgetPosition.bottom;
                  break;
                case PickImageWidgetPosition.bottom:
                  _currentPickImageWidgetPosition = PickImageWidgetPosition.top;
                  break;
              }
            });
          },
        ),
      ),
    );
  }

  Alignment _positionEnumToAlignment(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return Alignment.topLeft;
      case PickImageWidgetPosition.right: return Alignment.topRight;
      case PickImageWidgetPosition.top: return Alignment.topLeft;
      case PickImageWidgetPosition.bottom: return Alignment.bottomLeft;
    }
  }

  double _positionEnumToWidthFactor(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return 0.5;
      case PickImageWidgetPosition.right: return 0.5;
      case PickImageWidgetPosition.top: return 1;
      case PickImageWidgetPosition.bottom: return 1;
    }
  }

  double _positionEnumToHeightFactor(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return 1;
      case PickImageWidgetPosition.right: return 1;
      case PickImageWidgetPosition.top: return 0.5;
      case PickImageWidgetPosition.bottom: return 0.5;
    }
  }

  Alignment _positionEnumToCropCameraImageAlignment(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return Alignment.topRight;
      case PickImageWidgetPosition.right: return Alignment.topLeft;
      case PickImageWidgetPosition.top: return Alignment.bottomLeft;
      case PickImageWidgetPosition.bottom: return Alignment.topLeft;
    }
  }

  double _positionEnumToCropCameraImageWidthFactor(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return 0.5;
      case PickImageWidgetPosition.right: return 0.5;
      case PickImageWidgetPosition.top: return 1;
      case PickImageWidgetPosition.bottom: return 1;
    }
  }

  double _positionEnumToCropCameraImageHeightFactor(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return 1;
      case PickImageWidgetPosition.right: return 1;
      case PickImageWidgetPosition.top: return 0.5;
      case PickImageWidgetPosition.bottom: return 0.5;
    }
  }
}
