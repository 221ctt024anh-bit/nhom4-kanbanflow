import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/task.dart';
import '../../blocs/task_bloc.dart';
import '../../blocs/task_event.dart';
import '../task_card.dart';
import 'board_utils.dart';

class BoardMenuItem extends StatelessWidget {
  final String title;
  final String status;
  final Color accentColor;
  final List<Task> allTasks;
  final bool isSelected;
  final Function(String) onTap;

  const BoardMenuItem({
    super.key,
    required this.title,
    required this.status,
    required this.accentColor,
    required this.allTasks,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tasksCount = BoardUtils.getTasksByStatus(allTasks, status).length;

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

        return InkWell(
          onTap: () => onTap(status),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: isHovering
                  ? accentColor.withOpacity(0.2)
                  : (isSelected
                        ? accentColor.withOpacity(0.1)
                        : Colors.transparent),
              border: Border(
                left: BorderSide(
                  color: isHovering || isSelected
                      ? accentColor
                      : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isHovering || isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 16,
                      color: isHovering || isSelected
                          ? accentColor
                          : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$tasksCount',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LandscapeTaskContent extends StatelessWidget {
  final List<Task> allTasks;
  final String status;
  final String? role;

  const LandscapeTaskContent({
    super.key,
    required this.allTasks,
    required this.status,
    this.role,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = BoardUtils.getTasksByStatus(allTasks, status);
    final accentColor = BoardUtils.getStatusColor(status);

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

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: isHovering
              ? accentColor.withOpacity(0.05)
              : Colors.transparent,
          child: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có công việc nào',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 140, // Fixed height for task cards
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    if (role == 'viewer') {
                      return TaskCard(task: task, accentColor: accentColor);
                    }
                    return Draggable<Task>(
                      data: task,
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 380,
                          child: Opacity(
                            opacity: 0.9,
                            child: TaskCard(
                              task: task,
                              accentColor: accentColor,
                            ),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: TaskCard(task: task, accentColor: accentColor),
                      ),
                      child: TaskCard(task: task, accentColor: accentColor),
                    );
                  },
                ),
        );
      },
    );
  }
}
