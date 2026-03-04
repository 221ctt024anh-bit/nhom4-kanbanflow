import 'package:equatable/equatable.dart';

class ColumnEntity extends Equatable {
  final String id;
  final String title;
  final String boardId;
  final int order;

  const ColumnEntity({
    required this.id,
    required this.title,
    required this.boardId,
    required this.order,
  });

  @override
  List<Object?> get props => [id, title, boardId, order];
}
