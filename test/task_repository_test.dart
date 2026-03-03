// File: test/task_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

// Dùng đường dẫn tương đối (../lib) để bách phát bách trúng, không lo sai tên app
import 'package:nhom4_kanbanflow/data/datasources/local_database.dart';
import 'package:nhom4_kanbanflow/data/models/task_model.dart';
import 'package:nhom4_kanbanflow/data/repositories/task_repository_impl.dart';
import 'package:nhom4_kanbanflow/domain/entities/task.dart';

class MockLocalDatabase implements LocalDatabase {
  @override
  Future<List<TaskModel>> getAllTasks() async {
    return [
      TaskModel(
        id: 1,
        title: 'Test Task',
        description: 'Mô tả test',
        status: 'todo',
      ),
    ];
  }

  @override
  Future<TaskModel> insertTask(TaskModel task) async => task;
  @override
  Future<int> updateTask(TaskModel task) async => 1;
  @override
  Future<int> deleteTask(int id) async => 1;
  @override
  Future<List<TaskModel>> searchTasks(String keyword) async => [];
  @override
  Future<Database> get database => throw UnimplementedError();
}

void main() {
  late TaskRepositoryImpl repository;
  late MockLocalDatabase mockDatabase;

  setUp(() {
    mockDatabase = MockLocalDatabase();
    repository = TaskRepositoryImpl(localDatabase: mockDatabase);
  });

  test(
    'getAllTasks phải trả về danh sách Task Entity hợp lệ từ Database',
    () async {
      final result = await repository.getAllTasks();

      expect(result, isA<List<Task>>());
      expect(result.length, 1);
      expect(result[0].id, 1);
      expect(result[0].title, 'Test Task');
      expect(result[0].status, 'todo');
    },
  );
}
