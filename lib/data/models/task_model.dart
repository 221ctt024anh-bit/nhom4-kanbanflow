import 'dart:convert';
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
    super.checklist,
    super.hasAttachments = false,
    super.taskType = 'text',
  });

  // Chuyển từ SQLite (Map) sang Model
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    final checklistRaw = map['checklist'] as String?;
    List<ChecklistItem> checklist = [];
    if (checklistRaw != null && checklistRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(checklistRaw) as List;
        checklist = decoded
            .map((e) => ChecklistItem.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return TaskModel(
      id: map['id'] as String,
      boardId: map['board_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      status: map['status'] as String,
      assigneeId: map['assignee_id'] as String?,
      creatorId: map['creator_id'] as String?,
      dueAt: map['due_at'] != null
          ? DateTime.tryParse(map['due_at'] as String)?.toLocal()
          : null,
      createdAt: map['created_at'] as String,
      checklist: checklist,
      hasAttachments: map['has_attachments'] is bool
          ? map['has_attachments'] as bool
          : (map['has_attachments'] as int? ?? 0) == 1,
      taskType: map['task_type'] as String? ?? 'text',
    );
  }

  // Chuyển sang Map cho SQLite (Sử dụng 0/1 cho boolean)
  Map<String, dynamic> toSQLiteMap() {
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
      'checklist': jsonEncode(checklist.map((e) => e.toMap()).toList()),
      'has_attachments': hasAttachments ? 1 : 0,
      'task_type': taskType ?? 'text',
    };
  }

  // Chuyển sang Map cho Supabase (Sử dụng true/false cho boolean)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'board_id': boardId,
      'title': title,
      'description': description,
      'status': status,
      'assignee_id': assigneeId,
      'creator_id': creatorId,
      'due_at': dueAt?.toUtc().toIso8601String(),
      'created_at': createdAt,
      'checklist': jsonEncode(checklist.map((e) => e.toMap()).toList()),
      'has_attachments': hasAttachments,
      'task_type': taskType ?? 'text',
    };
  }

  Map<String, dynamic> toMap() => toSQLiteMap();
}
