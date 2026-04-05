import 'package:flutter/material.dart';
import '../../logic/folder_logic.dart';
import '../../data/models/note.dart';

class NoteEditorPage extends StatefulWidget {
  final FolderLogic folderLogic;
  final Note? note;

  const NoteEditorPage({super.key, required this.folderLogic, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _currentFilePath;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? "");
    _contentController = TextEditingController(
      text: widget.note?.content ?? "",
    );

    _currentFilePath = widget.note?.filePath ?? "";

    widget.folderLogic.addListener(_onFolderLogicUpdated);
  }

  @override
  void dispose() {
    widget.folderLogic.removeListener(_onFolderLogicUpdated);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onFolderLogicUpdated() {
    if (_currentFilePath.isEmpty) {
      return;
    }

    if (widget.folderLogic.lastMovedFromPath == _currentFilePath) {
      _currentFilePath = widget.folderLogic.lastMovedToPath!;

      if (widget.note != null) {
        widget.note!.filePath = _currentFilePath;
      }
    }

    try {
      //find the live version of this note in the database
      final liveNote = widget.folderLogic.allNotes.firstWhere(
        (n) => n.filePath == _currentFilePath,
      );

      if (liveNote.title != _titleController.text) {
        _titleController.text = liveNote.title;
      }

      //update the content (preserving cursor position)
      if (liveNote.content != _contentController.text) {
        final cursorPosition = _contentController.selection;
        _contentController.text = liveNote.content;

        //safely restore the cursor
        if (cursorPosition.baseOffset >= 0 &&
            cursorPosition.baseOffset <= liveNote.content.length) {
          _contentController.selection = cursorPosition;
        } else {
          //if the new content is shorter, place cursor at the end
          _contentController.selection = TextSelection.collapsed(
            offset: liveNote.content.length,
          );
        }
      }

      //update title
      if (liveNote.title != _titleController.text) {
        _titleController.text = liveNote.title;
      }
    } catch (e) {
      print("Note is deleted or renamed externally");
    }
  }

  void _saveNote() async {
    final title = _titleController.text;
    final content = _contentController.text;

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    if (widget.note == null) {
      await widget.folderLogic.createAndSaveNote(title, content);
    } else {
      await widget.folderLogic.updateNote(widget.note!, title, content);
    }

    if (mounted) Navigator.pop(context); //go back to folder
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: _saveNote, // Save automatically when hitting back!
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: primaryColor),
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
              style: theme.textTheme.headlineMedium,
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
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: "Start typing...",
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
