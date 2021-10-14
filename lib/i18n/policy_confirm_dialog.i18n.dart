import 'package:i18n_extension/i18n_extension.dart';

const title = "title";

extension Localization on String {
  static const _t = Translations.from("en_us", {
    title: {
      "en_us": "Welcome to Cheers Camera",
      "zh_cn": "欢迎使用Cheers Camera",
    }
  });

  String get i18n => localize(this, _t);

  String fill(List<Object> params) => localizeFill(this, params);

  String plural(value) => localizePlural(value, this, _t);

  String version(Object modifier) => localizeVersion(modifier, this, _t);
}