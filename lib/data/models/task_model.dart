import '../../domain/entities/task.dart';

class TaskModel extends Task {
  const TaskModel({
    required super.id,
    required super.boardId,
    required super.title,
    required super.description,
    required super.status,
    required super.createdAt,
  });

  // Chuyển từ SQLite (Map) sang Model
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      boardId: map['boardId'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      status: map['status'] as String,
      createdAt:
          (map['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }

  // Chuyển từ Model sang SQLite (Map) để lưu trữ
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'boardId': boardId,
      'title': title,
      'description': description,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
