import 'package:flutter/material.dart';
import '../models/note_model.dart';      // Import Model
import '../services/firebase_service.dart'; // Import Service

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  bool _isUploading = false;
  List<Map<dynamic, dynamic>> _courses = [];
  Map<dynamic, dynamic>? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses() async {
    try {
      final snapshot = await _firebaseService.dbRef.child('courses').get();
      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<dynamic, dynamic>> tempData = [];
        data.forEach((key, value) {
          final courseItem = Map<dynamic, dynamic>.from(value);
          courseItem['id'] = key;
          tempData.add(courseItem);
        });
        if (mounted) setState(() => _courses = tempData);
      }
    } catch (e) {
      debugPrint('Error load courses: $e');
    }
  }

  Future<void> _submitNote() async {
    if (_selectedCourse == null || _titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap lengkapi semua form!')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Menggunakan Model untuk menyusun data Map
      final noteData = NoteModel.createNoteMap(
        courseId: _selectedCourse!['id'],
        courseName: _selectedCourse!['name'],
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Mengirim data melalui Service
      await _firebaseService.saveNote(noteData);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catatan disimpan!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Catatan'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Mata Kuliah', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<Map<dynamic, dynamic>>(
              value: _selectedCourse,
              hint: const Text('Pilih Mata Kuliah'),
              items: _courses.map((course) {
                return DropdownMenuItem<Map<dynamic, dynamic>>(value: course, child: Text(course['name'] ?? ''));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCourse = val),
            ),
            const SizedBox(height: 16),
            const Text('Judul Catatan', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _titleController, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 16),
            const Text('Isi Catatan', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _contentController, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isUploading ? null : _submitNote,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isUploading 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Text('SIMPAN CATATAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}