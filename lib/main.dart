import 'dart:io';

import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:cheers_camera/screens/camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:i18n_extension/i18n_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'globals.dart';

List<CameraDescription> cameras = [];

late final Directory directory;

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
    directory = await getApplicationDocumentsDirectory();

    await App.init();

    EasyLoading.instance.maskType = EasyLoadingMaskType.black;

    // 禁止横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

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
      title: "Cheers Camera",
      theme: ThemeData(
        primarySwatch: createMaterialColor(const Color(0xffffecb3)),
      ),
      debugShowCheckedModeBanner: false,
      home: I18n(
        child: const CameraScreen()
      ),
      builder: EasyLoading.init(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', "US"),
        Locale('zh', "CN"),
      ],
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

MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  final swatch = <int, Color>{};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}
