import 'dart:io';

import 'package:flutter/cupertino.dart';

class PreviewScreen extends StatelessWidget {
  final File imageFile;
  final List<File> fileList;

  const PreviewScreen({
    Key? key,
    required this.imageFile,
    required this.fileList,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
