import 'package:cloud_firestore/cloud_firestore.dart'; // Tambahkan jika dibutuhkan
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:catatan_kuliah/models/note_model.dart';    
import 'package:catatan_kuliah/services/firebase_service.dart';

class AddNoteScreen extends StatefulWidget {
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

  // Mendapatkan UID Pengguna yang sedang aktif login
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.noteDataToEdit != null;

    if (_isEditMode) {
      _titleController.text = widget.noteDataToEdit!['title'] ?? '';
      _contentController.text = widget.noteDataToEdit!['content'] ?? '';
    }
    _loadCourses();
  }

  // REVISI LOGIKA: Mengambil daftar mata kuliah dari folder privat pengguna aktif
  void _loadCourses() async {
    if (_currentUid == null) {
      if (mounted) {
        setState(() {
          _courses = [];
        });
      }
      return;
    }

    try {
      // Jalur diubah dari 'courses' umum menjadi 'users_courses / $currentUid' privat
      final snapshot = await _firebaseService.dbRef.child('users_courses').child(_currentUid!).get();
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
            
            if (_isEditMode) {
              _selectedCourse = _courses.firstWhere(
                (course) => course['id'] == widget.noteDataToEdit!['courseId'],
                orElse: () => {},
              );
              if (_selectedCourse!.isEmpty) _selectedCourse = null;
            }
          });
        }
      } else {
        // Jika data di database memang belum ada (User baru login/belum input matkul)
        if (mounted) {
          setState(() {
            _courses = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error load courses: $e');
    }
  }

  // Mengamankan proses simpan dan edit catatan ke dalam folder UID masing-masing
  Future<void> _submitNote() async {
    if (_currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi telah berakhir, silakan login kembali.')));
      return;
    }

    if (_selectedCourse == null || _titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap lengkapi semua form!')));
      return;
    }

    setState(() => _isUploading = true);

    try {
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
        noteData['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
        final String noteId = widget.noteDataToEdit!['id'];
        
        await _firebaseService.dbRef
            .child('users_notes')
            .child(_currentUid!)
            .child(noteId)
            .update(noteData);
      } else {
        await _firebaseService.dbRef
            .child('users_notes')
            .child(_currentUid!)
            .push()
            .set(noteData);
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