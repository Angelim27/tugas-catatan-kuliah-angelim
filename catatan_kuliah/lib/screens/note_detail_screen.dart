import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NoteDetailScreen extends StatelessWidget {
  final Map<dynamic, dynamic> note;

  const NoteDetailScreen({super.key, required this.note});

  // Fungsi helper format tanggal
  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy • HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdited = note['updatedAt'] != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Catatan'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Mata Kuliah Card
            Card(
              elevation: 0,
              color: Colors.deepPurple.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.deepPurple, width: 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.book, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note['courseName'] ?? 'Mata Kuliah',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dosen: ${note['lecturer'] ?? "Tidak ada nama dosen"}',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Judul Catatan
            const Text(
              'Judul Catatan:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              note['title'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 32, thickness: 1),

            // Isi Catatan
            const Text(
              'Isi Catatan:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              note['content'] ?? '',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const Divider(height: 40, thickness: 1),

            // Info Riwayat Waktu
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Dibuat: ${_formatTimestamp(note['timestamp'] ?? 0)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            if (isEdited) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.edit_calendar, size: 14, color: Colors.deepPurple),
                  const SizedBox(width: 6),
                  Text(
                    'Diperbarui: ${_formatTimestamp(note['updatedAt'])}',
                    style: const TextStyle(fontSize: 13, color: Colors.deepPurple, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}