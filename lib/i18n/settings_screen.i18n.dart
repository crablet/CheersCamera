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
        "en_us": "Spirit Level",
        "zh_cn": "水平仪",
      } +
      {
        "en_us": "Save Original Image",
        "zh_cn": "保存原图",
      } +
      {
        "en_us": "About",
        "zh_cn": "关于",
      } +
      {
        "en_us": "Even mountains and ocean cannot stop us falling in love.",
        "zh_cn": "所爱隔山海，山海皆可平。",
      };

  String get i18n => localize(this, _t);

  String fill(List<Object> params) => localizeFill(this, params);

  String plural(value) => localizePlural(value, this, _t);

  String version(Object modifier) => localizeVersion(modifier, this, _t);
}