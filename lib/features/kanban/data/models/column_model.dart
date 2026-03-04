import '../../domain/entities/column_entity.dart';

class ColumnModel extends ColumnEntity {
  const ColumnModel({
    required super.id,
    required super.title,
    required super.boardId,
    required super.order,
  });

  factory ColumnModel.fromJson(Map<String, dynamic> json) {
    return ColumnModel(
      id: json['id'],
      title: json['title'],
      boardId: json['board_id'],
      order: json['column_order'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'board_id': boardId,
      'column_order': order,
    };
  }

  factory ColumnModel.fromEntity(ColumnEntity entity) {
    return ColumnModel(
      id: entity.id,
      title: entity.title,
      boardId: entity.boardId,
      order: entity.order,
    );
  }
}
