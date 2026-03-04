import '../../domain/entities/board_entity.dart';

class BoardModel extends BoardEntity {
  const BoardModel({
    required super.id,
    required super.title,
    required super.createdAt,
  });

  factory BoardModel.fromJson(Map<String, dynamic> json) {
    return BoardModel(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BoardModel.fromEntity(BoardEntity entity) {
    return BoardModel(
      id: entity.id,
      title: entity.title,
      createdAt: entity.createdAt,
    );
  }
}
