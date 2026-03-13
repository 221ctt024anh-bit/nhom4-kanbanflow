import '../entities/board.dart';
import '../repositories/board_repository.dart';

class GetBoards {
  final BoardRepository repository;
  GetBoards(this.repository);

  Future<List<Board>> call() async {
    return await repository.getBoards();
  }
}

class AddBoard {
  final BoardRepository repository;
  AddBoard(this.repository);

  Future<void> call(Board board) async {
    return await repository.addBoard(board);
  }
}

class UpdateBoard {
  final BoardRepository repository;
  UpdateBoard(this.repository);

  Future<void> call(Board board) async {
    return await repository.updateBoard(board);
  }
}

class DeleteBoard {
  final BoardRepository repository;
  DeleteBoard(this.repository);

  Future<void> call(String id) async {
    return await repository.deleteBoard(id);
  }
}

class WatchBoardsUseCase {
  final BoardRepository repository;
  WatchBoardsUseCase(this.repository);

  Stream<List<Board>> call() {
    return repository.watchBoards();
  }
}
