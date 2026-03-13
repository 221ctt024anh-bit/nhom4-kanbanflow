import '../entities/assigned_task_view.dart';

abstract class TaskAggregatorRepository {
  /// Trả về stream danh sách các task được giao cho người dùng hiện tại
  /// từ tất cả các board mà họ tham gia.
  Stream<List<AssignedTaskView>> getAssignedTasksStream(String userId);

  /// Tải lại danh sách task thủ công (ví dụ cho pull-to-refresh)
  Future<List<AssignedTaskView>> fetchAssignedTasks(String userId);
}
