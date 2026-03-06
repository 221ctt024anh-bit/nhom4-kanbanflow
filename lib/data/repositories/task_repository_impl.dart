import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/local_database.dart';
import '../models/task_model.dart';

// Class này implements (thực thi) cái bản thiết kế TaskRepository bên tầng Domain
class TaskRepositoryImpl implements TaskRepository {
  final LocalDatabase localDatabase;

  // Tiêm dependency (LocalDatabase) vào thông qua constructor
  TaskRepositoryImpl({required this.localDatabase});

  @override
  Future<List<Task>> getTasks({
    String? boardId,
    String? query,
    String? status,
  }) async {
    return await localDatabase.getTasks(
      boardId: boardId,
      query: query,
      status: status,
    );
  }

  @override
  Future<void> addTask(Task task) async {
    // Chuyển đổi từ Entity (Task - của tầng Domain) sang Model (TaskModel - của tầng Data) để lưu
    final taskModel = TaskModel(
      id: task.id,
      boardId: task.boardId,
      title: task.title,
      description: task.description,
      status: task.status,
      createdAt: task.createdAt,
    );
    await localDatabase.insertTask(taskModel);
  }

  @override
  Future<void> updateTask(Task task) async {
    final taskModel = TaskModel(
      id: task.id,
      boardId: task.boardId,
      title: task.title,
      description: task.description,
      status: task.status,
      createdAt: task.createdAt,
    );
    await localDatabase.updateTask(taskModel);
  }

  @override
  Future<void> deleteTask(String id) async {
    await localDatabase.deleteTask(id);
  }
}
