import 'package:shared_preferences/shared_preferences.dart';

class App {
  static late SharedPreferences sp;
  static init() async {
    sp = await SharedPreferences.getInstance();
  }
}