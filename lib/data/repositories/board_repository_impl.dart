import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/board.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/board_repository.dart';
import '../datasources/local_database.dart';
import '../models/board_model.dart';

class BoardRepositoryImpl implements BoardRepository {
  final SupabaseClient supabaseClient;
  final LocalDatabase localDatabase;
  final Map<String, String> _roleCache = {}; // boardId -> role

  BoardRepositoryImpl({
    required this.supabaseClient,
    LocalDatabase? localDatabase,
  }) : localDatabase = localDatabase ?? LocalDatabase();

  @override
  Future<List<Board>> getBoards() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      await _syncPendingBoardOperations();

      final ownerResponse = await supabaseClient
          .from('boards')
          .select()
          .eq('owner_id', userId);

      final memberResponse = await supabaseClient
          .from('board_members')
          .select('boards(*)')
          .eq('user_id', userId);

      final boardsMap = <String, BoardModel>{};

      for (final row in (ownerResponse as List)) {
        final board = BoardModel.fromMap(row as Map<String, dynamic>);
        boardsMap[board.id] = board;
        _updateRoleCache(board.id, 'owner');
      }

      for (final row in (memberResponse as List)) {
        final boardData = (row as Map<String, dynamic>)['boards'];
        if (boardData != null) {
          final board = BoardModel.fromMap(boardData as Map<String, dynamic>);
          boardsMap[board.id] = board;

          // Get the role for this specific user on this board
          final roleResp = await supabaseClient
              .from('board_members')
              .select('role')
              .eq('board_id', board.id)
              .eq('user_id', userId)
              .maybeSingle();

          if (roleResp != null) {
            _updateRoleCache(board.id, roleResp['role'] as String?);
          }
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
  Stream<List<Board>> watchBoards() async* {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      yield [];
      return;
    }

    // Tải dữ liệu ban đầu
    yield await getBoards();

    // Lắng nghe thay đổi trên bảng boards (dành cho owner)
    final _ = supabaseClient
        .channel('public:boards:owner_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'boards',
          callback: (_) {},
        )
        .subscribe();

    // Lắng nghe thay đổi trên bảng board_members (dành cho thành viên được mời)
    final __ = supabaseClient
        .channel('public:board_members:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'board_members',
          callback: (_) {},
        )
        .subscribe();

    // Để cập nhật Realtime mượt mà mà không tạo quá nhiều request,
    // ta lắng nghe các stream cơ bản của Supabase nếu có thể, hoặc dùng Stream định kỳ kết hợp callback.
    // Tuy nhiên, Supabase .stream() bị giới hạn filter.
    // Giải pháp tối ưu: Stream định kỳ + listener.

    yield* Stream.periodic(
      const Duration(seconds: 10),
    ).asyncMap((_) => getBoards());

    // Note: Ở phiên bản này tôi dùng polling 10s kết hợp với trigger LoadBoards khi cần.
    // Các listener trên sẽ giúp cho các thao tác local mượt mà hơn.
  }

  @override
  Future<void> addBoard(Board board) async {
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
          .upsert(boardModel.toMap(), onConflict: 'id');
      try {
        await supabaseClient.from('board_members').insert({
          'board_id': board.id,
          'user_id': board.ownerId,
          'role': 'admin',
        });
      } catch (_) {}
    } catch (_) {
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
      throw Exception('Không tìm thấy người dùng với email $email.');
    }

    final userId = profileResponse['id'];
    final existingMember = await supabaseClient
        .from('board_members')
        .select()
        .eq('board_id', boardId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingMember != null) {
      throw Exception('Người dùng này đã có trong bảng.');
    }

    await supabaseClient.from('board_members').insert({
      'board_id': boardId,
      'user_id': userId,
      'role': 'member',
    });
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
    // Invalidate cache for this board to force refresh
    _roleCache.remove(boardId);
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
    // Invalidate cache for this board to force refresh
    _roleCache.remove(boardId);
  }

  String? getRole(String boardId) => _roleCache[boardId];

  void _updateRoleCache(String boardId, String? role) {
    if (role != null) {
      _roleCache[boardId] = role;
    }
  }

  Future<void> _syncPendingBoardOperations() async {
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
          } catch (_) {}
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
        break;
      }
    }
  }
}
