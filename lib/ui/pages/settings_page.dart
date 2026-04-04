import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 100,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Settings",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Manage your localized, private configuration settings.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader("STORAGE"),
          _settingsCard([
            const ListTile(
              leading: Icon(Icons.folder_open),
              title: Text("Folder Location"),
              subtitle: Text("No folder selected"),
              trailing: Icon(Icons.chevron_right),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionHeader("APPEARANCE"),
          _settingsCard([
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text("Dark Mode"),
              value: true,
              activeColor: const Color(0xFF33B996),
              onChanged: (v) {},
            ),
            const Divider(color: Color.fromARGB(255, 71, 71, 71), height: 1),
            const ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text("Theme Primary"),
              trailing: CircleAvatar(
                radius: 8,
                backgroundColor: Color(0xFF33B996),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          _sectionHeader("SUPPORT"),
          _settingsCard([
            const ListTile(
              leading: Icon(Icons.chat_bubble_outline),
              title: Text("Send Feedback"),
              subtitle: Text("Report a bug or suggest a new feature"),
            ),
            const Divider(color: Color.fromARGB(255, 71, 71, 71), height: 1),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text("About"),
              subtitle: Text("Leran Local Storage Engine\nVersion 1.0.0"),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(children: children),
    );
  }
}
