import 'package:flutter/material.dart';
import 'package:nhom4_kanbanflow/domain/entities/task.dart';

class TaskColumn extends StatelessWidget {
  final String title;
  final List<Task> tasks;

  const TaskColumn({Key? key, required this.title, required this.tasks})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '$title (${tasks.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(tasks[index].title),
                    subtitle: Text(tasks[index].description),
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
