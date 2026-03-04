import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:kanban_flow/features/kanban/domain/entities/board_entity.dart';
import 'package:kanban_flow/features/kanban/domain/usecases/board_usecases.dart';
import 'package:kanban_flow/core/usecases/usecase.dart';
import 'board_event.dart';
import 'board_state.dart';

class BoardBloc extends Bloc<BoardEvent, BoardState> {
  final GetBoards getBoards;
  final CreateBoard createBoard;
  final DeleteBoard deleteBoard;

  BoardBloc({
    required this.getBoards,
    required this.createBoard,
    required this.deleteBoard,
  }) : super(BoardInitial()) {
    on<LoadBoardsEvent>(_onLoadBoards);
    on<AddBoardEvent>(_onAddBoard);
    on<DeleteBoardEvent>(_onDeleteBoard);
  }

  Future<void> _onLoadBoards(
    LoadBoardsEvent event,
    Emitter<BoardState> emit,
  ) async {
    emit(BoardLoading());
    final result = await getBoards(NoParams());
    result.fold(
      (failure) => emit(BoardError(failure.message)),
      (boards) => emit(BoardLoaded(boards)),
    );
  }

  Future<void> _onAddBoard(
    AddBoardEvent event,
    Emitter<BoardState> emit,
  ) async {
    final board = BoardEntity(
      id: const Uuid().v4(),
      title: event.title,
      createdAt: DateTime.now(),
    );
    final result = await createBoard(board);
    result.fold(
      (failure) => emit(BoardError(failure.message)),
      (_) => add(LoadBoardsEvent()),
    );
  }

  Future<void> _onDeleteBoard(
    DeleteBoardEvent event,
    Emitter<BoardState> emit,
  ) async {
    final result = await deleteBoard(event.boardId);
    result.fold(
      (failure) => emit(BoardError(failure.message)),
      (_) => add(LoadBoardsEvent()),
    );
  }
}
