import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/column_entity.dart';
import '../entities/task_entity.dart';
import '../repositories/kanban_repository.dart';

class GetColumns implements UseCase<List<ColumnEntity>, String> {
  final KanbanRepository repository;
  GetColumns(this.repository);

  @override
  Future<Either<Failure, List<ColumnEntity>>> call(String params) async {
    return await repository.getColumns(params);
  }
}

class GetTasks implements UseCase<List<TaskEntity>, String> {
  final KanbanRepository repository;
  GetTasks(this.repository);

  @override
  Future<Either<Failure, List<TaskEntity>>> call(String params) async {
    return await repository.getTasks(params);
  }
}

class CreateTask implements UseCase<void, TaskEntity> {
  final KanbanRepository repository;
  CreateTask(this.repository);

  @override
  Future<Either<Failure, void>> call(TaskEntity params) async {
    return await repository.createTask(params);
  }
}

class UpdateTask implements UseCase<void, TaskEntity> {
  final KanbanRepository repository;
  UpdateTask(this.repository);

  @override
  Future<Either<Failure, void>> call(TaskEntity params) async {
    return await repository.updateTask(params);
  }
}

class DeleteTask implements UseCase<void, String> {
  final KanbanRepository repository;
  DeleteTask(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) async {
    return await repository.deleteTask(params);
  }
}

class SearchTasks implements UseCase<List<TaskEntity>, String> {
  final KanbanRepository repository;
  SearchTasks(this.repository);

  @override
  Future<Either<Failure, List<TaskEntity>>> call(String params) async {
    return await repository.searchTasks(params);
  }
}

class CreateColumn implements UseCase<void, ColumnEntity> {
  final KanbanRepository repository;
  CreateColumn(this.repository);

  @override
  Future<Either<Failure, void>> call(ColumnEntity params) async {
    return await repository.createColumn(params);
  }
}

class DeleteColumn implements UseCase<void, String> {
  final KanbanRepository repository;
  DeleteColumn(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) async {
    return await repository.deleteColumn(params);
  }
}
