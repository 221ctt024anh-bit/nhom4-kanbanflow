import '../entities/board.dart';
import '../entities/user.dart';

abstract class BoardRepository {
  Future<List<Board>> getBoards();
  Future<void> addBoard(Board board);
  Future<void> updateBoard(Board board);
  Future<void> deleteBoard(String id);
  Future<void> addMember(String boardId, String email);
  Future<List<UserModel>> getBoardMembers(String boardId);
  Future<void> removeMember(String boardId, String userId);
}
