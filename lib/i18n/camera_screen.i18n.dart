import 'package:i18n_extension/i18n_extension.dart';

extension Localization on String {
  static final _t = Translations("en_us") +
      {
        "en_us": "Please select a picture first.🍻",
        "zh_cn": "请先选择照片🍻",
      } +
      {
        "en_us": "Image Saved",
        "zh_cn": "照片已保存",
      } +
      {
        "en_us": "Image saved!",
        "zh_cn": "成功保存！",
      } +
      {
        "en_us": "You can view in the gallery.",
        "zh_cn": "可前往相册查看",
      } +
      {
        "en_us": "Done",
        "zh_cn": "完成",
      };

  String get i18n => localize(this, _t);

  String fill(List<Object> params) => localizeFill(this, params);

  String plural(value) => localizePlural(value, this, _t);

  String version(Object modifier) => localizeVersion(modifier, this, _t);
}