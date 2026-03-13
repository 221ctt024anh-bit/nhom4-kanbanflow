import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/board.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/board_repository.dart';
import '../datasources/local_database.dart';
import '../models/board_model.dart';

class BoardRepositoryImpl implements BoardRepository {
  final SupabaseClient supabaseClient;
  final LocalDatabase localDatabase;
  final Map<String, String> _roleCache = {};
  StreamController<List<Board>>? _boardsController;
  RealtimeChannel? _ownerBoardsChannel;
  RealtimeChannel? _memberBoardsChannel;
  Timer? _refreshDebounce;

  BoardRepositoryImpl({
    required this.supabaseClient,
    LocalDatabase? localDatabase,
  }) : localDatabase = localDatabase ?? LocalDatabase();

  @override
  Future<List<Board>> getBoards() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      await syncPendingBoards();

      final ownerResponse = await supabaseClient
          .from('boards')
          .select()
          .eq('owner_id', userId);

      final memberResponse = await supabaseClient
          .from('board_members')
          .select('role, boards(*)')
          .eq('user_id', userId);

      final boardsMap = <String, BoardModel>{};

      for (final row in (ownerResponse as List)) {
        final board = BoardModel.fromMap(row as Map<String, dynamic>);
        boardsMap[board.id] = board;
        _updateRoleCache(board.id, 'owner');
      }

      for (final row in (memberResponse as List)) {
        final rowMap = row as Map<String, dynamic>;
        final boardData = rowMap['boards'];
        if (boardData != null) {
          final board = BoardModel.fromMap(boardData as Map<String, dynamic>);
          boardsMap[board.id] = board;
          _updateRoleCache(board.id, rowMap['role'] as String?);
        }
      }

      final boards = List<BoardModel>.from(boardsMap.values)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      await localDatabase.replaceBoards(boards);
      return boards;
    } catch (_) {
      final localBoards = await localDatabase.getBoards();
      localBoards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return localBoards;
    }
  }

  @override
  Stream<List<Board>> watchBoards() {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    _boardsController ??= StreamController<List<Board>>.broadcast();

    _ownerBoardsChannel ??= supabaseClient
        .channel('public:boards:owner_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'boards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'owner_id',
            value: userId,
          ),
          callback: (_) => _scheduleBoardsRefresh(),
        )
        .subscribe();

    _memberBoardsChannel ??= supabaseClient
        .channel('public:board_members:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'board_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _scheduleBoardsRefresh(),
        )
        .subscribe();

    _scheduleBoardsRefresh(immediate: true);
    return _boardsController!.stream;
  }

  @override
  Future<void> addBoard(Board board) async {
    debugPrint(
      'DEBUG: BoardRepositoryImpl.addBoard - Starting for board: ${board.id}',
    );
    final boardModel = BoardModel(
      id: board.id,
      title: board.title,
      ownerId: board.ownerId,
      createdAt: board.createdAt,
    );

    await localDatabase.upsertBoard(boardModel);
    try {
      debugPrint('DEBUG: BoardRepositoryImpl.addBoard - Upserting board');
      await supabaseClient
          .from('boards')
          .upsert(boardModel.toMap(), onConflict: 'id');
      try {
        await supabaseClient.from('board_members').insert({
          'board_id': board.id,
          'user_id': board.ownerId,
          'role': 'admin',
        });
      } catch (e) {
        debugPrint('DEBUG: BoardRepositoryImpl.addBoard - Member insert: $e');
      }
      _scheduleBoardsRefresh();
    } catch (e) {
      debugPrint('DEBUG: BoardRepositoryImpl.addBoard - Queueing sync: $e');
      await localDatabase.enqueueOperation(
        entity: 'board',
        operation: 'add',
        payload: jsonEncode(boardModel.toMap()),
      );
    }
  }

  @override
  Future<void> updateBoard(Board board) async {
    final boardModel = BoardModel(
      id: board.id,
      title: board.title,
      ownerId: board.ownerId,
      createdAt: board.createdAt,
    );

    await localDatabase.upsertBoard(boardModel);
    try {
      await supabaseClient
          .from('boards')
          .update(boardModel.toMap())
          .eq('id', board.id);
      _scheduleBoardsRefresh();
    } catch (_) {
      await localDatabase.enqueueOperation(
        entity: 'board',
        operation: 'update',
        payload: jsonEncode(boardModel.toMap()),
      );
    }
  }

  @override
  Future<void> deleteBoard(String id) async {
    await localDatabase.deleteBoard(id);
    try {
      await supabaseClient.from('boards').delete().eq('id', id);
      _roleCache.remove(id);
      _scheduleBoardsRefresh();
    } catch (_) {
      await localDatabase.enqueueOperation(
        entity: 'board',
        operation: 'delete',
        payload: jsonEncode({'id': id}),
      );
    }
  }

  @override
  Future<void> addMember(String boardId, String email) async {
    final profileResponse = await supabaseClient
        .from('profiles')
        .select()
        .eq('email', email)
        .maybeSingle();

    if (profileResponse == null) {
      throw Exception('Khong tim thay nguoi dung voi email $email.');
    }

    final userId = profileResponse['id'];
    final existingMember = await supabaseClient
        .from('board_members')
        .select()
        .eq('board_id', boardId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingMember != null) {
      throw Exception('Nguoi dung nay da co trong bang.');
    }

    await supabaseClient.from('board_members').insert({
      'board_id': boardId,
      'user_id': userId,
      'role': 'member',
    });
    _scheduleBoardsRefresh();
  }

  @override
  Future<List<UserModel>> getBoardMembers(String boardId) async {
    final memberResponse = await supabaseClient
        .from('board_members')
        .select('user_id, role')
        .eq('board_id', boardId);

    final memberRows = memberResponse as List;
    if (memberRows.isEmpty) return [];

    final userIds = memberRows
        .map((e) => (e as Map<String, dynamic>)['user_id'] as String)
        .toList();

    final profileResponse = await supabaseClient
        .from('profiles')
        .select()
        .filter('id', 'in', userIds);

    final profiles = profileResponse as List;
    final roleMap = {
      for (var row in memberRows)
        (row as Map<String, dynamic>)['user_id'] as String:
            row['role'] as String?,
    };

    return profiles.map((profile) {
      final map = profile as Map<String, dynamic>;
      final id = map['id'] as String;
      return UserModel(
        id: id,
        email: (map['email'] as String?) ?? '',
        displayName: map['display_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        role: roleMap[id],
      );
    }).toList();
  }

  @override
  Future<void> removeMember(String boardId, String userId) async {
    await supabaseClient
        .from('board_members')
        .delete()
        .eq('board_id', boardId)
        .eq('user_id', userId);
    _roleCache.remove(boardId);
    _scheduleBoardsRefresh();
  }

  @override
  Future<void> updateMemberRole(
    String boardId,
    String userId,
    String role,
  ) async {
    await supabaseClient.from('board_members').update({'role': role}).match({
      'board_id': boardId,
      'user_id': userId,
    });
    _roleCache.remove(boardId);
    _scheduleBoardsRefresh();
  }

  @override
  String? getRole(String boardId) => _roleCache[boardId];

  void _updateRoleCache(String boardId, String? role) {
    if (role != null) {
      _roleCache[boardId] = role;
    }
  }

  void _scheduleBoardsRefresh({bool immediate = false}) {
    if (_boardsController == null || _boardsController!.isClosed) {
      return;
    }

    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 250),
      () async {
        try {
          final boards = await getBoards();
          if (!(_boardsController?.isClosed ?? true)) {
            _boardsController!.add(boards);
          }
        } catch (error, stackTrace) {
          if (!(_boardsController?.isClosed ?? true)) {
            _boardsController!.addError(error, stackTrace);
          }
        }
      },
    );
  }

  @override
  Future<void> syncPendingBoards() async {
    final pending = await localDatabase.getPendingOperations('board');
    for (final op in pending) {
      try {
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        if (op.operation == 'add') {
          await supabaseClient.from('boards').upsert(payload, onConflict: 'id');
          try {
            await supabaseClient.from('board_members').insert({
              'board_id': payload['id'],
              'user_id': payload['owner_id'],
              'role': 'admin',
            });
          } catch (e) {
            debugPrint('DEBUG: BoardRepositoryImpl._sync member insert: $e');
          }
        } else if (op.operation == 'update') {
          await supabaseClient
              .from('boards')
              .update(payload)
              .eq('id', payload['id']);
        } else if (op.operation == 'delete') {
          await supabaseClient.from('boards').delete().eq('id', payload['id']);
        }
        await localDatabase.removePendingOperation(op.id);
      } catch (_) {
        continue;
      }
    }
  }
}
