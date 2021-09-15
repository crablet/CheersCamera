import 'package:flutter/material.dart';
import 'package:flutter_beautiful_popup/main.dart';
import 'package:i18n_extension/i18n_widget.dart';

import '../globals.dart';

import '../i18n/settings_screen.i18n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return I18n(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Settings".i18n),
          centerTitle: true,
        ),
        backgroundColor: Colors.grey[100],
        body: ListView(
          padding: const EdgeInsets.all(5.3 * 2),
          children: [
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2 * 5.3),
                  color: Colors.white
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text("Assistive Grid".i18n),
                    value: App.showAssistiveGridWidget,
                    onChanged: (bool value) {
                      setState(() {
                        App.showAssistiveGridWidget = value;
                      });
                    },
                    secondary: const Icon(Icons.grid_3x3),
                  ),
                  Divider(
                    color: Colors.grey[300],
                  ),
                  SwitchListTile(
                    title: Text("Spirit Level".i18n),
                    value: App.showSpiritLevelWidget,
                    onChanged: (bool value) {
                      setState(() {
                        App.showSpiritLevelWidget = value;
                      });
                    },
                    secondary: const Icon(Icons.border_horizontal),
                  )
                ],
              ),
            ),
            const SizedBox(height: 2 * 5.3),
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2 * 5.3),
                  color: Colors.white
              ),
              child: Column(
                children: [
                  ListTile(
                      title: Text("About".i18n),
                      leading: const Icon(Icons.info),
                      onTap: () {
                        BeautifulPopup(
                            context: context,
                            template: TemplateCamera
                        ).show(
                          title: "Cheers Camera",
                          content: "Built with love and courage.".i18n,
                        );
                      }
                  ),
                ],
              ),
            ),
          ],
        ),
      )
    );
  }
}
