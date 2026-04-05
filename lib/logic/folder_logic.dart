import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/isar_service.dart';
import '../data/models/note.dart';

class FolderLogic extends ChangeNotifier {
  String? folderPath;
  bool isLoading = true;

  final IsarService dbService = IsarService();
  List<Note> allNotes = [];

  //when class is created automatically check for saved folder
  FolderLogic() {
    loadSavedFolder();
  }

  //if the user had already picked folder in the past
  Future<void> loadSavedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    folderPath = prefs.getString('folder_path');

    //ensure the db is fully open before we let the ui load
    await dbService.db;

    if (folderPath != null) {
      await refreshNotesList();
    }

    isLoading = false;

    //tells ui to rebuild, col
    notifyListeners();
  }

  Future<void> refreshNotesList() async {
    allNotes = await dbService.getAllNotes();
    notifyListeners();
  }

  //picking the folder for use
  Future<void> selectFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Select your desired folder",
    );

    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('folder_path', selectedDirectory);
      folderPath = selectedDirectory;
      await refreshNotesList(); //load empty list
      //tells the ui th folder is picked
      notifyListeners();
    }
  }

  //diconnect the active folder
  Future<void> disconnectFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('folder_path');
    folderPath = null;
    notifyListeners();
  }

  Future<void> createAndSaveNote(String title, String content) async {
    if (folderPath == null) {
      return;
    }

    //create safe file name
    String safeTitle = title
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    if (safeTitle.isEmpty) {
      safeTitle = "Untitled";
    }

    String fullPath = "$folderPath/$safeTitle.md";
    File file = File(fullPath);

    //write raw md file into hard drive
    await file.writeAsString(content);

    //create the db index obj
    final newNote = Note()
      ..title = title
      ..content = content
      ..filePath = fullPath
      ..updateAt = DateTime.now();

    //save ot isar
    await dbService.saveNoteIndex(newNote);

    //update the ui
    await refreshNotesList();
  }

  Future<void> updateNote(Note note, String newTitle, String newContent) async {
    try {
      final oldFile = File(note.filePath);

      //prepare the new file path properly
      String safeTitle = newTitle
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      if (safeTitle.isEmpty) {
        safeTitle = "Untitled";
      }
      String newPath = "$folderPath/$safeTitle.md";

      if (note.filePath != newPath) {
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      final newFile = File(newPath);
      await newFile.writeAsString(newContent);

      note.title = newTitle;
      note.content = newContent;
      note.filePath = newPath;
      note.updateAt = DateTime.now();

      await dbService.saveNoteIndex(note);
      await refreshNotesList();
    } catch (e) {
      print("Error updating note: $e");
    }
  }
}
