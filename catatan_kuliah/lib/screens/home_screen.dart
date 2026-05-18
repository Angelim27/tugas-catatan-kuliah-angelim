import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:catatan_kuliah/services/firebase_service.dart';
import 'package:catatan_kuliah/services/theme_provider.dart'; 
import 'package:catatan_kuliah/screens/add_note_screen.dart';
import 'package:catatan_kuliah/screens/note_detail_screen.dart';
import 'package:catatan_kuliah/screens/course_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  List<Map<dynamic, dynamic>> _notesList = [];         
  List<Map<dynamic, dynamic>> _filteredNotesList = []; 
  
  bool _isLoading = true;
  bool _isSearching = false;                                                                       
  final TextEditingController _searchController = TextEditingController();

  String _currentSortOption = 'terbaru'; 

  // Ambil UID Pengguna yang sedang aktif login saat ini
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _getNotesRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // REVISI LOGIKA: Membaca database secara privat berdasarkan akun/UID masing-masing
  void _getNotesRealtime() {
    if (_currentUid == null) {
      if (mounted) {
        setState(() {
          _notesList = [];
          _filteredNotesList = [];
          _isLoading = false;
        });
      }
      return;
    }

    // Jalur penyimpanan diubah ke 'users_notes' -> ID Unik User
    _firebaseService.dbRef.child('users_notes').child(_currentUid!).onValue.listen((event) {
      final Map<dynamic, dynamic>? snapshotValue = event.snapshot.value as Map<dynamic, dynamic>?;
      if (snapshotValue == null) {
        if (mounted) {
          setState(() {
            _notesList = [];
            _filteredNotesList = [];
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

      if (mounted) {
        setState(() {
          _notesList = temporaryList;
          
          // Jalankan fungsi pengurutan & filter data
          _sortNotesList(_currentSortOption);
          
          if (_isSearching) {
            _filterNotes(_searchController.text);
          }
          _isLoading = false;
        });
      }
    });
  }

  void _sortNotesList(String option) {
    _currentSortOption = option;
    
    if (option == 'terbaru') {
      _notesList.sort((a, b) {
        final int timestampA = a['timestamp'] ?? 0;
        final int timestampB = b['timestamp'] ?? 0;
        return timestampB.compareTo(timestampA); 
      });
    } else if (option == 'terlama') {
      _notesList.sort((a, b) {
        final int timestampA = a['timestamp'] ?? 0;
        final int timestampB = b['timestamp'] ?? 0;
        return timestampA.compareTo(timestampB); 
      });
    } else if (option == 'abjad') {
      _notesList.sort((a, b) {
        final String titleA = (a['courseName'] ?? '').toString().toLowerCase();
        final String titleB = (b['courseName'] ?? '').toString().toLowerCase();
        return titleA.compareTo(titleB); 
      });
    }

    if (!_isSearching) {
      _filteredNotesList = List.from(_notesList);
    } else {
      _filterNotes(_searchController.text);
    }
  }

  void _filterNotes(String query) {
    List<Map<dynamic, dynamic>> results = [];
    if (query.isEmpty) {
      results = _notesList;
    } else {
      results = _notesList.where((note) {
        final courseName = (note['courseName'] ?? '').toString().toLowerCase();
        final title = (note['title'] ?? '').toString().toLowerCase();
        final searchQuery = query.toLowerCase();
        return courseName.contains(searchQuery) || title.contains(searchQuery);
      }).toList();
    }
    setState(() {
      _filteredNotesList = results;
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
              TextField(controller: nameController, decoration: const InputDecoration(hintText: "Nama Mata Kuliah")),
              const SizedBox(height: 8),
              TextField(controller: lecturerController, decoration: const InputDecoration(hintText: "Nama Dosen")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (_currentUid == null) return; // Keamanan dasar jika sesi kosong

                if (nameController.text.trim().isEmpty || lecturerController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua field wajib diisi!')));
                  return;
                }
                try {
                  // REVISI LOGIKA: Menyimpan mata kuliah khusus di folder UID milik user sendiri
                  await _firebaseService.dbRef
                      .child('users_courses')
                      .child(_currentUid!)
                      .push()
                      .set({
                        'name': nameController.text.trim(),
                        'lecturer': lecturerController.text.trim(),
                        'createdAt': DateTime.now().millisecondsSinceEpoch,
                      });

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mata kuliah berhasil ditambahkan!'), backgroundColor: Colors.green),
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

  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy • HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Cari catatan...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (value) => _filterNotes(value),
              )
            : const Text('Catatan Kuliah'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _filteredNotesList = _notesList;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Urutkan Catatan',
            onSelected: (String value) {
              setState(() {
                _sortNotesList(value); 
              });
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'terbaru',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, color: _currentSortOption == 'terbaru' ? Colors.deepPurple : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Terbaru'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'terlama',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, color: _currentSortOption == 'terlama' ? Colors.deepPurple : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Terlama'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'abjad',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, color: _currentSortOption == 'abjad' ? Colors.deepPurple : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Abjad (A-Z)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: Column( 
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 1. Header Profil Pengguna (Dinamis dari Firestore)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(_currentUid)
                        .get(),
                    builder: (context, snapshot) {
                      final String userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Tidak ada email';
                      String userName = 'Memuat nama...';

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        userName = data?['fullName'] ?? 'Pengguna';
                      }

                      return UserAccountsDrawerHeader(
                        accountName: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        accountEmail: Text(userEmail),
                        currentAccountPicture: const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Colors.deepPurple, size: 40),
                        ),
                        decoration: const BoxDecoration(color: Colors.deepPurple),
                      );
                    },
                  ),

                  // 2. Menu Daftar Mata Kuliah
                  ListTile(
                    leading: const Icon(Icons.class_, color: Colors.deepPurple),
                    title: const Text('Daftar Mata Kuliah', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CourseListScreen()),
                      );
                    },
                  ),

                  // 3. Menu Daftar Catatan
                  ListTile(
                    leading: const Icon(Icons.class_, color: Colors.deepPurple),
                    title: const Text('Daftar Catatan', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    onTap: () {
                      Navigator.pop(context); // Cukup tutup lacinya saja
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

            // Bagian Bawah: Mengunci tombol Logout di dasar laci samping
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
                  // Kotak Dialog Konfirmasi Keluar
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
                              // REVISI PENUTUPAN: Menutup dialog dan laci sebelum membersihkan token sesi login
                              Navigator.pop(context); // Tutup dialog
                              Navigator.pop(context); // Tutup drawer laci
                              
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Daftar Catatan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                      IconButton(
                        icon: const Icon(Icons.add_home_work, color: Colors.deepPurple),
                        onPressed: _showAddCourseDialog,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredNotesList.isEmpty
                      ? const Center(child: Text('Tidak ada catatan.'))
                      : ListView.builder(
                          itemCount: _filteredNotesList.length,
                          itemBuilder: (context, index) {
                            final note = _filteredNotesList[index];
                            final itemColor = _getCourseColor(note['courseName'] ?? '');

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NoteDetailScreen(note: note),
                                    ),
                                  );
                                },
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: itemColor.withOpacity(0.2),
                                    child: Icon(Icons.book, color: itemColor),
                                  ),
                                  title: Text(note['courseName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(note['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(note['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            note['updatedAt'] != null ? Icons.edit_calendar : Icons.access_time, 
                                            size: 12, 
                                            color: note['updatedAt'] != null ? Colors.deepPurple : Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              note['updatedAt'] != null
                                                  ? 'Catatan diperbarui: ${_formatTimestamp(note['updatedAt'])}'
                                                  : _formatTimestamp(note['timestamp'] ?? 0),
                                              style: TextStyle(
                                                fontSize: 12, 
                                                color: note['updatedAt'] != null ? Colors.deepPurple : Colors.grey,
                                                fontWeight: note['updatedAt'] != null ? FontWeight.w500 : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => AddNoteScreen(noteDataToEdit: note)),
                                        );
                                      } 
                                      else if (value == 'delete' && note['id'] != null) {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Row(
                                                children: [
                                                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Hapus Catatan'),
                                                ],
                                              ),
                                              content: const Text('Apakah Anda yakin ingin menghapus catatan kuliah ini? Tindakan ini tidak dapat dibatalkan.'),
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
                                                    await _firebaseService.deleteNote(note['id']); 
                                                    
                                                    if (!context.mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Catatan berhasil dihapus'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  },
                                                  child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Edit')])),
                                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                                    ],
                                  ),
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