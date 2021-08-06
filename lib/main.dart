import 'package:camera/camera.dart';
import 'package:cheers_camera/screens/camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();

    _requestPermission();
  } on CameraException catch (e) {
    debugPrint("Error in fetching the cameras: $e");
  }
  runApp(const CheersCamera());
}

class CheersCamera extends StatelessWidget {
  const CheersCamera({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "CheersCamera",
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      debugShowCheckedModeBanner: false,
      home: const CameraScreen(),
    );
  }
}

Future<void> _requestPermission() async {
  // 获取存储权限，image_gallery_saver库需要用到
  Map<Permission, PermissionStatus> statuses = await [
    Permission.storage,
  ].request();

  final info = statuses[Permission.storage].toString();
  debugPrint(info);
}

