import 'dart:convert';
import '../../domain/entities/task.dart';

class TaskModel extends Task {
  const TaskModel({
    required super.id,
    required super.boardId,
    required super.title,
    required super.description,
    required super.status,
    super.assigneeIds = const [],
    super.creatorId,
    super.dueAt,
    required super.createdAt,
    super.updatedAt,
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

    // Parse assigneeIds from Supabase nested query or SQLite JSON
    List<String> assigneeIds = [];
    final assigneesRaw = map['task_assignees'];
    if (assigneesRaw is List) {
      assigneeIds = assigneesRaw
          .map((e) => (e as Map<String, dynamic>)['user_id'] as String)
          .toList();
    } else if (map['assignee_ids'] is String) {
      try {
        assigneeIds = (jsonDecode(map['assignee_ids'] as String) as List)
            .cast<String>();
      } catch (_) {}
    } else if (map['assignee_id'] != null) {
      // Fallback for migration or old schema
      assigneeIds = [map['assignee_id'] as String];
    }

    return TaskModel(
      id: map['id'] as String,
      boardId: map['board_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      status: map['status'] as String,
      assigneeIds: assigneeIds,
      creatorId: map['creator_id'] as String?,
      dueAt: map['due_at'] != null
          ? DateTime.tryParse(map['due_at'] as String)?.toLocal()
          : null,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
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
      'assignee_ids': jsonEncode(assigneeIds),
      'assignee_id': assigneeIds.isNotEmpty ? assigneeIds.first : null,
      if (creatorId != null) 'creator_id': creatorId,
      if (dueAt != null) 'due_at': dueAt!.toUtc().toIso8601String(),
      'created_at': createdAt,
      'updated_at': updatedAt,
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
      'creator_id': creatorId,
      'due_at': dueAt?.toUtc().toIso8601String(),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'checklist': jsonEncode(checklist.map((e) => e.toMap()).toList()),
      'has_attachments': hasAttachments,
      'task_type': taskType ?? 'text',
    };
  }

  Map<String, dynamic> toMap() => toSQLiteMap();
}
