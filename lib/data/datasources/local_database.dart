// File: lib/data/datasources/local_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';

class LocalDatabase {
  // Áp dụng Singleton pattern để chỉ có 1 instance database duy nhất
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  // Gọi hàm này để lấy đối tượng database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kanbanflow.db');
    return _database!;
  }

  // Khởi tạo Database và định nghĩa đường dẫn lưu file
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Mở DB, nếu chưa có sẽ gọi hàm _createDB
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Hàm tạo các bảng dữ liệu
  Future _createDB(Database db, int version) async {
    // Tạo bảng Tasks
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');
    
    
  }

  // 1. Thêm một Task mới vào Database
  Future<TaskModel> insertTask(TaskModel task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    
    // Trả về TaskModel mới có kèm theo ID vừa được SQLite cấp tự động
    return TaskModel(
      id: id,
      title: task.title,
      description: task.description,
      status: task.status,
    );
  }

  // 2. Lấy toàn bộ danh sách Task (để hiển thị lên Board)
  Future<List<TaskModel>> getAllTasks() async {
    final db = await instance.database;
    final maps = await db.query('tasks'); // Truy vấn toàn bộ bảng 'tasks'

    // Chuyển đổi List<Map> thành List<TaskModel>
    return maps.map((map) => TaskModel.fromMap(map)).toList();
  }

  // 3. Cập nhật Task (Rất quan trọng cho bạn B khi làm Drag & Drop đổi Cột)
  Future<int> updateTask(TaskModel task) async {
    final db = await instance.database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  // 4. Xóa một Task
  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 5. Tìm kiếm Task theo tiêu đề hoặc mô tả (Search / Filter)
  Future<List<TaskModel>> searchTasks(String keyword) async {
    final db = await instance.database;
    final maps = await db.query(
      'tasks',
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
    );
    
    return maps.map((map) => TaskModel.fromMap(map)).toList();
  }
}