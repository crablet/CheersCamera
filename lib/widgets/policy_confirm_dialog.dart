import 'package:flutter/material.dart';

class PolicyConfirmDialog extends Dialog {
  const PolicyConfirmDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        children: [
          Dialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5.3 * 4)),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5.3 * 4, bottom: 5.3 * 4),
                  child: Text(
                    "欢迎使用Cheers Camera",
                    style: TextStyle(
                      fontSize: 5.3 * 2.9,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 53 * 6
                  ),
                  child: const Padding(
                    padding: EdgeInsets.only(
                      left: 5.3 * 4,
                      right: 5.3 * 4,
                      bottom: 5.3 * 2,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Text(
                        "请在使用前充分阅读《隐私协议》，并了解以下权限申请及使用情况：\n\n"
                        "当您需要使用编辑功能，或保存编辑后的图片时，我们会申请获取您的相册权限（或称为存储权限）、摄像头权限、麦克风权限。\n\n"
                        "如您对以上有任何疑问，可发送邮件至support@xiyuntech.gz.com与我们联系。\n\n"
                        "如您同意以上内容，请点击\"同意\"开始使用我们的产品与服务。",
                        style: TextStyle(
                          fontSize: 5.3 * 2.53,
                          color: Color(0xff535353),
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(5.3 * 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "点击阅读",
                          style: TextStyle(
                            fontSize: 5.3 * 2.53,
                            color: Color(0xff535353),
                          ),
                        ),
                        TextSpan(
                          text: "《隐私协议》",
                          style: TextStyle(
                            fontSize: 5.3 * 2.53,
                            color: Color(0xffcbba83),
                          ),
                        ),
                      ]
                    )
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5.3 * 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text(
                          "不同意",
                          style: TextStyle(
                            color: Color(0xff9d9d9d),
                            fontSize: 5.3 * 2.9,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(53 * 2, 5.3 * 6.66),
                          primary: const Color(0xfff6f6f6),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(5.3 * 2)),
                          )
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text(
                          "同意",
                          style: TextStyle(
                            fontSize: 5.3 * 2.9,
                            fontWeight: FontWeight.bold
                          )
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(53 * 2, 5.3 * 6.66),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(5.3 * 2)),
                          )
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
