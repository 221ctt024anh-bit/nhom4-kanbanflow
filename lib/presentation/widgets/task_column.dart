// File: lib/presentation/widgets/task_column.dart
import 'package:flutter/material.dart';
import '../../domain/entities/task.dart';

class TaskColumn extends StatelessWidget {
  final String title;
  final List<Task> tasks;
  final String status;

  const TaskColumn({
    super.key,
    required this.title,
    required this.tasks,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300, // Độ rộng cố định của mỗi cột
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        children: [
          // Tiêu đề cột
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              '$title (${tasks.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // Danh sách các Task
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                      task.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
