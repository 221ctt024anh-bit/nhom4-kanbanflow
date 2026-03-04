// File: lib/data/models/task_model.dart

class TaskModel {
  final int? id;
  final String title;
  final String description;
  final String status; // Trạng thái của cột: 'todo', 'doing', 'done'

  TaskModel({
    this.id,
    required this.title,
    required this.description,
    required this.status,
  });

  // Chuyển đối tượng Task thành Map để lưu vào SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
    };
  }

  // Đọc dữ liệu từ SQLite (Map) và chuyển ngược lại thành đối tượng Task
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      status: map['status'] as String,
    );
  }
}