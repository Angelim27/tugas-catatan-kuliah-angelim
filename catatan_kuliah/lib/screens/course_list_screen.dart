import 'package:flutter/material.dart';
import 'package:catatan_kuliah/services/firebase_service.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<dynamic, dynamic>> _coursesList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCoursesRealtime();
  }

  // Menarik data mata kuliah secara realtime dari Firebase
  void _fetchCoursesRealtime() {
    _firebaseService.dbRef.child('courses').onValue.listen((event) {
      final Map<dynamic, dynamic>? snapshotValue = event.snapshot.value as Map<dynamic, dynamic>?;
      
      if (snapshotValue == null) {
        if (mounted) {
          setState(() {
            _coursesList = [];
            _isLoading = false;
          });
        }
        return;
      }

      List<Map<dynamic, dynamic>> temporaryList = [];
      snapshotValue.forEach((key, value) {
        final courseData = Map<dynamic, dynamic>.from(value);
        courseData['id'] = key;
        temporaryList.add(courseData);
      });

      // Urutkan mata kuliah berdasarkan abjad A-Z
      temporaryList.sort((a, b) {
        final String nameA = (a['name'] ?? '').toString().toLowerCase();
        final String nameB = (b['name'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _coursesList = temporaryList;
          _isLoading = false;
        });
      }
    });
  }

  // Fungsi pembuat warna acak rapi berdasarkan nama makul
  Color _getCourseColor(String courseName) {
    final colors = [Colors.deepPurple, Colors.green, Colors.orange, Colors.blue, Colors.pink];
    return colors[courseName.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Mata Kuliah'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coursesList.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada mata kuliah terdaftar.',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _coursesList.length,
                  itemBuilder: (context, index) {
                    final course = _coursesList[index];
                    final String courseName = course['name'] ?? 'Mata Kuliah';
                    final String lecturerName = course['lecturer'] ?? 'Tidak ada nama dosen';
                    final Color itemColor = _getCourseColor(courseName);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: itemColor.withOpacity(0.15),
                          child: Icon(Icons.school, color: itemColor, size: 24),
                        ),
                        title: Text(
                          courseName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Dosen: $lecturerName',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}