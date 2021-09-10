import 'package:shared_preferences/shared_preferences.dart';

class App {
  static late SharedPreferences sp;

  /// 初始化全局变量，必须确保该函数在main中被调用
  static init() async {
    sp = await SharedPreferences.getInstance();
  }

  static bool get showSpiritLevelWidget => sp.getBool("showSpiritLevelWidget") ?? false;
  static set showSpiritLevelWidget(bool show) => sp.setBool("showSpiritLevelWidget", show);

  static bool get showAssistiveGridWidget => sp.getBool("showAssistiveGridWidget") ?? false;
  static set showAssistiveGridWidget(bool show) => sp.setBool("showAssistiveGridWidget", show);
}