import '../entities/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getTasks({String? boardId, String? query, String? status});
  Future<void> addTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String id);
  Future<Task?> getTaskById(String id);
}
