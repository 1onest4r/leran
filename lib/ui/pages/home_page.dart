import 'package:flutter/material.dart';

import '../../logic/folder_logic.dart';
import 'note_editor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FolderLogic _folderLogic = FolderLogic();

  @override
  void dispose() {
    _folderLogic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "FOLDER",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _folderLogic,
        builder: (context, child) {
          if (_folderLogic.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF33B996)),
            );
          }

          if (_folderLogic.folderPath != null) {
            return _buildActiveFolder();
          } else {
            return _buildNoFolder();
          }
        },
      ),
    );
  }

  Widget _buildNoFolder() {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 80,
            color: primaryColor.withOpacity(0.4),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Active Folder",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Select a folder on your device to serve as your digital archive. Your notes will be stored safely here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          const SizedBox(height: 30),
          OutlinedButton.icon(
            onPressed: _folderLogic.selectFolder,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryColor, width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.folder_open),
            label: const Text(
              "Select Local Folder",
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFolder() {
    return Scaffold(
      backgroundColor: Colors.transparent, // Keeps the dark theme
      body: _folderLogic.allNotes.isEmpty
          ? const Center(
              child: Text(
                "Folder is empty. Create a note!",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _folderLogic.allNotes.length,
              itemBuilder: (context, index) {
                final note = _folderLogic.allNotes[index];
                return Card(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      note.title.isEmpty ? "Untitled" : note.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      note.content,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis, // Cuts off long text with ...
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteEditorPage(
                            folderLogic: _folderLogic,
                            note: note,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      // THE CREATE NOTE BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.edit, color: Colors.black),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorPage(folderLogic: _folderLogic),
            ),
          );
        },
      ),
    );
  }
}
