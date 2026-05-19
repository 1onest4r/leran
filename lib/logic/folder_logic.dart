import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/database/database_service.dart';
import '../data/models/note.dart';

enum SortOption { dateDesc, alphaAsc, alphaDesc }

class FolderLogic extends ChangeNotifier {
  String? folderPath;

  bool isLoading = true;
  bool isSyncingBackground = false;

  SortOption currentSort = SortOption.dateDesc;
  int displayLimit = 50;

  final DatabaseService dbService = DatabaseService();
  List<Note> allNotes = [];

  StreamSubscription<FileSystemEvent>? _directoryWatcher;
  final Map<String, Timer> _debounceTimers = {};

  String? lastMovedFromPath;
  String? lastMovedToPath;

  FolderLogic() {
    loadSavedFolder();
  }

  @override
  void dispose() {
    _stopWatchingDirectory();
    super.dispose();
  }

  void changeSortOption(SortOption option) {
    currentSort = option;
    refreshNotesList();
  }

  void changeDisplayLimit(int limit) {
    displayLimit = limit;
    refreshNotesList();
  }

  Future<void> loadSavedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    folderPath = prefs.getString('folder_path');

    await dbService.db;

    if (folderPath != null) {
      // NEW: Check permission before trying to load files on boot
      if (Platform.isAndroid) {
        if (!await Permission.manageExternalStorage.isGranted &&
            !await Permission.storage.isGranted) {
          // If permission was revoked, wait for the user to grant it manually later
          isLoading = false;
          notifyListeners();
          return;
        }
      }

      await refreshNotesList();
      _startWatchingDirectory(folderPath!);
      _syncFolderMassive(folderPath!);
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshNotesList() async {
    String orderBy = 'updateAt DESC';
    if (currentSort == SortOption.alphaAsc) orderBy = 'title ASC';
    if (currentSort == SortOption.alphaDesc) orderBy = 'title DESC';

    allNotes = await dbService.getAllNotes(
      limit: displayLimit,
      orderBy: orderBy,
    );
    notifyListeners();
  }

  Future<void> selectFolder() async {
    // --- NEW: Request Storage Permissions First! ---
    if (Platform.isAndroid) {
      // For Android 11+ (API 30+)
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      // For Android 10 and below
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }

      // Verify they actually granted it
      if (!await Permission.manageExternalStorage.isGranted &&
          !await Permission.storage.isGranted) {
        print("Storage permission denied. Cannot read files.");
        return; // Stop here if user denied permission
      }
    }
    // ----------------------------------------------

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Select your desired folder",
    );

    if (selectedDirectory != null) {
      isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('folder_path', selectedDirectory);
      folderPath = selectedDirectory;

      await dbService.clearAllNotes();
      await refreshNotesList();

      isLoading = false;
      notifyListeners();

      _startWatchingDirectory(selectedDirectory);
      _syncFolderMassive(selectedDirectory);
    }
  }

  // --- NEW: Force Rescan for Android Reinstalls ---
  Future<void> forceRescan() async {
    if (folderPath != null) {
      // In case files were skipped due to permission timing, clear DB to fetch fresh.
      await dbService.clearAllNotes();
      await _syncFolderMassive(folderPath!);
    }
  }

  Future<void> _syncFolderMassive(String path) async {
    if (isSyncingBackground) return;

    isSyncingBackground = true;
    notifyListeners();

    try {
      final directory = Directory(path);
      final entities = await directory.list(recursive: true).toList();
      final mdFiles = entities
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.md'))
          .toList();

      final int batchSize = 50;
      for (int i = 0; i < mdFiles.length; i += batchSize) {
        final end = (i + batchSize < mdFiles.length)
            ? i + batchSize
            : mdFiles.length;
        final batch = mdFiles.sublist(i, end);
        List<Note> notesBatch = [];

        for (var file in batch) {
          final stat = await file.stat();
          final content = await file.readAsString();
          final title = file.uri.pathSegments.last.replaceAll('.md', '');

          notesBatch.add(
            Note()
              ..title = title
              ..content = content
              ..filePath = file.path
              ..updateAt = stat.modified,
          );
        }

        await dbService.saveNotesBatch(notesBatch);
        await refreshNotesList();

        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      print("Background mass sync error: $e");
    }

    isSyncingBackground = false;
    notifyListeners();
  }

  Future<void> disconnectFolder() async {
    _stopWatchingDirectory();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('folder_path');
    folderPath = null;
    await dbService.clearAllNotes();
    allNotes.clear();
    notifyListeners();
  }

  Future<void> createAndSaveNote(String title, String content) async {
    if (folderPath == null) return;

    String safeTitle = title
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    if (safeTitle.isEmpty) safeTitle = "Untitled";

    String fullPath = "$folderPath/$safeTitle.md";
    File file = File(fullPath);
    await file.writeAsString(content);
  }

  Future<void> updateNote(Note note, String newTitle, String newContent) async {
    try {
      final oldFile = File(note.filePath);

      String safeTitle = newTitle
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      if (safeTitle.isEmpty) safeTitle = "Untitled";
      String newPath = "$folderPath/$safeTitle.md";

      if (note.filePath != newPath) {
        if (await oldFile.exists()) await oldFile.delete();
      }

      final newFile = File(newPath);
      await newFile.writeAsString(newContent);
    } catch (e) {
      print("Error updating note: $e");
    }
  }

  void _startWatchingDirectory(String path) {
    _stopWatchingDirectory();
    final directory = Directory(path);
    if (!directory.existsSync()) return;

    _directoryWatcher = directory.watch(recursive: true).listen((event) {
      _handleFileSystemEvent(event);
    });
  }

  void _stopWatchingDirectory() {
    _directoryWatcher?.cancel();
    _directoryWatcher = null;
    for (var timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  void _handleFileSystemEvent(FileSystemEvent event) {
    if (event is FileSystemMoveEvent) {
      if (event.destination != null && event.destination!.endsWith(".md")) {
        _debounceAction(
          event.destination!,
          () => _processFileMove(event.path, event.destination!),
        );
      } else {
        _debounceAction(event.path, () => _processFileDelete(event.path));
      }
    } else if (event is FileSystemDeleteEvent) {
      if (event.path.endsWith('.md')) {
        _debounceAction(event.path, () => _processFileDelete(event.path));
      }
    } else if (event is FileSystemCreateEvent ||
        event is FileSystemModifyEvent) {
      if (event.path.endsWith('.md')) {
        _debounceAction(event.path, () => _processFileChange(event.path));
      }
    }
  }

  Future<void> _processFileMove(String rawOldPath, String rawNewPath) async {
    try {
      final oldPath = File(rawOldPath).absolute.path;
      final newPath = File(rawNewPath).absolute.path;

      lastMovedFromPath = oldPath;
      lastMovedToPath = newPath;

      final existingNote = await dbService.getNoteByPath(oldPath);
      final file = File(newPath);

      if (!await file.exists()) return;

      final stat = await file.stat();
      final content = await file.readAsString();
      final title = file.uri.pathSegments.last.replaceAll('.md', '');

      final note = existingNote ?? Note();
      note.title = title;
      note.content = content;
      note.filePath = newPath;
      note.updateAt = stat.modified;

      await dbService.saveNoteIndex(note);
      if (existingNote == null) await dbService.deleteNoteByPath(oldPath);
      await refreshNotesList();

      Future.delayed(const Duration(milliseconds: 500), () {
        if (lastMovedFromPath == oldPath) lastMovedFromPath = null;
        if (lastMovedToPath == newPath) lastMovedToPath = null;
      });
    } catch (e) {
      print("File move error: $e");
    }
  }

  void _debounceAction(String path, Future<void> Function() action) {
    _debounceTimers[path]?.cancel();
    _debounceTimers[path] = Timer(const Duration(milliseconds: 500), () async {
      _debounceTimers.remove(path);
      await action();
    });
  }

  Future<void> _processFileChange(String rawpath) async {
    try {
      final file = File(rawpath);
      if (!await file.exists()) return;
      final path = file.absolute.path;

      final stat = await file.stat();
      final content = await file.readAsString();
      final title = file.uri.pathSegments.last.replaceAll('.md', '');

      final existingNote = await dbService.getNoteByPath(path);
      final note = existingNote ?? Note();
      note.title = title;
      note.content = content;
      note.filePath = path;
      note.updateAt = stat.modified;

      await dbService.saveNoteIndex(note);
      await refreshNotesList();
    } catch (e) {
      print("File change error: $e");
    }
  }

  Future<void> _processFileDelete(String rawpath) async {
    try {
      final path = File(rawpath).absolute.path;
      await dbService.deleteNoteByPath(path);
      await refreshNotesList();
    } catch (e) {
      print("File delete error: $e");
    }
  }

  Future<void> deleteNoteFile(Note note) async {
    try {
      final file = File(note.filePath);
      if (await file.exists()) await file.delete();
      await dbService.deleteNoteByPath(note.filePath);
      await refreshNotesList();
    } catch (e) {
      print("Error deleting note file: $e");
    }
  }

  Map<String, List<Note>> get clusteredNotes {
    final Map<String, List<Note>> clusters = {};
    for (var note in allNotes) {
      for (var tag in note.tags) {
        if (!clusters.containsKey(tag)) clusters[tag] = [];
        clusters[tag]!.add(note);
      }
    }
    return clusters;
  }
}
