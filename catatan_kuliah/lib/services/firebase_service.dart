import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

  // Simpan mata kuliah baru
  Future<void> saveCourse(String name, String lecturer) async {
    await dbRef.child('courses').push().set({
      'name': name,
      'lecturer': lecturer,
    });
  }

  // Simpan catatan baru
  Future<void> saveNote(Map<String, dynamic> noteData) async {
    await dbRef.child('notes').push().set(noteData);
  }

  // Hapus catatan berdasarkan ID
  Future<void> deleteNote(String noteId) async {
    await dbRef.child('notes').child(noteId).remove();
  }
}