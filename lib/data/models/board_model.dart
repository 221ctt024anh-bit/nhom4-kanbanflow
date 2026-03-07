import '../../domain/entities/board.dart';

class BoardModel extends Board {
  const BoardModel({
    required super.id,
    required super.title,
    required super.ownerId,
    required super.createdAt,
  });

  factory BoardModel.fromMap(Map<String, dynamic> map) {
    return BoardModel(
      id: map['id'] as String,
      title: map['title'] as String,
      ownerId: map['owner_id'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'owner_id': ownerId,
      'created_at': createdAt,
    };
  }
}
