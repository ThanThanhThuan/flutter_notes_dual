// lib/notes_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notes_repository.dart';
import 'note_model.dart';
import 'local_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Repository provider (singleton)
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository();
});

/// Connectivity provider – emits `true` if online
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield (await connectivity.checkConnectivity()) != ConnectivityResult.none;
  await for (final event in connectivity.onConnectivityChanged) {
    yield event != ConnectivityResult.none;
  }
});

/// Stream of notes – switches between Firestore & local
final notesStreamProvider =
    StreamProvider.autoDispose<List<NoteModel>>((ref) async* {
  final repo = ref.watch(notesRepositoryProvider);
  final online = await ref.watch(connectivityProvider.future);

  if (online) {
    // Listen to Firestore
    yield* repo.firestoreStream();
  } else {
    // Offline – use local store
    yield* repo.localStream();
  }
});

final editModeProvider = StateProvider<bool>((ref) => false);
final selectedNoteProvider = StateProvider<NoteModel?>((ref) => null);
