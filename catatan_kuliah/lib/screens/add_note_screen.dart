import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:catatan_kuliah/models/note_model.dart';    
import 'package:catatan_kuliah/services/firebase_service.dart';

class AddNoteScreen extends StatefulWidget {
  // 1. Revisi nama parameter agar konsisten
  final Map<dynamic, dynamic>? noteDataToEdit;
  const AddNoteScreen({super.key, this.noteDataToEdit});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  bool _isUploading = false;
  bool _isEditMode = false;
  List<Map<dynamic, dynamic>> _courses = [];
  Map<dynamic, dynamic>? _selectedCourse;

  @override
  void initState() {
    super.initState();
    // 2. Revisi pemanggilan variabel widget yang benar
    _isEditMode = widget.noteDataToEdit != null;

    if (_isEditMode) {
      _titleController.text = widget.noteDataToEdit!['title'] ?? '';
      _contentController.text = widget.noteDataToEdit!['content'] ?? '';
    }
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
        
        if (mounted) {
          setState(() {
            _courses = tempData;
            
            // 3. Tambahan: Otomatis pilih mata kuliah yang sesuai jika dalam Mode Edit
            if (_isEditMode) {
              _selectedCourse = _courses.firstWhere(
                (course) => course['id'] == widget.noteDataToEdit!['courseId'],
                orElse: () => {},
              );
              if (_selectedCourse!.isEmpty) _selectedCourse = null;
            }
          });
        }
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
      // 1. Menyusun data dasar catatan
      final Map<String, dynamic> noteData = Map<String, dynamic>.from(
        NoteModel.createNoteMap(
          courseId: _selectedCourse!['id'],
          courseName: _selectedCourse!['name'],
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          timestamp: _isEditMode 
              ? widget.noteDataToEdit!['timestamp']
              : DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      noteData['lecturer'] = _selectedCourse!['lecturer'] ?? 'Tidak ada nama dosen';

      if (_isEditMode) {
        // 2. Jika di-edit, tambahkan properti 'updatedAt' dengan waktu sekarang
        noteData['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

        final String noteId = widget.noteDataToEdit!['id'];
        await _firebaseService.dbRef.child('notes').child(noteId).update(noteData);
      } else {
        await _firebaseService.saveNote(noteData);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditMode ? 'Catatan berhasil diperbarui!' : 'Catatan disimpan!')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 5. Revisi: Judul AppBar berubah dinamis sesuai mode
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Catatan' : 'Tambah Catatan'), 
        backgroundColor: Colors.deepPurple, 
        foregroundColor: Colors.white,
      ),
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
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              items: _courses.map((course) {
                return DropdownMenuItem<Map<dynamic, dynamic>>(
                  value: course, 
                  child: Text(course['name'] ?? ''),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCourse = val),
            ),
            const SizedBox(height: 16),
            const Text('Judul Catatan', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController, 
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 16),
            const Text('Isi Catatan', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController, 
              maxLines: 5, 
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isUploading ? null : _submitNote,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isUploading 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)))
                : Text(
                    _isEditMode ? 'PERBARUI CATATAN' : 'SIMPAN CATATAN', 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
            )
          ],
        ),
      ),
    );
  }
}