import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cheers_camera/screens/preview_screen.dart';
import 'package:cheers_camera/widgets/image_cropper.dart';
import 'package:flutter/material.dart';

import 'package:cheers_camera/main.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum PickImageWidgetPosition {
  left,
  right,
  top,
  bottom,
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
  with WidgetsBindingObserver {

  final GlobalKey _cropperKey = GlobalKey(debugLabel: "cropperKey");

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

  // 当前屏幕上有多少手指正在触摸（触点个数），用于处理缩放
  int _pointers = 0;

  final ResolutionPreset currentResolutionPreset = ResolutionPreset.max;

  double _baseScale = 1.0;
  double _currentZoomLevel = 1.0;
  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;

  List<File> allFileList = [];

  final List<PickImageWidgetPosition> _pickImageWidgetPositionList = [
    PickImageWidgetPosition.left,
    PickImageWidgetPosition.right,
    PickImageWidgetPosition.top,
    PickImageWidgetPosition.bottom,
  ];
  PickImageWidgetPosition _currentPickImageWidgetPosition = PickImageWidgetPosition.left;

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

  void refreshAlreadyCapturedImages() async {
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = await directory.list().toList();
    allFileList.clear();
    List<Map<int, dynamic>> fileNames = [];
    for (var file in fileList) {
      if (file.path.contains(".jpg")) {
        allFileList.add(File(file.path));
        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    }

    if (fileNames.isNotEmpty) {
      final recentFile = fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];
      _imageFile = File("${directory.path}/$recentFileName");
    }

    setState(() {});
  }

  void resetCameraValues() async {
    _currentZoomLevel = 1.0;
    _currentExposureOffset = 0.0;
  }

  @override
  void initState() {
    // 隐藏状态栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    // 初始化相机
    onNewCameraSelected(cameras.first);
    refreshAlreadyCapturedImages();
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
          backgroundColor: Colors.black,
          body: _isCameraInitialized
            ? _buildLoadedCamera(context)
            : _buildLoadingCamera(),
        )
    );
  }

  Widget _buildLoadedCamera(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1 / controller!.value.aspectRatio,
          child: Stack(
            children: [
              _buildCameraPreviewWidget(context),
              _buildSelectPictureWidget(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildSelectPickImagePositionWidget(),
                    _buildShowExposureOffsetWidget(),
                    _buildChangeExposureOffsetWidget(),
                    Row(
                      children: [
                        _buildChangeZoomLevelWidget(),
                        _buildShowZoomLevelWidget()
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
        Expanded(
          child: SingleChildScrollView(
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
                      _buildFlashTorchWidget()
                    ],
                  ),
                )
              ],
            ),
          ),
        )
      ],
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
        XFile? rawImage = await _takePicture();
        File imageFile = File(rawImage!.path);
        String fileFormat = imageFile.path.split('.').last;
        debugPrint(fileFormat);

        int currentUnix = DateTime.now().microsecondsSinceEpoch;
        final directory = await getApplicationDocumentsDirectory();
        final fileName = "$currentUnix.$fileFormat";  // 目前暂定为"时间戳.后缀"的命名，后续会改
        await imageFile.copy("${directory.path}/$fileName");
        await ImageGallerySaver.saveFile(imageFile.path, name: fileName); // 保存到相册中

        setState(() {
          _hasTakenPicture = true;
        });

        refreshAlreadyCapturedImages();
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
            Icons.circle,
            color: Colors.white,
            size: 65,
          ),
          Container(),
        ],
      ),
    );
  }

  Widget _buildMergePictureWidget() {
    return InkWell(
      onTap: () async {
        if (_hasSelectedPicture) {
          final png = await ImageCropper.crop(cropperKey: _cropperKey);
          if (png != null) {
            int currentUnix = DateTime.now().microsecondsSinceEpoch;
            final directory = await getApplicationDocumentsDirectory();
            final croppedFileName = "{$currentUnix}_cropped.png";
            final file = await File("${directory.path}/$croppedFileName").create();
            file.writeAsBytesSync(png);
            await ImageGallerySaver.saveFile(file.path, name: croppedFileName);

            final imageFromCamera = image.decodeImage(_imageFile!.readAsBytesSync());
            final imageFromSelected = image.decodeImage(file.readAsBytesSync());
            if (imageFromCamera != null && imageFromSelected != null) {
              final mergedImage = image.Image(imageFromCamera.width, imageFromCamera.height);
              image.copyInto(mergedImage, imageFromCamera, blend: true);
              switch (_currentPickImageWidgetPosition) {
                case PickImageWidgetPosition.left:
                  final imageFromSelectedResized = image.copyResize(imageFromSelected, width: imageFromCamera.width ~/ 2, height: imageFromCamera.height);
                  image.copyInto(mergedImage, imageFromSelectedResized, dstX: 0, blend: true);
                  break;
                case PickImageWidgetPosition.right:
                  final imageFromSelectedResized = image.copyResize(imageFromSelected, width: imageFromCamera.width ~/ 2, height: imageFromCamera.height);
                  image.copyInto(mergedImage, imageFromSelectedResized, dstX: imageFromCamera.width ~/ 2, blend: true);
                  break;
                case PickImageWidgetPosition.top:
                  final imageFromSelectedResized = image.copyResize(imageFromSelected, width: imageFromCamera.width, height: imageFromCamera.height ~/ 2);
                  image.copyInto(mergedImage, imageFromSelectedResized, dstY: 0, blend: true);
                  break;
                case PickImageWidgetPosition.bottom:
                  final imageFromSelectedResized = image.copyResize(imageFromSelected, width: imageFromCamera.width, height: imageFromCamera.height ~/ 2);
                  image.copyInto(mergedImage, imageFromSelectedResized, dstY: imageFromCamera.height ~/ 2, blend: true);
                  break;
              }

              final newFile = await File("${directory.path}/new_{$croppedFileName}").create();
              newFile.writeAsBytesSync(image.encodePng(mergedImage));
              await ImageGallerySaver.saveFile(newFile.path, name: "new_{$croppedFileName}");
            }
          }
        }
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
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 8.0,
            right: 8.0,
          ),
          child: DropdownButton<PickImageWidgetPosition>(
            dropdownColor: Colors.black87,
            underline: Container(),
            value: _currentPickImageWidgetPosition,
            items: [
              for (var position in _pickImageWidgetPositionList)
                DropdownMenuItem(
                  child: _positionEnumToIcon(position),
                  value: position,
                )
            ],
            onChanged: (value) {
              setState(() {
                _currentPickImageWidgetPosition = value!;
              });
            },
            hint: const Text("Select pick image widget position"),
          ),
        ),
      ),
    );
  }

  Widget _positionEnumToIcon(PickImageWidgetPosition position) {
    switch (position) {
      case PickImageWidgetPosition.left:
        return const Icon(
          Icons.align_horizontal_left,
          color: Colors.white,
        );
      case PickImageWidgetPosition.right:
        return const Icon(
          Icons.align_horizontal_right,
          color: Colors.white,
        );
      case PickImageWidgetPosition.top:
        return const Icon(
          Icons.align_vertical_top,
          color: Colors.white,
        );
      case PickImageWidgetPosition.bottom:
        return const Icon(
          Icons.align_vertical_bottom,
          color: Colors.white,
        );
    }
  }

  Widget _buildChangeExposureOffsetWidget() {
    return Expanded(
      child: RotatedBox(
        quarterTurns: 3,
        child: SizedBox(
          height: 30,
          child: Slider(
            value: _currentExposureOffset,
            min: _minAvailableExposureOffset,
            max: _maxAvailableExposureOffset,
            activeColor: Colors.white,
            inactiveColor: Colors.white30,
            onChanged: (value) async {
              setState(() {
                _currentExposureOffset = value;
              });
              await controller!.setExposureOffset(value);
            },
          ),
        ),
      )
    );
  }

  Widget _buildShowExposureOffsetWidget() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, top: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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

  Widget _buildFlashTorchWidget() {
    return InkWell(
      onTap: () async {
        setState(() {
          _currentFlashMode = FlashMode.torch;
        });
        await controller!.setFlashMode(FlashMode.torch);
      },
      child: Icon(
        Icons.highlight,
        color: _currentFlashMode == FlashMode.torch
          ? Colors.amber
          : Colors.white,
      ),
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
          ? Colors.amber
          : Colors.white,
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
          ? Colors.amber
          : Colors.white,
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
          ? Colors.amber
          : Colors.white,
      ),
    );
  }

  Widget _buildLoadingCamera() {
    return const Center(
      child: Text(
        "LOADING",
        style: TextStyle(color: Colors.white),
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

  Widget _buildCameraPreviewWidget(BuildContext context) {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return _buildLoadedCamera(context);
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
                onTapDown: (details) => onViewFinderTap(details, constraints),
              );
            },
          ),
        ),
      );
    }
  }

  Widget _buildSelectPictureWidget(BuildContext context) {
    return SizedBox.expand(
      child: FractionallySizedBox(
        alignment: _positionEnumToAlignment(_currentPickImageWidgetPosition),
        widthFactor: _positionEnumToWidthFactor(_currentPickImageWidgetPosition),
        heightFactor: _positionEnumToHeightFactor(_currentPickImageWidgetPosition),
        child: !_hasSelectedPicture
          ? Container(
            color: Colors.pink,
            child: ElevatedButton(
              child: const Text("select"),
              onPressed: () async {
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
          : ImageCropper(
              cropperKey: _cropperKey,
              image: Image.file(_selectedFile!)
          )
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
}
