import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nhom4_kanbanflow/presentation/blocs/task_bloc.dart';
import 'package:nhom4_kanbanflow/presentation/widgets/task_column.dart';

class BoardScreen extends StatelessWidget {
  const BoardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KanbanFlow - Nhóm 4')),
      body: BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          if (state is TaskLoaded) {
            final tasks = state.tasks;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaskColumn(
                    title: 'CẦN LÀM',
                    tasks: tasks.where((t) => t.status == 'todo').toList(),
                  ),
                  TaskColumn(
                    title: 'ĐANG LÀM',
                    tasks: tasks.where((t) => t.status == 'doing').toList(),
                  ),
                  TaskColumn(
                    title: 'HOÀN THÀNH',
                    tasks: tasks.where((t) => t.status == 'done').toList(),
                  ),
                ],
              ),
            );
          }
          if (state is TaskError) {
            return Center(child: Text('Lỗi: ${state.message}'));
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
