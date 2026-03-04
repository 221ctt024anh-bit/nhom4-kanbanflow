import 'package:equatable/equatable.dart';

abstract class BoardEvent extends Equatable {
  const BoardEvent();
  @override
  List<Object> get props => [];
}

class LoadBoardsEvent extends BoardEvent {}

class AddBoardEvent extends BoardEvent {
  final String title;
  const AddBoardEvent(this.title);
  @override
  List<Object> get props => [title];
}

class DeleteBoardEvent extends BoardEvent {
  final String boardId;
  const DeleteBoardEvent(this.boardId);
  @override
  List<Object> get props => [boardId];
}
