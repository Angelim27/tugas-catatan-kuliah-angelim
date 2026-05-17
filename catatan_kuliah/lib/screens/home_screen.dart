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

  // Atribut tambahan untuk menyimpan opsi pengurutan yang sedang aktif
  // Opsi: 'terbaru', 'terlama', 'abjad'
  String _currentSortOption = 'terbaru'; 

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

  void _getNotesRealtime() {
    _firebaseService.dbRef.child('notes').onValue.listen((event) {
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

  // LOGIKA BARU: Fungsi khusus untuk mengurutkan list catatan berdasarkan pilihan user
  void _sortNotesList(String option) {
    _currentSortOption = option;
    
    if (option == 'terbaru') {
      _notesList.sort((a, b) {
        final int timestampA = a['timestamp'] ?? 0;
        final int timestampB = b['timestamp'] ?? 0;
        return timestampB.compareTo(timestampA); // Descending
      });
    } else if (option == 'terlama') {
      _notesList.sort((a, b) {
        final int timestampA = a['timestamp'] ?? 0;
        final int timestampB = b['timestamp'] ?? 0;
        return timestampA.compareTo(timestampB); // Ascending
      });
    } else if (option == 'abjad') {
      _notesList.sort((a, b) {
        final String titleA = (a['courseName'] ?? '').toString().toLowerCase();
        final String titleB = (b['courseName'] ?? '').toString().toLowerCase();
        return titleA.compareTo(titleB); // A-Z berdasarkan Nama Makul
      });
    }

    // Perbarui daftar filtered agar visual layar langsung berubah
    if (!_isSearching) {
      _filteredNotesList = List.from(_notesList);
    } else {
      _filterNotes(_searchController.text);
    }
  }

  // Bonus: Pencarian Catatan
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
                if (nameController.text.trim().isEmpty || lecturerController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua field wajib diisi!')));
                  return;
                }
                try {
                  await _firebaseService.saveCourse(nameController.text.trim(), lecturerController.text.trim());
                  if (!context.mounted) return;
                  Navigator.pop(context);
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
          
          // TOMBOL BARU: Pop-up Menu Pengurutan di sebelah kanan AppBar
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Urutkan Catatan',
            onSelected: (String value) {
              setState(() {
                _sortNotesList(value); // Jalankan fungsi sortir sesuai pilihan
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
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text('Angelim', style: TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text('NPM: 2327240084'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.deepPurple, size: 40),
              ),
              decoration: BoxDecoration(color: Colors.deepPurple),
            ),
            ListTile(
              leading: const Icon(Icons.class_, color: Colors.deepPurple),
              title: const Text(
                'Daftar Mata Kuliah',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
              onTap: () {
                Navigator.pop(context); // Menutup laci drawer terlebih dahulu
                // Navigasi masuk ke halaman daftar mata kuliah yang sudah dibuat tadi
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CourseListScreen()),
                );
              },
            ),

            // Garis pembatas tipis agar tampilan menu terlihat rapi dan profesional
            const Divider(height: 1, thickness: 0.5),
            
            ListTile(
              leading: const Icon(Icons.dark_mode, color: Colors.deepPurple),
              title: const Text(
                'Dark Mode',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
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
                                      // REVISI DI SINI: Membuka dialog konfirmasi sebelum benar-benar menghapus ke Firebase
                                      else if (value == 'delete' && note['id'] != null) {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false, // User wajib memilih salah satu tombol, tidak bisa asal klik di luar dialog
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
                                                // Tombol Batal
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context); // Menutup dialog tanpa menghapus apa-apa
                                                  },
                                                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                                                ),
                                                // Tombol Hapus (Eksekusi)
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red.shade50,
                                                    elevation: 0,
                                                  ),
                                                  onPressed: () async {
                                                    Navigator.pop(context); // Tutup dialognya dulu
                                                    await _firebaseService.deleteNote(note['id']); // Baru eksekusi hapus data dari Firebase
                                                    
                                                    // Memberikan feedback sukses berupa SnackBar kecil di bawah layar
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