import 'package:camera/camera.dart';
import 'package:cheers_camera/screens/camera_screen.dart';
import 'package:flutter/material.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
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
      home: CameraScreen(),
    );
  }
}
