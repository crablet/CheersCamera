import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class App {
  static late SharedPreferences sp;

  /// 初始化全局变量，必须确保该函数在main中被调用
  static init() async {
    sp = await SharedPreferences.getInstance();

    ImageEditor.theme = ThemeData(
      scaffoldBackgroundColor: Colors.black,
      backgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black87,
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        toolbarTextStyle: TextStyle(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
      ),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
      ),
    );
  }

  static bool get showSpiritLevelWidget => sp.getBool("showSpiritLevelWidget") ?? false;
  static set showSpiritLevelWidget(bool show) => sp.setBool("showSpiritLevelWidget", show);

  static bool get showAssistiveGridWidget => sp.getBool("showAssistiveGridWidget") ?? false;
  static set showAssistiveGridWidget(bool show) => sp.setBool("showAssistiveGridWidget", show);

  static bool get saveOriginalImage => sp.getBool("saveOriginalImage") ?? true;
  static set saveOriginalImage(bool isSave) => sp.setBool("saveOriginalImage", isSave);
}