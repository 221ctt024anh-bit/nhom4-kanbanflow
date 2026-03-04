import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:kanban_flow/features/kanban/data/datasources/kanban_local_datasource.dart';
import 'package:kanban_flow/features/kanban/data/models/board_model.dart';
import 'package:kanban_flow/features/kanban/data/repositories/kanban_repository_impl.dart';
import 'package:kanban_flow/core/error/failures.dart';

@GenerateMocks([KanbanLocalDataSource])
import 'kanban_repository_impl_test.mocks.dart';

void main() {
  late KanbanRepositoryImpl repository;
  late MockKanbanLocalDataSource mockLocalDataSource;

  setUp(() {
    mockLocalDataSource = MockKanbanLocalDataSource();
    repository = KanbanRepositoryImpl(localDataSource: mockLocalDataSource);
  });

  final tBoardModel = BoardModel(
    id: '1',
    title: 'Test Board',
    createdAt: DateTime.now(),
  );

  final tBoardList = [tBoardModel];

  group('getBoards', () {
    test(
      'should return list of boards when call to local datasource is successful',
      () async {
        // Arrange
        when(
          mockLocalDataSource.getBoards(),
        ).thenAnswer((_) async => tBoardList);

        // Act
        final result = await repository.getBoards();

        // Assert
        verify(mockLocalDataSource.getBoards());
        expect(result, equals(Right(tBoardList)));
      },
    );

    test(
      'should return DatabaseFailure when call to local datasource is unsuccessful',
      () async {
        // Arrange
        when(mockLocalDataSource.getBoards()).thenThrow(Exception('DB Error'));

        // Act
        final result = await repository.getBoards();

        // Assert
        verify(mockLocalDataSource.getBoards());
        expect(
          result,
          equals(const Left(DatabaseFailure('Exception: DB Error'))),
        );
      },
    );
  });

  group('createBoard', () {
    test('should call local datasource to create board', () async {
      // Arrange
      when(mockLocalDataSource.createBoard(any)).thenAnswer((_) async => {});

      // Act
      final result = await repository.createBoard(tBoardModel);

      // Assert
      verify(mockLocalDataSource.createBoard(any));
      expect(result, equals(const Right(null)));
    });
  });
}
