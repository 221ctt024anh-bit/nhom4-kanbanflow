import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';
import '../models/board_model.dart';

class LocalDatabase {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kanbanflow.db');
    return _database!;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      // Khởi tạo FFI Web
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: _createDB,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    // Kích hoạt FFI nếu đang chạy trên Windows/Linux/Mac (cực kỳ quan trọng để chạy Test)
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE boards (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        boardId TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (boardId) REFERENCES boards (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Thêm cột createdAt vào bảng tasks cho các database cũ
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN createdAt TEXT NOT NULL DEFAULT ""',
      );
    }
  }

  Future<List<TaskModel>> getTasks({
    String? boardId,
    String? query,
    String? status,
  }) async {
    final db = await database;

    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (boardId != null) {
      whereClauses.add('boardId = ?');
      whereArgs.add(boardId);
    }

    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }

    if (query != null && query.isNotEmpty) {
      whereClauses.add('title LIKE ?');
      whereArgs.add('%$query%');
    }

    String? whereString = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;

    final result = await db.query(
      'tasks',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );
    return result.map((map) => TaskModel.fromMap(map)).toList();
  }

  Future<int> insertTask(TaskModel task) async {
    final db = await database;
    return await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTask(TaskModel task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(String id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // BOARDS CRUD
  Future<List<BoardModel>> getBoards() async {
    final db = await database;
    final result = await db.query('boards', orderBy: 'createdAt ASC');
    return result.map((map) => BoardModel.fromMap(map)).toList();
  }

  Future<int> insertBoard(BoardModel board) async {
    final db = await database;
    return await db.insert(
      'boards',
      board.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateBoard(BoardModel board) async {
    final db = await database;
    return await db.update(
      'boards',
      board.toMap(),
      where: 'id = ?',
      whereArgs: [board.id],
    );
  }

  Future<int> deleteBoard(String id) async {
    final db = await database;
    return await db.delete('boards', where: 'id = ?', whereArgs: [id]);
  }
}
