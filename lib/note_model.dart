// lib/note_model.dart
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'note_model.g.dart';

@HiveType(typeId: 0)
class NoteModel {
  @HiveField(0)
  final String id; // Firestore generated or UUID

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final String note;

  NoteModel({
    required this.id,
    required this.date,
    required this.note,
  });

  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoteModel(
      id: data['id'] ?? doc.id,
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'date': Timestamp.fromDate(date),
        'note': note,
      };
}
