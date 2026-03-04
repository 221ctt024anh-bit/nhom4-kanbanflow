import 'package:equatable/equatable.dart';

class TaskEntity extends Equatable {
  final String id;
  final String title;
  final String description;
  final String columnId;
  final int order;
  final DateTime createdAt;

  const TaskEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.columnId,
    required this.order,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    columnId,
    order,
    createdAt,
  ];
}
