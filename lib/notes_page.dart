// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:notes_riverpod/main.dart';
import 'package:notes_riverpod/note_model.dart';
import 'package:notes_riverpod/notes_providers.dart';
import 'package:uuid/uuid.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Kick‑off initial sync when the app launches
    ref.read(notesRepositoryProvider).initSync();
  }

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.read(connectivityProvider);

    // 2. Access the current value using the .value property
    // .value returns T? (nullable), so it might be null if the stream hasn't emitted yet.

    if (asyncValue.hasValue) {
      final value = asyncValue.value!;
      if (value) {
        //Sync when online
        ref.read(notesRepositoryProvider).syncLocalWithFirestore();
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Riverpod Notes')),
      body: Column(
        children: [
          _buildComposer(),
          const Divider(height: 1),
          Expanded(child: _buildNotesList()),
        ],
      ),
    );
  }

  /// The large composer (TextField + Add button)
  Widget _buildComposer() {
    final editMode = ref.watch(editModeProvider);
    final selectedNote = ref.watch(selectedNoteProvider);
    _controller.text = selectedNote?.note ?? '';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              minLines: 5,
              decoration: const InputDecoration(
                hintText: 'Type your note…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              if (selectedNote != null && editMode)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat.yMMMd().add_jm().format(selectedNote.date)),
                    IconButton(
                        onPressed: () {
                          ref.read(selectedNoteProvider.notifier).state = null;
                          ref.read(editModeProvider.notifier).state = false;
                        },
                        icon: const Icon(Icons.close)),
                  ],
                ),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: editMode ? const Text('Update') : const Text('Add'),
                onPressed: _submitNote,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submitNote() async {
    final text = _controller.text.trim();
    final repo = ref.read(notesRepositoryProvider);
    if (text.isEmpty) return;
    String id = '';
    DateTime date = DateTime.now();
    if (ref.read(editModeProvider)) {
      id = ref.read(selectedNoteProvider)!.id;
      date = ref.read(selectedNoteProvider)!.date;
      // delete from local first
      await repo.deleteNoteLocal(id);
    } else {
      id = const Uuid().v4();
    }

    final note = NoteModel(
      id: id,
      date: date,
      note: text,
    );

    await repo.addNote(note);
    await repo.syncLocalWithFirestore(); // keep cache fresh

    _controller.clear();
    if (ref.read(editModeProvider)) {
      ref.read(selectedNoteProvider.notifier).state = null;
      ref.read(editModeProvider.notifier).state = false;
    }
  }

  /// List of notes from the provider
  Widget _buildNotesList() {
    return Consumer(builder: (context, ref, _) {
      final notesAsync = ref.watch(notesStreamProvider);
      return notesAsync.when(
        data: (notes) => ListView.builder(
          itemCount: notes.length,
          itemBuilder: (_, i) => _noteTile(notes[i]),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      );
    });
  }

  Widget _noteTile(NoteModel n) {
    final formatted = DateFormat.yMMMd().add_jm().format(n.date);

    // 1. Watch the stream provider
    final asyncConnectValue = ref.watch(connectivityProvider);
    return ListTile(
        title: Text(n.note, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(formatted),
        leading: const Icon(Icons.note),
        dense: true,
        onTap: () {
          // This code runs when the user taps the ListTile
          if (!ref.read(editModeProvider)) {
            ref.read(editModeProvider.notifier).state = true;
          }
          ref.read(selectedNoteProvider.notifier).state = n;
        },
        trailing: asyncConnectValue.when(
          // State: Data has successfully been received
          data: (bool value) {
            return IconButton(
              icon: const Icon(Icons.delete), //, color: Colors.red),
              onPressed: !value
                  ? null
                  : () async {
                      // show delete button only when online
                      final bool? didConfirm =
                          await showDeleteConfirmationDialog(context);

                      // Check if the result is true (user clicked 'Delete')
                      if (didConfirm == true) {
                        final repo = ref.read(notesRepositoryProvider);
                        repo.deleteNote(n.id);
                        // repo.syncLocalWithFirestore();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Item deleted successfully!'),
                            ),
                          );
                        }
                      }
                    },
            );
          },
          // State: Error occurred during streaming
          error: (Object error, StackTrace stackTrace) {
            return const Text('Err');
          },
          // State: Initial loading state
          loading: () {
            return const Text('...');
          },
        ));
  }
}

Future<bool?> showDeleteConfirmationDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
            'Are you sure you want to delete this item? This action cannot be undone.'),
        actions: <Widget>[
          TextButton(
            // Returns false to the Future, cancelling the delete
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            // Returns true to the Future, confirming the delete
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red, // Highlight the destructive action
            ),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
}
