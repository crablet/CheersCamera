import 'package:i18n_extension/i18n_extension.dart';

extension Localization on String {
  static final _t = Translations("en_us") +
      {
        "en_us": "Settings",
        "zh_cn": "设置",
      } +
      {
        "en_us": "Assistive Grid",
        "zh_cn": "辅助线",
      } +
      {
        "en_us": "Assistive Grid",
        "zh_cn": "辅助线",
      } +
      {
        "en_us": "Spirit Level",
        "zh_cn": "水平仪",
      } +
      {
        "en_us": "About",
        "zh_cn": "关于",
      } +
      {
        "en_us": "Built with love and courage.",
        "zh_cn": "以爱与勇气之名。",
      };

  String get i18n => localize(this, _t);

  String fill(List<Object> params) => localizeFill(this, params);

  String plural(value) => localizePlural(value, this, _t);

  String version(Object modifier) => localizeVersion(modifier, this, _t);
}