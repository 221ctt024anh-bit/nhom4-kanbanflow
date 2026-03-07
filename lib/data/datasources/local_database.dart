import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/board_model.dart';
import '../models/task_model.dart';

class PendingOperation {
  final int id;
  final String entity;
  final String operation;
  final String payload;

  const PendingOperation({
    required this.id,
    required this.entity,
    required this.operation,
    required this.payload,
  });
}

class LocalDatabase {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('taskmate.db');
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
      databaseFactory = databaseFactoryFfiWeb;
      return databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: _createDB,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS pending_ops');
      await db.execute('DROP TABLE IF EXISTS tasks');
      await db.execute('DROP TABLE IF EXISTS boards');
      await _createDB(db, 2);
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN due_at TEXT');
      } catch (_) {
        // Column may already exist.
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS boards (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        board_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL,
        assignee_id TEXT,
        creator_id TEXT,
        due_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (board_id) REFERENCES boards (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_ops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<List<BoardModel>> getBoards() async {
    final db = await database;
    final result = await db.query('boards', orderBy: 'created_at DESC');
    return result
        .map((row) => BoardModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> replaceBoards(List<BoardModel> boards) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('boards');
      for (final board in boards) {
        await txn.insert(
          'boards',
          board.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<int> upsertBoard(BoardModel board) async {
    final db = await database;
    return db.insert(
      'boards',
      board.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteBoard(String id) async {
    final db = await database;
    return db.delete('boards', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TaskModel>> getTasks({
    String? boardId,
    String? query,
    String? status,
  }) async {
    final db = await database;

    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (boardId != null) {
      whereClauses.add('board_id = ?');
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

    final result = await db.query(
      'tasks',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );
    return result
        .map((row) => TaskModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> replaceTasksForBoard(
    String boardId,
    List<TaskModel> tasks,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tasks', where: 'board_id = ?', whereArgs: [boardId]);
      for (final task in tasks) {
        await txn.insert(
          'tasks',
          task.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<int> upsertTask(TaskModel task) async {
    final db = await database;
    return db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteTask(String id) async {
    final db = await database;
    return db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> enqueueOperation({
    required String entity,
    required String operation,
    required String payload,
  }) async {
    final db = await database;
    return db.insert('pending_ops', {
      'entity': entity,
      'operation': operation,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<PendingOperation>> getPendingOperations(String entity) async {
    final db = await database;
    final rows = await db.query(
      'pending_ops',
      where: 'entity = ?',
      whereArgs: [entity],
      orderBy: 'id ASC',
    );
    return rows
        .map(
          (row) => PendingOperation(
            id: row['id'] as int,
            entity: row['entity'] as String,
            operation: row['operation'] as String,
            payload: row['payload'] as String,
          ),
        )
        .toList();
  }

  Future<int> removePendingOperation(int id) async {
    final db = await database;
    return db.delete('pending_ops', where: 'id = ?', whereArgs: [id]);
  }
}
