import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nhom4_kanbanflow/data/datasources/local_database.dart';
import 'package:nhom4_kanbanflow/data/repositories/task_repository_impl.dart';
import 'package:nhom4_kanbanflow/domain/entities/task.dart';
import 'package:nhom4_kanbanflow/data/models/board_model.dart';

void main() {
  late LocalDatabase localDatabase;
  late TaskRepositoryImpl repository;

  // Chạy 1 lần duy nhất trước khi bắt đầu test
  setUpAll(() {
    // Khởi tạo môi trường FFI để SQLite chạy được trên Windows khi test
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Chạy trước MỖI hàm test
  setUp(() async {
    localDatabase = LocalDatabase();
    await localDatabase.close(); // Reset the static connection

    // Xóa database cũ đi để mỗi bài test đều là một môi trường sạch sẽ
    final dbPath = await getDatabasesPath();
    await deleteDatabase('$dbPath/kanbanflow.db');

    repository = TaskRepositoryImpl(localDatabase: localDatabase);

    // Bảng task có foreign key boardId, cần tạo board trước
    await localDatabase.insertBoard(
      const BoardModel(
        id: 'board1',
        title: 'Bảng mẫu',
        createdAt: '2026-03-04',
      ),
    );
  });

  // Dữ liệu mẫu để test
  final tTask = Task(
    id: '1',
    boardId: 'board1',
    title: 'Học Flutter',
    description: 'Làm đồ án',
    status: 'todo',
    createdAt: '2026-03-04T12:00:00Z',
  );
  final tTaskUpdated = Task(
    id: '1',
    boardId: 'board1',
    title: 'Học Flutter',
    description: 'Hoàn thành UI',
    status: 'done',
    createdAt: '2026-03-04T12:00:00Z',
  );

  group('TaskRepository Tests', () {
    test('Nên thêm công việc và lấy danh sách thành công', () async {
      // Act: Thêm task
      await repository.addTask(tTask);
      // Act: Lấy danh sách
      final tasks = await repository.getTasks();

      // Assert: Kiểm tra kết quả
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Học Flutter');
      expect(tasks.first.status, 'todo');
    });

    test('Nên cập nhật công việc thành công', () async {
      // Arrange: Thêm task ban đầu
      await repository.addTask(tTask);

      // Act: Cập nhật task
      await repository.updateTask(tTaskUpdated);
      final tasks = await repository.getTasks();

      // Assert: Trạng thái phải đổi thành 'done'
      expect(tasks.first.status, 'done');
      expect(tasks.first.description, 'Hoàn thành UI');
    });

    test('Nên xóa công việc thành công', () async {
      // Arrange
      await repository.addTask(tTask);

      // Act
      await repository.deleteTask('1');
      final tasks = await repository.getTasks();

      // Assert: Danh sách phải rỗng
      expect(tasks.isEmpty, true);
    });
  });
}
