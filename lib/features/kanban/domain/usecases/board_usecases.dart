import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/board_entity.dart';
import '../repositories/kanban_repository.dart';

class GetBoards implements UseCase<List<BoardEntity>, NoParams> {
  final KanbanRepository repository;
  GetBoards(this.repository);

  @override
  Future<Either<Failure, List<BoardEntity>>> call(NoParams params) async {
    return await repository.getBoards();
  }
}

class CreateBoard implements UseCase<void, BoardEntity> {
  final KanbanRepository repository;
  CreateBoard(this.repository);

  @override
  Future<Either<Failure, void>> call(BoardEntity params) async {
    return await repository.createBoard(params);
  }
}

class DeleteBoard implements UseCase<void, String> {
  final KanbanRepository repository;
  DeleteBoard(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) async {
    return await repository.deleteBoard(params);
  }
}
