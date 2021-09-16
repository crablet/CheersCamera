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
        "en_us": "Would you like a further edit?",
        "zh_cn": "想进一步编辑吗？",
      } +
      {
        "en_us": "cancel",
        "zh_cn": "取消",
      } +
      {
        "en_us": "edit",
        "zh_cn": "编辑",
      };

  String get i18n => localize(this, _t);

  String fill(List<Object> params) => localizeFill(this, params);

  String plural(value) => localizePlural(value, this, _t);

  String version(Object modifier) => localizeVersion(modifier, this, _t);
}