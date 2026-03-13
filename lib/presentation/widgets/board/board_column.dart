import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/task.dart';
import '../../blocs/task_bloc.dart';
import '../../blocs/task_event.dart';
import '../task_card.dart';
import 'board_utils.dart';

class BoardColumn extends StatelessWidget {
  final String title;
  final String status;
  final List<Task> allTasks;
  final Color accentColor;
  final String? role;

  const BoardColumn({
    super.key,
    required this.title,
    required this.status,
    required this.allTasks,
    required this.accentColor,
    this.role,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = BoardUtils.getTasksByStatus(allTasks, status);

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) =>
          status != 'overdue' && details.data.status != status,
      onAcceptWithDetails: (details) {
        if (status == 'overdue') return;
        final droppedTask = details.data;
        final updatedTask = Task(
          id: droppedTask.id,
          boardId: droppedTask.boardId,
          title: droppedTask.title,
          description: droppedTask.description,
          status: status == 'overdue' ? droppedTask.status : status,
          assigneeIds: droppedTask.assigneeIds,
          creatorId: droppedTask.creatorId,
          dueAt: droppedTask.dueAt,
          createdAt: droppedTask.createdAt,
          checklist: droppedTask.checklist,
          hasAttachments: droppedTask.hasAttachments,
          taskType: droppedTask.taskType,
        );
        context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering
                  ? accentColor.withOpacity(0.8)
                  : Colors.grey.withOpacity(0.2),
              width: isHovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovering
                    ? accentColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              colorScheme: ColorScheme.light(primary: accentColor),
            ),
            child: ExpansionTile(
              key: PageStorageKey('$status-${tasks.isNotEmpty}'),
              initiallyExpanded: tasks.isNotEmpty,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: tasks.map((task) {
                if (role == 'viewer') {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TaskCard(task: task, accentColor: accentColor),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Draggable<Task>(
                    data: task,
                    feedback: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 64,
                        child: Opacity(
                          opacity: 0.9,
                          child: TaskCard(task: task, accentColor: accentColor),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.4,
                      child: TaskCard(task: task, accentColor: accentColor),
                    ),
                    child: TaskCard(task: task, accentColor: accentColor),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
