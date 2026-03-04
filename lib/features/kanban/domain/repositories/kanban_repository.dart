import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/board_entity.dart';
import '../entities/column_entity.dart';
import '../entities/task_entity.dart';

abstract class KanbanRepository {
  // Board operations
  Future<Either<Failure, List<BoardEntity>>> getBoards();
  Future<Either<Failure, void>> createBoard(BoardEntity board);
  Future<Either<Failure, void>> deleteBoard(String boardId);

  // Column operations
  Future<Either<Failure, List<ColumnEntity>>> getColumns(String boardId);
  Future<Either<Failure, void>> createColumn(ColumnEntity column);
  Future<Either<Failure, void>> deleteColumn(String columnId);

  // Task operations
  Future<Either<Failure, List<TaskEntity>>> getTasks(String columnId);
  Future<Either<Failure, void>> createTask(TaskEntity task);
  Future<Either<Failure, void>> updateTask(TaskEntity task);
  Future<Either<Failure, void>> deleteTask(String taskId);
  Future<Either<Failure, void>> moveTask(
    String taskId,
    String newColumnId,
    int newOrder,
  );
  Future<Either<Failure, List<TaskEntity>>> searchTasks(String query);
}
