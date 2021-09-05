import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  final spFuture = SharedPreferences.getInstance();
  bool _showAssistiveGridWidget = App.sp.getBool("showAssistiveGridWidget") ?? false;
  bool _showSpiritLevelWidget = App.sp.getBool("showSpiritLevelWidget") ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(5.3 * 2),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5.3 * 2),
              color: Colors.white
            ),
            child: Column(
              children: [
                Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Assistive Grid"),
                      value: _showAssistiveGridWidget,
                      onChanged: (bool value) async {
                        setState(() {
                          _showAssistiveGridWidget = value;
                        });
                        final sp = await spFuture;
                        sp.setBool("showAssistiveGridWidget", value);
                      },
                      secondary: const Icon(Icons.grid_3x3),
                    ),
                    Divider(
                      color: Colors.grey[300],
                    ),
                    SwitchListTile(
                      title: const Text("Spirit Level"),
                      value: _showSpiritLevelWidget,
                      onChanged: (bool value) async {
                        setState(() {
                          _showSpiritLevelWidget = value;
                        });
                        final sp = await spFuture;
                        sp.setBool("showSpiritLevelWidget", value);
                      },
                      secondary: const Icon(Icons.border_horizontal),
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
