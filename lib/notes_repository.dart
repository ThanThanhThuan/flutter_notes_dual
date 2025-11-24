// lib/notes_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'note_model.dart';
import 'local_storage.dart';

class NotesRepository {
  final FirebaseFirestore _firestore;
  final LocalStorage _localStorage;
  final Connectivity _connectivity;

  NotesRepository({
    FirebaseFirestore? firestore,
    LocalStorage? localStorage,
    Connectivity? connectivity,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _localStorage = localStorage ?? LocalStorage(),
        _connectivity = connectivity ?? Connectivity();

  /// Stream notes from Firestore ordered by date descending
  Stream<List<NoteModel>> firestoreStream() {
    return _firestore
        .collection('notes')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList());
  }

  /// Stream notes from local Hive store
  Stream<List<NoteModel>> localStream() async* {
    // A simple polling stream – emit the current list every 5 s
    while (true) {
      final notes = await _localStorage.getAllNotes();
      yield notes;
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  /// Add a note: try Firestore, otherwise fall back to local
  Future<void> addNote(NoteModel note) async {
    final connection = await _connectivity.checkConnectivity();
    final online = connection != ConnectivityResult.none;

    if (online) {
      try {
        await _firestore
            .collection('notes')
            .doc(note.id)
            .set(note.toFirestore());
      } catch (_) {
        // Firestore write failed → store locally
        // await _localStorage.saveNote(note);
      }
    } else {
      await _localStorage.saveNote(note);
    }
  }

  Future<void> deleteNote(String id) async {
    final connection = await _connectivity.checkConnectivity();
    final online = connection != ConnectivityResult.none;

    if (online) {
      try {
        // also delete from local
        await _localStorage.deleteNote(id);
        await _firestore.collection('notes').doc(id).delete();
      } catch (_) {
        // Firestore write failed → store locally
        await _localStorage.deleteNote(id);
      }
    } else {
      await _localStorage.deleteNote(id);
    }
  }

  Future<void> deleteNoteLocal(String id) async {
    await _localStorage.deleteNote(id);
  }

  /// Sync local cache with latest 50 docs from Firestore
  Future<void> syncLocalWithFirestore() async {
    final connection = await _connectivity.checkConnectivity();
    if (connection == ConnectivityResult.none) return; // No network

    final docsAll = await _firestore.collection('notes').get();

    final listAll =
        docsAll.docs.map((d) => NoteModel.fromFirestore(d)).toList();

    final allBoxNotes = await _localStorage.getAllNotes();

    final notesToAddToFireStore =
        allBoxNotes.where((element) => !listAll.contains(element)).toList();
// Add any missing notes to Firestore- Test OK
    for (var note in notesToAddToFireStore) {
      await _firestore.collection('notes').doc(note.id).set(note.toFirestore());
    }

    final docs = await _firestore
        .collection('notes')
        .orderBy('date', descending: true)
        .limit(50)
        .get();

    final latest = docs.docs.map((d) => NoteModel.fromFirestore(d)).toList();
    await _localStorage.syncToLatest50(latest);
  }

  /// Call this on app start (or whenever you want)
  Future<void> initSync() async {
    await syncLocalWithFirestore(); // try to catch up on boot
  }
}
