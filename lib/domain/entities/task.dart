
import 'package:equatable/equatable.dart';

class Task extends Equatable {
  final int? id;
  final String title;
  final String description;
  final String status;

  const Task({
    this.id,
    required this.title,
    required this.description,
    required this.status,
  });

  @override
  List<Object?> get props => [id, title, description, status];
}