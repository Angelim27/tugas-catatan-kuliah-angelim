import 'package:flutter/material.dart';
import '../services/firebase_service.dart'; 
import 'add_note_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<dynamic, dynamic>> _notesList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getNotesRealtime();
  }

  void _getNotesRealtime() {
    // Memantau data secara realtime lewat service
    _firebaseService.dbRef.child('notes').onValue.listen((event) {
      final Map<dynamic, dynamic>? snapshotValue = event.snapshot.value as Map<dynamic, dynamic>?;
      if (snapshotValue == null) {
        if (mounted) {
          setState(() {
            _notesList = [];
            _isLoading = false;
          });
        }
        return;
      }

      List<Map<dynamic, dynamic>> temporaryList = [];
      snapshotValue.forEach((key, value) {
        final noteData = Map<dynamic, dynamic>.from(value);
        noteData['id'] = key;
        temporaryList.add(noteData);
      });

      temporaryList.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      if (mounted) {
        setState(() {
          _notesList = temporaryList;
          _isLoading = false;
        });
      }
    });
  }

  void _showAddCourseDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController lecturerController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tambah Mata Kuliah'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: "Nama Mata Kuliah"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lecturerController,
                decoration: const InputDecoration(hintText: "Nama Dosen"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || lecturerController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Semua field wajib diisi!')),
                  );
                  return;
                }
                try {
                  // Memanggil fungsi dari Service
                  await _firebaseService.saveCourse(
                    nameController.text.trim(),
                    lecturerController.text.trim(),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mata kuliah berhasil ditambahkan!')),
                  );
                } catch (e) {
                  debugPrint('Failed to add course: $e');
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Color _getCourseColor(String courseName) {
    final colors = [Colors.deepPurple, Colors.green, Colors.orange, Colors.blue, Colors.pink];
    return colors[courseName.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Kuliah'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_home_work),
            onPressed: _showAddCourseDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Daftar Catatan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                Expanded(
                  child: _notesList.isEmpty
                      ? const Center(child: Text('Belum ada catatan kuliah.'))
                      : ListView.builder(
                          itemCount: _notesList.length,
                          itemBuilder: (context, index) {
                            final note = _notesList[index];
                            final itemColor = _getCourseColor(note['courseName'] ?? '');

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: itemColor.withOpacity(0.2),
                                  child: Icon(Icons.book, color: itemColor),
                                ),
                                title: Text(note['courseName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(note['title'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    if (note['id'] != null) {
                                      await _firebaseService.deleteNote(note['id']);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddNoteScreen()));
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}