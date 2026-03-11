import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/board.dart';
import '../../domain/usecases/board_usecases.dart';
import 'board_event.dart';
import 'board_state.dart';

class BoardBloc extends Bloc<BoardEvent, BoardState> {
  final GetBoards getBoards;
  final AddBoard addBoard;
  final UpdateBoard updateBoard;
  final DeleteBoard deleteBoard;
  final WatchBoardsUseCase watchBoards;

  BoardBloc({
    required this.getBoards,
    required this.addBoard,
    required this.updateBoard,
    required this.deleteBoard,
    required this.watchBoards,
  }) : super(BoardInitial()) {
    on<LoadBoards>(_onLoadBoards);
    on<WatchBoards>(_onWatchBoards);
    on<AddBoardEvent>(_onAddBoard);
    on<UpdateBoardEvent>(_onUpdateBoard);
    on<DeleteBoardEvent>(_onDeleteBoard);
    on<ResetBoards>((event, emit) => emit(BoardInitial()));
  }

  Future<void> _onLoadBoards(LoadBoards event, Emitter<BoardState> emit) async {
    final currentState = state;
    if (currentState is! BoardLoaded) {
      emit(BoardLoading());
    }
    try {
      final boards = await getBoards.call();
      emit(BoardLoaded(boards, (id) => getBoards.repository.getRole(id)));
    } catch (e) {
      emit(BoardError(e.toString()));
    }
  }

  Future<void> _onWatchBoards(
    WatchBoards event,
    Emitter<BoardState> emit,
  ) async {
    emit(BoardLoading());
    await emit.forEach<List<Board>>(
      watchBoards.call(),
      onData: (boards) =>
          BoardLoaded(boards, (id) => watchBoards.repository.getRole(id)),
      onError: (e, stack) => BoardError(e.toString()),
    );
  }

  Future<void> _onAddBoard(
    AddBoardEvent event,
    Emitter<BoardState> emit,
  ) async {
    try {
      await addBoard.call(event.board);
      add(LoadBoards());
    } catch (e) {
      emit(BoardError(e.toString()));
    }
  }

  Future<void> _onUpdateBoard(
    UpdateBoardEvent event,
    Emitter<BoardState> emit,
  ) async {
    try {
      await updateBoard.call(event.board);
      add(LoadBoards());
    } catch (e) {
      emit(BoardError(e.toString()));
    }
  }

  Future<void> _onDeleteBoard(
    DeleteBoardEvent event,
    Emitter<BoardState> emit,
  ) async {
    try {
      await deleteBoard.call(event.id);
      add(LoadBoards());
    } catch (e) {
      emit(BoardError(e.toString()));
    }
  }
}
