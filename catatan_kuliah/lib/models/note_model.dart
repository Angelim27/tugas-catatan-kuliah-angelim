class NoteModel {
  static Map<String, dynamic> createNoteMap({
    required String courseId,
    required String courseName,
    required String title,
    required String content,
    required int timestamp,
  }) {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'title': title,
      'content': content,
      'timestamp': timestamp,
    };
  }
}