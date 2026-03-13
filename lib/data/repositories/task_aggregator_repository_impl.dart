import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/assigned_task_view.dart';
import '../../domain/repositories/task_aggregator_repository.dart';
import '../models/task_model.dart';

class TaskAggregatorRepositoryImpl implements TaskAggregatorRepository {
  final SupabaseClient supabaseClient;
  
  // Lưu trữ các subscription chuyển động
  RealtimeChannel? _assigneesChannel;
  RealtimeChannel? _tasksChannel;
  
  // Stream controller để đẩy dữ liệu ra UI
  final _controller = StreamController<List<AssignedTaskView>>.broadcast();
  
  // Cache danh sách task IDs đang được giao để subscribe
  List<String> _currentTaskIds = [];

  TaskAggregatorRepositoryImpl({required this.supabaseClient});

  @override
  Stream<List<AssignedTaskView>> getAssignedTasksStream(String userId) {
    _initStream(userId);
    return _controller.stream;
  }

  Future<void> _initStream(String userId) async {
    // 1. Tải dữ liệu ban đầu
    await _refreshAndEmit(userId);
    
    // 2. Subscribe vào task_assignees để biết khi nào có task mới được giao
    _assigneesChannel?.unsubscribe();
    _assigneesChannel = supabaseClient
        .channel('public:task_assignees:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_assignees',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            await _refreshAndEmit(userId);
          },
        )
        .subscribe();
  }

  Future<void> _refreshAndEmit(String userId) async {
    final tasks = await fetchAssignedTasks(userId);
    _controller.add(tasks);
    
    // Cập nhật subscription cho từng task cụ thể
    _updateTasksSubscription(userId, tasks.map((e) => e.task.id).toList());
  }

  void _updateTasksSubscription(String userId, List<String> newTaskIds) {
    // Nếu danh sách IDs không đổi thì không cần làm gì
    if (_currentTaskIds.length == newTaskIds.length && 
        _currentTaskIds.every((id) => newTaskIds.contains(id))) {
      return;
    }

    _currentTaskIds = List.from(newTaskIds);
    _tasksChannel?.unsubscribe();
    
    if (_currentTaskIds.isEmpty) return;

    // Subscribe vào bảng tasks cho những IDs này
    _tasksChannel = supabaseClient.channel('public:tasks:assigned_to_me');
    
    // Note: Supabase Realtime filter 'in' is restricted sometimes, 
    // but we can listen to the table and filter manually or use multiple filters if needed.
    // For simplicity and correctness with many tasks, we listen to all task changes 
    // and filter in the callback if they match our IDs.
    _tasksChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tasks',
      callback: (payload) {
        final taskId = payload.newRecord['id'] as String?;
        if (taskId != null && _currentTaskIds.contains(taskId)) {
          _refreshAndEmit(userId);
        }
      },
    ).subscribe();
  }

  @override
  Future<List<AssignedTaskView>> fetchAssignedTasks(String userId) async {
    try {
      // 1. Lấy tất cả task_id mà user được giao
      final assigneesResponse = await supabaseClient
          .from('task_assignees')
          .select('task_id')
          .eq('user_id', userId);
      
      final taskIds = (assigneesResponse as List)
          .map((e) => e['task_id'] as String)
          .toList();
      
      if (taskIds.isEmpty) return [];

      // 2. Lấy thông tin Task cùng với Board Title
      // Query qua RPC hoặc join query (nếu RLS cho phép)
      final tasksResponse = await supabaseClient
          .from('tasks')
          .select('*, boards(title), task_assignees(user_id)')
          .filter('id', 'in', taskIds);

      final List<AssignedTaskView> result = [];
      for (final item in (tasksResponse as List)) {
        final task = TaskModel.fromMap(item as Map<String, dynamic>);
        final boardTitle = (item['boards'] as Map<String, dynamic>?)?['title'] ?? 'Unknown Board';
        
        result.add(AssignedTaskView(
          task: task,
          boardTitle: boardTitle,
        ));
      }
      
      return result;
    } catch (e) {
      print('DEBUG: Error fetching assigned tasks: $e');
      return [];
    }
  }

  void dispose() {
    _assigneesChannel?.unsubscribe();
    _tasksChannel?.unsubscribe();
    _controller.close();
  }
}
