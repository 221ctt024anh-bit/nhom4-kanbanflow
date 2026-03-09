import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/local_database.dart';
import '../models/task_model.dart';
import '../repositories/notification_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  final NotificationRepository notificationRepository;
  final SupabaseClient supabaseClient;
  final LocalDatabase localDatabase;

  TaskRepositoryImpl({
    required this.supabaseClient,
    required this.notificationRepository,
    LocalDatabase? localDatabase,
  }) : localDatabase = localDatabase ?? LocalDatabase();

  @override
  Future<List<Task>> getTasks({
    String? boardId,
    String? query,
    String? status,
  }) async {
    try {
      await _syncPendingTaskOperations();

      var request = supabaseClient.from('tasks').select();

      if (boardId != null) {
        request = request.eq('board_id', boardId);
      }
      if (status != null) {
        request = request.eq('status', status);
      }
      if (query != null && query.isNotEmpty) {
        request = request.ilike('title', '%$query%');
      }

      final response = await request.order('created_at', ascending: false);
      final tasks = (response as List)
          .map((e) => TaskModel.fromMap(e as Map<String, dynamic>))
          .toList();

      // Merge with pending operations to ensure local-first consistency
      final pending = await localDatabase.getPendingOperations('task');
      for (final op in pending) {
        try {
          final payload = jsonDecode(op.payload) as Map<String, dynamic>;
          if (op.operation == 'add' || op.operation == 'update') {
            final taskModel = TaskModel.fromMap(payload);
            final index = tasks.indexWhere((t) => t.id == taskModel.id);
            if (index != -1) {
              tasks[index] = taskModel;
            } else if (op.operation == 'add') {
              tasks.insert(0, taskModel);
            }
          } else if (op.operation == 'delete') {
            final id = payload['id'] as String?;
            if (id != null) {
              tasks.removeWhere((t) => t.id == id);
            }
          }
        } catch (_) {}
      }

      if (boardId != null) {
        await localDatabase.replaceTasksForBoard(boardId, tasks);
      } else {
        for (final task in tasks) {
          await localDatabase.upsertTask(task);
        }
      }

      return tasks;
    } catch (_) {
      return localDatabase.getTasks(
        boardId: boardId,
        query: query,
        status: status,
      );
    }
  }

  @override
  Future<void> addTask(Task task) async {
    final taskModel = TaskModel(
      id: task.id,
      boardId: task.boardId,
      title: task.title,
      description: task.description,
      status: task.status,
      assigneeId: task.assigneeId,
      creatorId: task.creatorId,
      dueAt: task.dueAt,
      createdAt: task.createdAt,
      checklist: task.checklist,
      hasAttachments: task.hasAttachments,
      taskType: task.taskType,
    );

    await localDatabase.upsertTask(taskModel);
    try {
      await supabaseClient
          .from('tasks')
          .upsert(taskModel.toSupabaseMap(), onConflict: 'id');
    } catch (_) {
      await localDatabase.enqueueOperation(
        entity: 'task',
        operation: 'add',
        payload: jsonEncode(taskModel.toMap()),
      );
    }
  }

  @override
  Future<void> updateTask(Task task) async {
    final taskModel = TaskModel(
      id: task.id,
      boardId: task.boardId,
      title: task.title,
      description: task.description,
      status: task.status,
      assigneeId: task.assigneeId,
      creatorId: task.creatorId,
      dueAt: task.dueAt,
      createdAt: task.createdAt,
      checklist: task.checklist,
      hasAttachments: task.hasAttachments,
      taskType: task.taskType,
    );

    await localDatabase.upsertTask(taskModel);
    try {
      // Fetch old task to check for changes
      final oldTaskResponse = await supabaseClient
          .from('tasks')
          .select('assignee_id, title')
          .eq('id', task.id)
          .maybeSingle();

      await supabaseClient
          .from('tasks')
          .update(taskModel.toSupabaseMap())
          .eq('id', task.id);

      // Notification logic
      if (oldTaskResponse != null) {
        final oldAssigneeId = oldTaskResponse['assignee_id'] as String?;
        final newAssigneeId = task.assigneeId;

        if (newAssigneeId != null && newAssigneeId != oldAssigneeId) {
          final currentUserId = supabaseClient.auth.currentUser?.id;
          if (newAssigneeId != currentUserId) {
            await notificationRepository.createNotification(
              userId: newAssigneeId,
              taskId: task.id,
              title: 'Công việc mới được giao',
              message: 'Bạn đã được giao công việc: ${task.title}',
            );
          }
        }
      }
    } catch (_) {
      await localDatabase.enqueueOperation(
        entity: 'task',
        operation: 'update',
        payload: jsonEncode(taskModel.toMap()),
      );
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    await localDatabase.deleteTask(id);
    try {
      await supabaseClient.from('tasks').delete().eq('id', id);
    } catch (_) {
      await localDatabase.enqueueOperation(
        entity: 'task',
        operation: 'delete',
        payload: jsonEncode({'id': id}),
      );
    }
  }

  Future<void> _syncPendingTaskOperations() async {
    final pending = await localDatabase.getPendingOperations('task');
    for (final op in pending) {
      try {
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        if (op.operation == 'add') {
          final taskModel = TaskModel.fromMap(payload);
          await supabaseClient
              .from('tasks')
              .upsert(taskModel.toSupabaseMap(), onConflict: 'id');
        } else if (op.operation == 'update') {
          final taskModel = TaskModel.fromMap(payload);
          await supabaseClient
              .from('tasks')
              .update(taskModel.toSupabaseMap())
              .eq('id', payload['id']);
        } else if (op.operation == 'delete') {
          await supabaseClient.from('tasks').delete().eq('id', payload['id']);
        }
        await localDatabase.removePendingOperation(op.id);
      } catch (_) {
        break;
      }
    }
  }
}
