import '../../domain/entities/task.dart';

class TaskModel extends Task {
  const TaskModel({
    required super.id,
    required super.boardId,
    required super.title,
    required super.description,
    required super.status,
    super.assigneeId,
    super.creatorId,
    super.dueAt,
    required super.createdAt,
  });

  // Chuyển từ SQLite (Map) sang Model
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      boardId: map['board_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      status: map['status'] as String,
      assigneeId: map['assignee_id'] as String?,
      creatorId: map['creator_id'] as String?,
      dueAt: map['due_at'] != null
          ? DateTime.tryParse(map['due_at'] as String)
          : null,
      createdAt: map['created_at'] as String,
    );
  }

  // Chuyển từ Model sang SQLite (Map) để lưu trữ
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'board_id': boardId,
      'title': title,
      'description': description,
      'status': status,
      if (assigneeId != null) 'assignee_id': assigneeId,
      if (creatorId != null) 'creator_id': creatorId,
      if (dueAt != null) 'due_at': dueAt!.toUtc().toIso8601String(),
      'created_at': createdAt,
    };
  }
}
