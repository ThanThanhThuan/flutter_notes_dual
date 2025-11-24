// lib/local_storage.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'note_model.dart';

class LocalStorage {
  static const String _boxName = 'notesBox';

  Future<Box<NoteModel>> _openBox() async {
    return await Hive.openBox<NoteModel>(_boxName);
  }

  Future<void> saveNote(NoteModel note) async {
    final box = await _openBox();
    await box.put(note.id, note);
  }

  Future<void> deleteNote(String id) async {
    final box = await _openBox();
    for (var key in box.keys) {
      if (key == id) {
        await box.delete(key);
      }
    }
  }

  Future<List<NoteModel>> getAllNotes() async {
    final box = await _openBox();
    // Return in descending order
    return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> syncToLatest50(List<NoteModel> latest) async {
    final box = await _openBox();
    // Keep only the latest 50 docs
    final idsToKeep = latest.map((n) => n.id).toSet();

    // Delete older entries that are not in `idsToKeep`
    for (var key in box.keys) {
      if (!idsToKeep.contains(key)) {
        await box.delete(key);
      }
    }

    // Add any missing notes
    for (var note in latest) {
      if (!box.containsKey(note.id)) {
        await box.put(note.id, note);
      }
    }
  }
}
