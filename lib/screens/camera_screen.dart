import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:cheers_camera/painters/af_frame_painter.dart';
import 'package:cheers_camera/painters/assistive_grid_painter.dart';
import 'package:cheers_camera/screens/settings_screen.dart';
import 'package:cheers_camera/widgets/image_cropper.dart' as ic;
import 'package:cheers_camera/widgets/policy_confirm_dialog.dart';
import 'package:cheers_camera/widgets/spirit_level.dart';
import 'package:flutter/material.dart';

import 'package:cheers_camera/main.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_editor/image_editor.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart' as ip;

import '../globals.dart';
import '../i18n/camera_screen.i18n.dart';

enum PickImageWidgetPosition {
  left,
  right,
  top,
  bottom,
}

class MergeImageParam {
  final Uint8List imageFromSelect;
  final Uint8List imageFromCamera;
  final PickImageWidgetPosition currentPickImageWidgetPosition;
  final int imageFromSelectWidth;
  final int imageFromSelectHeight;
  final int imageFromCameraWidth;
  final int imageFromCameraHeight;


  MergeImageParam(
      this.imageFromSelect,
      this.imageFromCamera,
      this.currentPickImageWidgetPosition,
      this.imageFromSelectWidth,
      this.imageFromSelectHeight,
      this.imageFromCameraWidth,
      this.imageFromCameraHeight,
  );
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
  with WidgetsBindingObserver {

  final GlobalKey<ic.ImageCropperState> _cropperKeyForSelectPictureWidget =
    GlobalKey(debugLabel: "cropperKeyForSelectPictureWidget");

  final GlobalKey<ic.ImageCropperState> _cropperKeyForTakePictureWidget =
    GlobalKey(debugLabel: "cropperKeyForTakePictureWidget");

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
  final double _minPickImageRotation = -pi;
  final double _maxPickImageRotation = pi;
  bool _isSwitchingCamera = false;
  bool _shouldShowCamera = App.policyAgreement;

  bool _showFlashChoiceWidget = false;
  bool _showChangeExposureWidget = false;
  bool _showSelectPickImagePositionWidget = false;
  bool _showPreviewMaskOpacityWidget = false;
  bool _showPickImageRotationWidget = false;
  bool _showZoomValueWidget = false;

  // ?????????????????????????????????????????????????????????????????????????????????
  int _pointers = 0;

  final ResolutionPreset currentResolutionPreset = ResolutionPreset.max;

  double _baseScale = 1.0;
  double _currentZoomLevel = 1.0;
  double _currentExposureOffset = 0.0;
  double _currentPreviewMaskOpacity = 0.253;
  FlashMode _currentFlashMode = FlashMode.auto;
  double _currentPickImageWidgetRotation = 0; // [-pi, pi]

  static const double _afFrameRadius = 53;

  List<File> allFileList = [];

  PickImageWidgetPosition _currentPickImageWidgetPosition = PickImageWidgetPosition.left;

  double _autofocusFrameX = 0;
  double _autofocusFrameY = 0;
  bool _showAutofocusFrame = false;

  Future<XFile?> _takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController!.value.isTakingPicture) {
      // ???????????????????????????
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

    // ???controller????????????UI??????????????????
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

      controller!.setFlashMode(_currentFlashMode);
    } on CameraException catch (e) {
      debugPrint("Error initializing camera: $e");
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
        _isSwitchingCamera = false;
      });
    }
  }

  void resetCameraValues() async {
    _currentZoomLevel = 1.0;
    _currentExposureOffset = 0.0;
  }

  @override
  void initState() {
    super.initState();
    if (App.policyAgreement) {
      // ???????????????
      onNewCameraSelected(cameras.first);
      WidgetsBinding.instance?.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;
    // ??????????????????????????????APP??????????????????????????????????????????????????????????????????????????????
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {  // ???????????????
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {  // ????????????
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
          body: _isCameraInitialized && _shouldShowCamera
            ? _buildLoadedCamera()
            : _isSwitchingCamera ? _buildSwitchingCamera()
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
              if (_hasSelectedPicture && _hasTakenPicture)
                _buildBlackBackground(),
              _buildSelectPictureWidget(),
              if (!_hasTakenPicture)
                _buildCameraControlPad(),
              if (_hasTakenPicture && _imageFile != null)
                _buildCropCameraImageWidget(),
              if (App.showAssistiveGridWidget)
                _buildAssistiveGridWidget(),
              if (App.showSpiritLevelWidget)
                const SpiritLevel(),
              if (_hasSelectedPicture)
                _buildReselectImageWidget(),
              if (_showZoomValueWidget && !(_hasSelectedPicture && _hasSelectedPicture))
                _buildZoomValueWidget(),
              _buildAFFrameWidget(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        if (!(_hasSelectedPicture && _hasTakenPicture))
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
                        const SizedBox(width: 60, height: 60)
                        // _buildPreviewPictureWidget()
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

  Widget _buildAFFrameWidget() {
    return Positioned(
      left: _autofocusFrameX,
      top: _autofocusFrameY,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _showAutofocusFrame ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 530),
          child: CustomPaint(
            size: const Size.square(_afFrameRadius),
            painter: AFFramePainter(),
          )
        ),
      )
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

  Widget _buildToolBoxDetailWidget() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: _showFlashChoiceWidget ? _buildFlashChoiceWidget() :
             _showChangeExposureWidget ? _buildChangeExposureWidget() :
             _showSelectPickImagePositionWidget ? _buildSelectPickImagePositionWidget() :
             _showPreviewMaskOpacityWidget ? _buildChangePreviewMaskOpacityWidget() :
             _showPickImageRotationWidget ? _buildChangePickImageRotationWidget():
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
                      _showPreviewMaskOpacityWidget = false;
                      _showPickImageRotationWidget = false;
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
                      _showPreviewMaskOpacityWidget = false;
                      _showPickImageRotationWidget = false;
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
                      _showPreviewMaskOpacityWidget = false;
                      _showPickImageRotationWidget = false;
                    });
                  },
                ),
                InkWell(
                  child: const Icon(Icons.opacity, color: Colors.grey),
                  onTap: () {
                    setState(() {
                      _showPreviewMaskOpacityWidget = !_showPreviewMaskOpacityWidget;
                      _showChangeExposureWidget = false;
                      _showFlashChoiceWidget = false;
                      _showSelectPickImagePositionWidget = false;
                      _showPickImageRotationWidget = false;
                    });
                  },
                ),
                InkWell(
                  child: const Icon(Icons.loop, color: Colors.grey),
                  onTap: () {
                    setState(() {
                      _showPickImageRotationWidget = !_showPickImageRotationWidget;
                      _showPreviewMaskOpacityWidget = false;
                      _showChangeExposureWidget = false;
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
                      setState(() {});  // ??????????????????????????????????????????????????????
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

  // Widget _buildPreviewPictureWidget() {
  //   return InkWell(
  //     onTap: _imageFile != null
  //       ? () {
  //         Navigator.of(context).push(
  //           MaterialPageRoute(
  //             builder: (context) => PreviewScreen(imageFile: _imageFile!, fileList: allFileList)
  //           )
  //         );
  //       }
  //       : null,
  //     child: Container(
  //       width: 60,
  //       height: 60,
  //       decoration: BoxDecoration(
  //         color: Colors.black,
  //         borderRadius: BorderRadius.circular(10.0),
  //         border: Border.all(
  //           color: Colors.white,
  //           width: 2,
  //         ),
  //         image: _imageFile != null
  //           ? DecorationImage(
  //               image: FileImage(_imageFile!),
  //               fit: BoxFit.cover,
  //           )
  //           : null
  //       ),
  //     ),
  //   );
  // }

  Widget _buildTakePictureWidget() {
    return InkWell(
      onTap: () async {
        if (!_hasSelectedPicture) {
          Fluttertoast.showToast(
            msg: "Please select a picture first.????".i18n,
            backgroundColor: const Color(0xffffecb3),
            textColor: Colors.black,
            toastLength: Toast.LENGTH_SHORT,
          );
        } else {
          EasyLoading.show();

          XFile? rawImage = await _takePicture();
          _imageFile = File(rawImage!.path);

          // ???????????????"????????????"???????????????????????????????????????????????????????????????????????????????????????????????????????????????
          if (App.saveOriginalImage) {
            String fileFormat = _imageFile!.path.split('.').last;
            final currentUnix = DateTime.now().microsecondsSinceEpoch;
            final fileName = "$currentUnix.$fileFormat";  // ???????????????"?????????.??????"????????????????????????
            await ImageGallerySaver.saveFile(_imageFile!.path, name: fileName); // ??????????????????
          }

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

        final croppedImageFromSelectResult =
          await ic.ImageCropper.crop(
              cropperKey: _cropperKeyForSelectPictureWidget,
              cropPosition: _positionEnumToPreviewMaskCropPosition(_currentPickImageWidgetPosition)
          );
        final croppedImageFromSelect = croppedImageFromSelectResult.result;
        final croppedImageFromSelectWidth = croppedImageFromSelectResult.imageWidth;
        final croppedImageFromSelectHeight = croppedImageFromSelectResult.imageHeight;

        final croppedImageFromCameraResult =
          await ic.ImageCropper.crop(cropperKey: _cropperKeyForTakePictureWidget);
        final croppedImageFromCamera = croppedImageFromCameraResult.result;
        final croppedImageFromCameraWidth = croppedImageFromCameraResult.imageWidth;
        final croppedImageFromCameraHeight = croppedImageFromCameraResult.imageHeight;

        if (croppedImageFromSelect != null && croppedImageFromCamera != null) {
          final mergedImage = await _mergeImage(
              MergeImageParam(croppedImageFromSelect,
                  croppedImageFromCamera,
                  _currentPickImageWidgetPosition,
                  croppedImageFromSelectWidth,
                  croppedImageFromSelectHeight,
                  croppedImageFromCameraWidth,
                  croppedImageFromCameraHeight
              )
          );
          if (mergedImage != null) {
            final currentUnix = DateTime.now().microsecondsSinceEpoch;
            final croppedFileName = "{$currentUnix}_cropped.png";
            await ImageGallerySaver.saveImage(
                mergedImage,
                quality: 100,
                name: "new_{$croppedFileName}"
            );

            // ??????????????????????????????????????????
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(5.3 * 2 * 2)
                )
              ),
              builder: (BuildContext context) {
                return FractionallySizedBox(
                  heightFactor: 0.53,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xffffecb3),
                          Color(0xffffffff),
                        ]
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(5.3 * 2 * 2)
                      )
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "????",
                              style: TextStyle(
                                fontSize: 53 / 2
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  "Image Saved".i18n,
                                  style: const TextStyle(
                                    fontSize: 53 / 3,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                                const SizedBox(height: 5.3 / 2),
                                Text(
                                  "You can view in the gallery.".i18n,
                                  style: const TextStyle(
                                    fontSize: 53 / 5,
                                    color: Colors.grey
                                  )
                                )
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 5.3 * 2 * 2),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Done".i18n,
                            style:
                            const TextStyle(
                              fontSize: 5.3 * 2.9,
                              fontWeight: FontWeight.bold
                            )
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(53 * 5.3, 5.3 * 9.99),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(5.3 * 2)),
                            )
                          ),
                        )
                      ],
                    )
                  ),
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
    final imageFromCameraWidth = param.imageFromCameraWidth;
    final imageFromCameraHeight = param.imageFromCameraHeight;
    final imageFromSelectWidth = param.imageFromSelectWidth;
    final imageFromSelectHeight = param.imageFromSelectHeight;

    switch (param.currentPickImageWidgetPosition) {
      case PickImageWidgetPosition.left:
        final imageMergeOption = ImageMergeOption(
          canvasSize: Size(imageFromCameraWidth * 2, imageFromCameraHeight.toDouble()),
          format: const OutputFormat.png()
        )
        ..addImage(MergeImageConfig(
            image: MemoryImageSource(param.imageFromSelect),
            position: ImagePosition(
                const Offset(0, 0),
                Size(imageFromSelectWidth.toDouble(), imageFromSelectHeight.toDouble())
            )
        ))
        ..addImage(MergeImageConfig(
            image: MemoryImageSource(param.imageFromCamera),
            position: ImagePosition(
              Offset(imageFromSelectWidth.toDouble(), 0),
              Size(imageFromCameraWidth.toDouble(), imageFromCameraHeight.toDouble())
            )
        ));
        return ImageMerger.mergeToMemory(option: imageMergeOption);

      case PickImageWidgetPosition.right:
        final imageMergeOption = ImageMergeOption(
            canvasSize: Size(imageFromCameraWidth * 2, imageFromCameraHeight.toDouble()),
            format: const OutputFormat.png()
        )
        ..addImage(MergeImageConfig(
            image: MemoryImageSource(param.imageFromCamera),
            position: ImagePosition(
                const Offset(0, 0),
                Size(imageFromCameraWidth.toDouble(), imageFromCameraHeight.toDouble())
            )
        ))
        ..addImage(MergeImageConfig(
            image: MemoryImageSource(param.imageFromSelect),
            position: ImagePosition(
                Offset(imageFromCameraWidth.toDouble(), 0),
                Size(imageFromSelectWidth.toDouble(), imageFromSelectHeight.toDouble())
            )
        ));
        return ImageMerger.mergeToMemory(option: imageMergeOption);

      case PickImageWidgetPosition.top:
        final imageMergeOption = ImageMergeOption(
            canvasSize: Size(imageFromCameraWidth.toDouble(), imageFromCameraHeight.toDouble() * 2),
            format: const OutputFormat.png()
        )
        ..addImage(MergeImageConfig(
            image: MemoryImageSource(param.imageFromSelect),
            position: ImagePosition(
                const Offset(0, 0),
                Size(imageFromSelectWidth.toDouble(), imageFromSelectHeight.toDouble())
            )
        ))
        ..addImage(MergeImageConfig(
            image: MemoryImageSource(param.imageFromCamera),
            position: ImagePosition(
                Offset(0, imageFromSelectHeight.toDouble()),
                Size(imageFromCameraWidth.toDouble(), imageFromCameraHeight.toDouble())
            )
        ));
        return ImageMerger.mergeToMemory(option: imageMergeOption);

      case PickImageWidgetPosition.bottom:
        final imageMergeOption = ImageMergeOption(
            canvasSize: Size(imageFromCameraWidth.toDouble(), imageFromCameraHeight.toDouble() * 2),
            format: const OutputFormat.png()
        )
        ..addImage(MergeImageConfig(
            image: MemoryImageSource(param.imageFromCamera),
            position: ImagePosition(
                const Offset(0, 0),
                Size(imageFromCameraWidth.toDouble(), imageFromCameraHeight.toDouble())
            )
        ))
        ..addImage(MergeImageConfig(
            image: MemoryImageSource(param.imageFromSelect),
            position: ImagePosition(
                Offset(0, imageFromCameraHeight.toDouble()),
                Size(imageFromSelectWidth.toDouble(), imageFromSelectHeight.toDouble())
            )
        ));
        return ImageMerger.mergeToMemory(option: imageMergeOption);
    }
  }

  Widget _buildSelectRearCameraWidget() {
    return InkWell(
      onTap: () {
        setState(() {
          _isSwitchingCamera = true;
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

  Widget _buildChangeZoomLevelWidget() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(left: 53, right: 53),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 0.53,
          ),
          child: Slider(
            value: _currentZoomLevel,
            min: _minAvailableZoom,
            max: _maxAvailableZoom,
            activeColor: Colors.white,
            inactiveColor: Colors.white30,
            onChanged: (value) async {
              setState(() {
                _currentZoomLevel = value;
                _showZoomValueWidget = true;
              });
              await controller!.setZoomLevel(value);
            },
            onChangeEnd: (value) {
              setState(() {
                _showZoomValueWidget = false;
              });
            },
          )
        ),
      )
    );
  }

  Widget _buildChangePickImageRotationWidget() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildChangeCurrentPickImageRotationWidget(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChangeCurrentPickImageRotationWidget() {
    return Expanded(
        child: SizedBox(
          width: 30,
          child: Slider(
            value: _currentPickImageWidgetRotation,
            min: _minPickImageRotation,
            max: _maxPickImageRotation,
            onChanged: (value) {
              setState(() {
                // ??????????????????????????????????????????????????????????????????
                if (_hasSelectedPicture) {
                  var matrix =  _cropperKeyForSelectPictureWidget
                      .currentState
                      ?.transformationController
                      .value.clone();
                  if (matrix != null) {
                    matrix
                      ..translate(999.9, 999.9)
                      ..rotateZ(value - _currentPickImageWidgetRotation)  // ?????????????????????????????????????????????????????????rotateZ????????????????????????????????????
                      ..translate(-999.9, -999.9);
                    _cropperKeyForSelectPictureWidget
                        .currentState
                        ?.transformationController
                        .value = matrix;
                    _currentPickImageWidgetRotation = value;
                  }
                }
              });
            },
          ),
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

  Widget _buildChangeCurrentPreviewMaskOpacityWidget() {
    return Expanded(
        child: SizedBox(
          width: 30,
          child: Slider(
            value: _currentPreviewMaskOpacity,
            min: 0.0,
            max: 1.0,
            onChanged: (value) async {
              setState(() {
                _currentPreviewMaskOpacity = value;
              });
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

  Widget _buildShowCurrentPreviewMaskOpacityWidget() {
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
            _currentPreviewMaskOpacity.toStringAsFixed(1) + 'x',
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

  Widget _buildChangePreviewMaskOpacityWidget() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildShowCurrentPreviewMaskOpacityWidget(),
                _buildChangeCurrentPreviewMaskOpacityWidget(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLoadingCamera() {
    Timer(const Duration(milliseconds: 53), () async {
      if (!App.policyAgreement && !App.policyConfirmDialogIsShowing) {
        App.policyConfirmDialogIsShowing = true;
        _shouldShowCamera = await showDialog(context: context, builder: (_) => const PolicyConfirmDialog());
        _isCameraInitialized = true;
        onNewCameraSelected(cameras.first);
        setState(() {});
      }
    });

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(53),
        child: Image.asset("assets/cheers_splash.png"),
      ),
    );
  }

  Widget _buildSwitchingCamera() {
    return Container(
      color: Colors.black
    );
  }

  Widget _buildBlackBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
    );
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    Offset offset;
    switch (_currentPickImageWidgetPosition) {
      case PickImageWidgetPosition.left:
        offset = Offset(
          (details.localPosition.dx + constraints.maxWidth) / (constraints.maxWidth * 2),
          details.localPosition.dy / constraints.maxHeight,
        );
        break;

      case PickImageWidgetPosition.right:
        offset = Offset(
          details.localPosition.dx / (constraints.maxWidth * 2),
          details.localPosition.dy / constraints.maxHeight,
        );
        break;

      case PickImageWidgetPosition.top:
        offset = Offset(
          details.localPosition.dx / (constraints.maxWidth * 2),
          (details.localPosition.dy  + constraints.maxHeight) / (constraints.maxHeight * 2),
        );
        break;

      case PickImageWidgetPosition.bottom:
        offset = Offset(
          details.localPosition.dx / (constraints.maxWidth * 2),
          details.localPosition.dy / (constraints.maxHeight * 2),
        );
        break;

      default:
        offset = Offset(
          details.localPosition.dx / constraints.maxWidth,
          details.localPosition.dy / constraints.maxHeight,
        );
    }

    final CameraController cameraController = controller!;
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentZoomLevel;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // ?????????????????????????????????????????????????????????????????????
    if (controller == null || _pointers != 2) {
      return;
    }

    _currentZoomLevel = (_baseScale * details.scale).clamp(_minAvailableZoom, _maxAvailableZoom);
    setState(() {
      _showZoomValueWidget = true;
    });
    await controller!.setZoomLevel(_currentZoomLevel);
  }

  Widget _buildCameraPreviewWidget() {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return _buildLoadedCamera();
    } else {
      return CameraPreview(controller!);
    }
  }

  Widget _buildCameraControlPad() {
    return SizedBox.expand(
      child: DragTarget<PickImageWidgetPosition>(
        builder: (context, candidateData, rejectedData) {
          return FractionallySizedBox(
            alignment: _positionEnumToCropCameraImageAlignment(_currentPickImageWidgetPosition),
            widthFactor: _positionEnumToCropCameraImageWidthFactor(_currentPickImageWidgetPosition),
            heightFactor: _positionEnumToCropCameraImageHeightFactor(_currentPickImageWidgetPosition),
            child: Listener(
              onPointerDown: (_) => ++_pointers,
              onPointerUp: (_) => --_pointers,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onScaleEnd: (detail) {
                      setState(() {
                        _showZoomValueWidget = false;
                      });
                    },
                    onTapUp: (event) {
                      // ????????????????????????????????????
                      setState(() {
                        switch (_currentPickImageWidgetPosition) {
                          case PickImageWidgetPosition.left:
                            _showAutofocusFrame = true;
                            _autofocusFrameX = event.localPosition.dx - _afFrameRadius / 2 + constraints.maxWidth; // ????????????????????????????????????????????????????????????????????????
                            _autofocusFrameY = event.localPosition.dy - _afFrameRadius / 2;
                            break;

                          case PickImageWidgetPosition.right:
                            _showAutofocusFrame = true;
                            _autofocusFrameX = event.localPosition.dx - _afFrameRadius / 2; // ????????????????????????????????????????????????????????????????????????
                            _autofocusFrameY = event.localPosition.dy - _afFrameRadius / 2;
                            break;

                          case PickImageWidgetPosition.top:
                            _showAutofocusFrame = true;
                            _autofocusFrameX = event.localPosition.dx - _afFrameRadius / 2; // ????????????????????????????????????????????????????????????????????????
                            _autofocusFrameY = event.localPosition.dy - _afFrameRadius / 2 + constraints.maxHeight;
                            break;

                          case PickImageWidgetPosition.bottom:
                            _showAutofocusFrame = true;
                            _autofocusFrameX = event.localPosition.dx - _afFrameRadius / 2; // ????????????????????????????????????????????????????????????????????????
                            _autofocusFrameY = event.localPosition.dy - _afFrameRadius / 2;
                            break;
                        }
                      });

                      // ??????????????????????????????????????????
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
    );
  }
  
  Widget _buildPreviewMaskWidget() {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: _positionEnumToPreviewMaskBeginAlignment(_currentPickImageWidgetPosition),
        end: _positionEnumToPreviewMaskEndAlignment(_currentPickImageWidgetPosition),
        colors: [
          Colors.white,
          Colors.white,
          Colors.white.withOpacity(_currentPreviewMaskOpacity),
          Colors.white.withOpacity(_currentPreviewMaskOpacity)
        ],
        stops: const [.0, .5, .5, 1.0]  // ????????????????????????????????????????????????0???????????????????????????????????????????????????
      ).createShader(rect),
      child: DragTarget<PickImageWidgetPosition>(
        builder: (context, candidateData, rejectedData) {
          return LongPressDraggable<PickImageWidgetPosition>(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ic.ImageCropper(
                  boundaryMargin: _currentPickImageWidgetRotation != 0
                      ? const EdgeInsets.all(999.9)
                      : _positionEnumToPreviewMaskBoundaryMargin(_currentPickImageWidgetPosition,
                                                                 Size(constraints.maxWidth, constraints.maxHeight)),
                  key: _cropperKeyForSelectPictureWidget,
                  image: Image.file(_selectedFile!),
                );
              }
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
      ),
    );
  }

  Widget _buildSelectPictureWidget() {
    return SizedBox.expand(
      child: !_hasSelectedPicture
          ? FractionallySizedBox(
              alignment: _positionEnumToSelectPictureAlignment(_currentPickImageWidgetPosition),
              widthFactor: _positionEnumToSelectPictureWidthFactor(_currentPickImageWidgetPosition),
              heightFactor: _positionEnumToHeightSelectPictureFactor(_currentPickImageWidgetPosition),
              child: Container(
                color: Colors.black38,
                child: InkWell(
                  child: const Icon(Icons.add_a_photo, color: Colors.white,),
                  onTap: () async {
                    XFile? file = await ip.ImagePicker().pickImage(source: ip.ImageSource.gallery);
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
              ),
            )
          : _buildPreviewMaskWidget()
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

  Widget _buildZoomValueWidget() {
    return IgnorePointer(
      child: Center(
        child: Text(
          _currentZoomLevel.toStringAsFixed(1) + 'x',
          style: const TextStyle(
            fontSize: 53,
            color: Colors.white,
          ),
        ),
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
              XFile? file = await ip.ImagePicker().pickImage(source: ip.ImageSource.gallery);
              setState(() {
                if (file == null) {
                  _selectedFile = null;
                  _hasSelectedPicture = false;
                  _currentPickImageWidgetRotation = 0.0;
                } else {
                  _selectedFile = File(file.path);
                  _hasSelectedPicture = true;
                  _currentPickImageWidgetRotation = 0.0;
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
                key: _cropperKeyForTakePictureWidget,
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

  Alignment _positionEnumToSelectPictureAlignment(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return Alignment.topLeft;
      case PickImageWidgetPosition.right: return Alignment.topRight;
      case PickImageWidgetPosition.top: return Alignment.topLeft;
      case PickImageWidgetPosition.bottom: return Alignment.bottomLeft;
    }
  }

  double _positionEnumToSelectPictureWidthFactor(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return 0.5;
      case PickImageWidgetPosition.right: return 0.5;
      case PickImageWidgetPosition.top: return 1;
      case PickImageWidgetPosition.bottom: return 1;
    }
  }

  double _positionEnumToHeightSelectPictureFactor(PickImageWidgetPosition position) {
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

  Alignment _positionEnumToPreviewMaskBeginAlignment(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return Alignment.topLeft;
      case PickImageWidgetPosition.right: return Alignment.topRight;
      case PickImageWidgetPosition.top: return Alignment.topCenter;
      case PickImageWidgetPosition.bottom: return Alignment.bottomCenter;
    }
  }

  Alignment _positionEnumToPreviewMaskEndAlignment(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return Alignment.topRight;
      case PickImageWidgetPosition.right: return Alignment.topLeft;
      case PickImageWidgetPosition.top: return Alignment.bottomCenter;
      case PickImageWidgetPosition.bottom: return Alignment.topCenter;
    }
  }

  ic.CropPosition _positionEnumToPreviewMaskCropPosition(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left: return ic.CropPosition.leftHalf;
      case PickImageWidgetPosition.right: return ic.CropPosition.rightHalf;
      case PickImageWidgetPosition.top: return ic.CropPosition.topHalf;
      case PickImageWidgetPosition.bottom: return ic.CropPosition.bottomHalf;
    }
  }

  EdgeInsets _positionEnumToPreviewMaskBoundaryMargin(PickImageWidgetPosition position, Size size) {
    switch (position) {
      case PickImageWidgetPosition.left: return EdgeInsets.only(right: size.width / 2);
      case PickImageWidgetPosition.right: return EdgeInsets.only(left: size.width / 2);
      case PickImageWidgetPosition.top: return EdgeInsets.only(bottom: size.height / 2);
      case PickImageWidgetPosition.bottom: return EdgeInsets.only(top: size.height / 2);
    }
  }
}
