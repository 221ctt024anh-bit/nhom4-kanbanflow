
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/local_database.dart';
import '../models/task_model.dart';

class TaskRepositoryImpl implements TaskRepository {
  final LocalDatabase localDatabase;

  // Bắt buộc phải truyền LocalDatabase vào khi khởi tạo (Dependency Injection)
  TaskRepositoryImpl({required this.localDatabase});

  @override
  Future<List<Task>> getAllTasks() async {
    final taskModels = await localDatabase.getAllTasks();
    // Biến đổi List<TaskModel> thành List<Task>
    return taskModels.map((model) => Task(
      id: model.id,
      title: model.title,
      description: model.description,
      status: model.status,
    )).toList();
  }

  @override
  Future<Task> insertTask(Task task) async {
    // Biến đổi Task thành TaskModel để lưu vào DB
    final taskModel = TaskModel(
      title: task.title,
      description: task.description,
      status: task.status,
    );
    final insertedModel = await localDatabase.insertTask(taskModel);
    
    return Task(
      id: insertedModel.id,
      title: insertedModel.title,
      description: insertedModel.description,
      status: insertedModel.status,
    );
  }

  @override
  Future<int> updateTask(Task task) async {
    final taskModel = TaskModel(
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
    );
    return await localDatabase.updateTask(taskModel);
  }

  @override
  Future<int> deleteTask(int id) async {
    return await localDatabase.deleteTask(id);
  }

  @override
  Future<List<Task>> searchTasks(String keyword) async {
    final taskModels = await localDatabase.searchTasks(keyword);
    return taskModels.map((model) => Task(
      id: model.id,
      title: model.title,
      description: model.description,
      status: model.status,
    )).toList();
  }
}