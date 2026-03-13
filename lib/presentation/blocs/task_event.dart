import '../../domain/entities/task.dart';

abstract class TaskEvent {}

// Sự kiện: Yêu cầu tải danh sách công việc
class LoadTasks extends TaskEvent {
  final String? boardId;
  final String? query;
  final String? status;

  LoadTasks({this.boardId, this.query, this.status});
}

// Sự kiện: Yêu cầu thêm công việc
class AddTaskEvent extends TaskEvent {
  final Task task;
  AddTaskEvent(this.task);
}

// Sự kiện: Yêu cầu cập nhật công việc
class UpdateTaskEvent extends TaskEvent {
  final Task task;
  UpdateTaskEvent(this.task);
}

// Sự kiện: Yêu cầu xóa công việc
class DeleteTaskEvent extends TaskEvent {
  final String id;
  DeleteTaskEvent(this.id);
}

class ResetTasks extends TaskEvent {}
