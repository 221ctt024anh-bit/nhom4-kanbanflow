import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/local_database.dart';
import '../models/task_model.dart';

class TaskRepositoryImpl implements TaskRepository {
  final SupabaseClient supabaseClient;
  final LocalDatabase localDatabase;

  TaskRepositoryImpl({
    required this.supabaseClient,
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

      if (boardId != null) {
        await localDatabase.replaceTasksForBoard(boardId, tasks);
      } else {
        for (final task in tasks) {
          await localDatabase.upsertTask(task);
        }
      }

      return tasks;
    } catch (_) {
      return localDatabase.getTasks(boardId: boardId, query: query, status: status);
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
    );

    await localDatabase.upsertTask(taskModel);
    try {
      await supabaseClient.from('tasks').upsert(taskModel.toMap(), onConflict: 'id');
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
    );

    await localDatabase.upsertTask(taskModel);
    try {
      await supabaseClient.from('tasks').update(taskModel.toMap()).eq('id', task.id);
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
          await supabaseClient.from('tasks').upsert(payload, onConflict: 'id');
        } else if (op.operation == 'update') {
          await supabaseClient.from('tasks').update(payload).eq('id', payload['id']);
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
