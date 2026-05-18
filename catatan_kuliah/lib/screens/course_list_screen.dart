import 'package:catatan_kuliah/screens/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:catatan_kuliah/services/firebase_service.dart';
import 'package:catatan_kuliah/services/theme_provider.dart'; 
import 'package:catatan_kuliah/screens/sign_in_screen.dart'; 

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<dynamic, dynamic>> _coursesList = [];
  bool _isLoading = true;

  // Mendapatkan UID Pengguna yang aktif saat ini
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _coursesListLive();
  }

  // Membaca daftar mata kuliah secara dinamis per akun/UID masing-masing
  void _coursesListLive() {
    if (_currentUid == null) {
      if (mounted) {
        setState(() {
          _coursesList = [];
          _isLoading = false;
        });
      }
      return;
    }

    _firebaseService.dbRef.child('users_courses').child(_currentUid!).onValue.listen((event) {
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

      if (mounted) {
        setState(() {
          _coursesList = temporaryList;
          _isLoading = false;
        });
      }
    });
  }

  Color _getCourseColor(String courseName) {
    final colors = [Colors.deepPurple, Colors.green, Colors.orange, Colors.blue, Colors.pink];
    return colors[courseName.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Mata Kuliah'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer(); 
              },
            );
          },
        ),
      ),
      
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 1. Header Profil Pengguna 
                  FutureBuilder<DocumentSnapshot>(
                    future: _currentUid != null 
                        ? FirebaseFirestore.instance.collection('users').doc(_currentUid).get()
                        : null,
                    builder: (context, snapshot) {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      
                      String userName = 'Sign Up';
                      String userEmail = 'Silakan masuk ke akun Anda';

                      if (currentUser != null) {
                        userEmail = currentUser.email ?? 'Tidak ada email';
                        
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          userName = data?['fullName'] ?? 'Pengguna';
                        } else if (snapshot.connectionState == ConnectionState.waiting) {
                          userName = 'Memuat nama...';
                        } else {
                          userName = 'Pengguna';
                        }
                      }

                      return InkWell(
                        onTap: () {
                          if (currentUser == null) {
                            Navigator.pop(context); 
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignInScreen(), 
                              ),
                            );
                          }
                        },
                        child: UserAccountsDrawerHeader(
                          accountName: Row(
                            children: [
                              Text(
                                userName, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              if (currentUser == null) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                              ],
                            ],
                          ),
                          accountEmail: Text(userEmail),
                          currentAccountPicture: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, color: Colors.deepPurple, size: 40),
                          ),
                          decoration: const BoxDecoration(color: Colors.deepPurple),
                        ),
                      );
                    },
                  ),

                  // 2. Menu Daftar Mata Kuliah
                  ListTile(
                    leading: const Icon(Icons.class_, color: Colors.deepPurple),
                    title: const Text('Daftar Mata Kuliah', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    onTap: () {
                      Navigator.pop(context); 
                    },
                  ),

                  // 3. Menu Daftar Catatan 
                  ListTile(
                    leading: const Icon(Icons.class_, color: Colors.deepPurple),
                    title: const Text('Daftar Catatan ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                      );
                    },
                  ),

                  // 4. Menu Switch Dark Mode
                  ListTile(
                    leading: const Icon(Icons.dark_mode, color: Colors.deepPurple),
                    title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      activeColor: Colors.deepPurple,
                      onChanged: (value) {
                        themeProvider.toggleTheme(); 
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Tombol Logout di dasar laci 
            const Divider(height: 1, thickness: 0.5),
            SafeArea(
              top: false,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Keluar Akun (Log Out)',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Colors.red),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Konfirmasi Keluar'),
                          ],
                        ),
                        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              elevation: 0,
                            ),
                            onPressed: () async {
                              Navigator.pop(context); 
                              Navigator.pop(context); 
                              
                              setState(() {}); 
                              
                              await FirebaseAuth.instance.signOut(); 
                            },
                            child: const Text(
                              'Keluar',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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