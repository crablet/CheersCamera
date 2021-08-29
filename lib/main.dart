import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cheers_camera/screens/camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];

late final Directory directory;

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
    directory = await getApplicationDocumentsDirectory();

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
      builder: EasyLoading.init(),
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

