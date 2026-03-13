import 'dart:convert';

import 'package:flutter/foundation.dart';
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
      await syncPendingTasks();

      var request = supabaseClient
          .from('tasks')
          .select('id, board_id, title, description, status, creator_id, due_at, created_at, updated_at, checklist, has_attachments, task_type, task_assignees(user_id)');

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
            // Skip if not belonging to current board
            if (boardId != null && taskModel.boardId != boardId) continue;

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
      assigneeIds: task.assigneeIds,
      creatorId: task.creatorId,
      dueAt: task.dueAt,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      checklist: task.checklist,
      hasAttachments: task.hasAttachments,
      taskType: task.taskType,
    );

    await localDatabase.upsertTask(taskModel);
    try {
      await supabaseClient
          .from('tasks')
          .upsert(taskModel.toSupabaseMap(), onConflict: 'id');

      // Sync assignees
      if (taskModel.assigneeIds.isNotEmpty) {
        await supabaseClient
            .from('task_assignees')
            .insert(
              taskModel.assigneeIds
                  .map((uid) => {'task_id': task.id, 'user_id': uid})
                  .toList(),
            );
      }
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
      assigneeIds: task.assigneeIds,
      creatorId: task.creatorId,
      dueAt: task.dueAt,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      checklist: task.checklist,
      hasAttachments: task.hasAttachments,
      taskType: task.taskType,
    );

    await localDatabase.upsertTask(taskModel);
    try {
      // 1. Fetch old assignees
      final oldAssigneesResponse = await supabaseClient
          .from('task_assignees')
          .select('user_id')
          .eq('task_id', task.id);
      final oldAssigneeIds = (oldAssigneesResponse as List)
          .map((e) => e['user_id'] as String)
          .toList();

      // 2. Update task basic info
      await supabaseClient
          .from('tasks')
          .update(taskModel.toSupabaseMap())
          .eq('id', task.id);

      // 3. Sync assignees join table
      final newAssigneeIds = task.assigneeIds;

      // Unassign those no longer in the list
      final toRemove = oldAssigneeIds
          .where((id) => !newAssigneeIds.contains(id))
          .toList();
      if (toRemove.isNotEmpty) {
        await supabaseClient
            .from('task_assignees')
            .delete()
            .eq('task_id', task.id)
            .filter('user_id', 'in', toRemove);
      }

      // Assign those newly added
      final toAdd = newAssigneeIds
          .where((id) => !oldAssigneeIds.contains(id))
          .toList();
      if (toAdd.isNotEmpty) {
        await supabaseClient
            .from('task_assignees')
            .insert(
              toAdd.map((uid) => {'task_id': task.id, 'user_id': uid}).toList(),
            );

        // Notifications are handled by DB trigger on task_assignees insert
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
    debugPrint('DEBUG: TaskRepositoryImpl.deleteTask - ID: $id');
    
    // 1. Kiểm tra xem thẻ có tồn tại trên Supabase không
    bool existsOnServer = false;
    try {
      final check = await supabaseClient
          .from('tasks')
          .select('id')
          .eq('id', id)
          .maybeSingle();
      existsOnServer = check != null;
    } catch (e) {
      debugPrint('DEBUG: TaskRepositoryImpl.deleteTask - Lỗi khi kiểm tra thẻ: $e');
      // Nếu lỗi mạng, chúng ta cứ giả định là nó có thể tồn tại để tiếp tục quy trình offline
      existsOnServer = true; 
    }

    // 2. Xóa khỏi database local
    await localDatabase.deleteTask(id);
    
    // 3. QUAN TRỌNG: Dọn dẹp hàng đợi đồng bộ (nếu thẻ này mới tạo/sửa chưa kịp lên server)
    await localDatabase.clearPendingOperationsByEntityId('task', id);

    if (!existsOnServer) {
      debugPrint('DEBUG: TaskRepositoryImpl.deleteTask - Thẻ không có trên server (local-only), đã dọn dẹp xong.');
      return; // Thành công vì đã dọn dẹp sạch ở local
    }

    // 4. Thực hiện xóa trên Supabase
    try {
      debugPrint('DEBUG: TaskRepositoryImpl.deleteTask - Đang xóa trên Supabase...');
      final response = await supabaseClient
          .from('tasks')
          .delete()
          .eq('id', id)
          .select();
      
      if (response.isEmpty) {
        // Nếu server từ chối (RLS), chúng ta mới cần enqueue để thử lại sau hoặc báo lỗi
        debugPrint('DEBUG: TaskRepositoryImpl.deleteTask - Server từ chối xóa (RLS), đang đưa vào hàng đợi...');
        await localDatabase.enqueueOperation(
          entity: 'task',
          operation: 'delete',
          payload: jsonEncode({'id': id}),
        );
        throw Exception('Không thể xóa thẻ: Bạn không có quyền xóa trên server.');
      }
      debugPrint('DEBUG: TaskRepositoryImpl.deleteTask - Xóa thành công!');
    } catch (e) {
      debugPrint('DEBUG: TaskRepositoryImpl.deleteTask - Lỗi khi xóa (mạng hoặc khác): $e');
      if (e is! Exception) { // Nếu không phải lỗi logic RLS mình vừa throw
        await localDatabase.enqueueOperation(
          entity: 'task',
          operation: 'delete',
          payload: jsonEncode({'id': id}),
        );
      }
      rethrow;
    }
  }

  @override
  Future<Task?> getTaskById(String id) async {
    try {
      final response = await supabaseClient
          .from('tasks')
          .select('id, board_id, title, description, status, creator_id, due_at, created_at, updated_at, checklist, has_attachments, task_type, task_assignees(user_id)')
          .eq('id', id)
          .maybeSingle();
      
      if (response == null) return null;
      return TaskModel.fromMap(response);
    } catch (_) {
      // Fallback to local if offline
      return localDatabase.getTaskById(id);
    }
  }

  @override
  Future<void> syncPendingTasks() async {
    final pending = await localDatabase.getPendingOperations('task');
    if (pending.isEmpty) {
      return;
    }
    
    debugPrint('DEBUG: syncPendingTasks - Starting sync for ${pending.length} operations');
    for (final op in pending) {
      try {
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        debugPrint('DEBUG: syncPendingTasks - Syncing ${op.operation} for ID: ${payload['id']}');
        
        if (op.operation == 'add' || op.operation == 'update') {
          final taskModel = TaskModel.fromMap(payload);
          await supabaseClient
              .from('tasks')
              .upsert(taskModel.toSupabaseMap(), onConflict: 'id');
          
          if (taskModel.assigneeIds.isNotEmpty) {
            await supabaseClient.from('task_assignees').delete().eq('task_id', taskModel.id);
            await supabaseClient.from('task_assignees').insert(
              taskModel.assigneeIds.map((uid) => {'task_id': taskModel.id, 'user_id': uid}).toList(),
            );
          }
        } else if (op.operation == 'delete') {
          await supabaseClient.from('tasks').delete().eq('id', payload['id']);
        }
        
        await localDatabase.removePendingOperation(op.id);
        debugPrint('DEBUG: syncPendingTasks - SUCCESS for ID: ${payload['id']}');
      } catch (e) {
        debugPrint('DEBUG: syncPendingTasks - ERROR for ID: ${op.id}: $e');
        
        // Nếu lỗi do bảng không tồn tại trên server (Foreign Key Violation)
        // thì ta xóa operation này đi để tránh bị kẹt hàng chờ vô hạn.
        if (e is PostgrestException && e.code == '23503') {
          debugPrint('DEBUG: syncPendingTasks - Orphaned data detected (code 23503), removing from queue.');
          await localDatabase.removePendingOperation(op.id);
        }
        
        continue; 
      }
    }
    debugPrint('DEBUG: syncPendingTasks - Finished sync attempt.');
  }
}
