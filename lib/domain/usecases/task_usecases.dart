
import '../entities/task.dart';
import '../repositories/task_repository.dart';

class GetTasksUseCase {
  final TaskRepository repository;
  GetTasksUseCase(this.repository);
  
  Future<List<Task>> call() async => await repository.getAllTasks();
}

class AddTaskUseCase {
  final TaskRepository repository;
  AddTaskUseCase(this.repository);
  
  Future<Task> call(Task task) async => await repository.insertTask(task);
}

class UpdateTaskUseCase {
  final TaskRepository repository;
  UpdateTaskUseCase(this.repository);
  
  Future<int> call(Task task) async => await repository.updateTask(task);
}

class DeleteTaskUseCase {
  final TaskRepository repository;
  DeleteTaskUseCase(this.repository);
  
  Future<int> call(int id) async => await repository.deleteTask(id);
}

class SearchTasksUseCase {
  final TaskRepository repository;
  SearchTasksUseCase(this.repository);
  
  Future<List<Task>> call(String keyword) async => await repository.searchTasks(keyword);
}