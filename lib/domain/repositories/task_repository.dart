
import '../entities/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getAllTasks();
  Future<Task> insertTask(Task task);
  Future<int> updateTask(Task task);
  Future<int> deleteTask(int id);
  Future<List<Task>> searchTasks(String keyword);
}