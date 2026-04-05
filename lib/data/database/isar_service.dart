import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';

class IsarService {
  //late is for "i promise to initialize this before using"
  late Future<Isar> db;

  IsarService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    //check if its already open so we dont crash the app
    if (Isar.instanceNames.isEmpty) {
      //get the safe, hidden system directory "not the user's folder"
      final dir = await getApplicationDocumentsDirectory();

      return await Isar.open(
        [NoteSchema], //this comes from note.g.dart
        directory: dir.path,
      );
    }
    return Future.value(Isar.getInstance());
  }

  Future<void> saveNoteIndex(Note newNote) async {
    final isar = await db;

    //doing an edit
    await isar.writeTxn(() async {
      await isar.notes.put(newNote); //an update
    });
  }

  //fetch all notes to show on the home page
  Future<List<Note>> getAllNotes() async {
    final isar = await db;
    return await isar.notes.where().sortByTitle().findAll();
  }

  //supa mega fast search (check title or content)
  Future<List<Note>> searchNotes(String query) async {
    final isar = await db;
    return await isar.notes
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .contentContains(query, caseSensitive: false)
        .findAll();
  }
}
