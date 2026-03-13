import '../../domain/entities/board.dart';

abstract class BoardEvent {}

class LoadBoards extends BoardEvent {}

class WatchBoards extends BoardEvent {}

class AddBoardEvent extends BoardEvent {
  final Board board;
  AddBoardEvent(this.board);
}

class UpdateBoardEvent extends BoardEvent {
  final Board board;
  UpdateBoardEvent(this.board);
}

class DeleteBoardEvent extends BoardEvent {
  final String id;
  DeleteBoardEvent(this.id);
}

class ResetBoards extends BoardEvent {}
