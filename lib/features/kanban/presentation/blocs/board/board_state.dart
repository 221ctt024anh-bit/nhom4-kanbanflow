import 'package:equatable/equatable.dart';
import '../../../domain/entities/board_entity.dart';

abstract class BoardState extends Equatable {
  const BoardState();
  @override
  List<Object> get props => [];
}

class BoardInitial extends BoardState {}

class BoardLoading extends BoardState {}

class BoardLoaded extends BoardState {
  final List<BoardEntity> boards;
  const BoardLoaded(this.boards);
  @override
  List<Object> get props => [boards];
}

class BoardError extends BoardState {
  final String message;
  const BoardError(this.message);
  @override
  List<Object> get props => [message];
}
