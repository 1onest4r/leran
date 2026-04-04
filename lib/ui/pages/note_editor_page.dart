import 'package:flutter/material.dart';
import '../../logic/folder_logic.dart';

class NoteEditorPage extends StatefulWidget {
  final FolderLogic folderLogic;

  const NoteEditorPage({super.key, required this.folderLogic});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  void _saveNote() async {
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
      Navigator.pop(context); // dont save empty notes
      return;
    }

    //call the logic to save the file and index it
    await widget.folderLogic.createAndSaveNote(
      _titleController.text,
      _contentController.text,
    );

    if (mounted) Navigator.pop(context); //go back to folder
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF33B996)),
          onPressed: _saveNote, // Save automatically when hitting back!
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF33B996)),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // TITLE INPUT
            TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                hintText: "Note Title",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                filled: false,
              ),
            ),
            const Divider(color: Colors.white10),
            // CONTENT INPUT
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines:
                    null, // Makes it expand infinitely like a real note app
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                decoration: const InputDecoration(
                  hintText: "Start typing your markdown here...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
