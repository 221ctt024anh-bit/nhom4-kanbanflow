import '../../domain/entities/board.dart';

abstract class BoardState {}

class BoardInitial extends BoardState {}

class BoardLoading extends BoardState {}

class BoardLoaded extends BoardState {
  final List<Board> boards;
  final String? Function(String boardId) getRole;
  BoardLoaded(this.boards, this.getRole);
}

class BoardError extends BoardState {
  final String message;
  BoardError(this.message);
}
