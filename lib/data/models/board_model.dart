import '../../domain/entities/board.dart';

class BoardModel extends Board {
  const BoardModel({
    required super.id,
    required super.title,
    required super.createdAt,
  });

  factory BoardModel.fromMap(Map<String, dynamic> map) {
    return BoardModel(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: map['createdAt'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'createdAt': createdAt};
  }
}
