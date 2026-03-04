import 'package:hive_flutter/hive_flutter.dart';
import '../models/board_model.dart';
import '../models/column_model.dart';
import '../models/task_model.dart';

abstract class KanbanLocalDataSource {
  Future<List<BoardModel>> getBoards();
  Future<void> createBoard(BoardModel board);
  Future<void> deleteBoard(String boardId);

  Future<List<ColumnModel>> getColumns(String boardId);
  Future<void> createColumn(ColumnModel column);
  Future<void> deleteColumn(String columnId);

  Future<List<TaskModel>> getTasks(String columnId);
  Future<void> createTask(TaskModel task);
  Future<void> updateTask(TaskModel task);
  Future<void> deleteTask(String taskId);
  Future<List<TaskModel>> searchTasks(String query);
}

class KanbanLocalDataSourceImpl implements KanbanLocalDataSource {
  final Box boardsBox = Hive.box('boards');
  final Box columnsBox = Hive.box('columns');
  final Box tasksBox = Hive.box('tasks');

  @override
  Future<List<BoardModel>> getBoards() async {
    final values = boardsBox.values.toList();
    final boards = values
        .map((e) => BoardModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    boards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return boards;
  }

  @override
  Future<void> createBoard(BoardModel board) async {
    await boardsBox.put(board.id, board.toJson());
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    await boardsBox.delete(boardId);

    // Cascading delete manually for Hive
    final allColumns = await getColumns(boardId);
    for (var col in allColumns) {
      await deleteColumn(col.id);
    }
  }

  @override
  Future<List<ColumnModel>> getColumns(String boardId) async {
    final values = columnsBox.values.toList();
    final columns = values
        .map((e) => ColumnModel.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.boardId == boardId)
        .toList();
    columns.sort((a, b) => a.order.compareTo(b.order));
    return columns;
  }

  @override
  Future<void> createColumn(ColumnModel column) async {
    await columnsBox.put(column.id, column.toJson());
  }

  @override
  Future<void> deleteColumn(String columnId) async {
    await columnsBox.delete(columnId);

    // Delete tasks in this column
    final allTasks = tasksBox.values.toList();
    final tasksToDelete = allTasks
        .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.columnId == columnId);

    for (var t in tasksToDelete) {
      await tasksBox.delete(t.id);
    }
  }

  @override
  Future<List<TaskModel>> getTasks(String columnId) async {
    final values = tasksBox.values.toList();
    final tasks = values
        .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.columnId == columnId)
        .toList();
    tasks.sort((a, b) => a.order.compareTo(b.order));
    return tasks;
  }

  @override
  Future<void> createTask(TaskModel task) async {
    await tasksBox.put(task.id, task.toJson());
  }

  @override
  Future<void> updateTask(TaskModel task) async {
    await tasksBox.put(task.id, task.toJson());
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await tasksBox.delete(taskId);
  }

  @override
  Future<List<TaskModel>> searchTasks(String query) async {
    final values = tasksBox.values.toList();
    final lowercaseQuery = query.toLowerCase();

    final results = values
        .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
        .where(
          (t) =>
              t.title.toLowerCase().contains(lowercaseQuery) ||
              t.description.toLowerCase().contains(lowercaseQuery),
        )
        .toList();

    return results;
  }
}
