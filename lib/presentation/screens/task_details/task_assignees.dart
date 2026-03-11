import 'package:flutter/material.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/user.dart';
import '../../../app_preferences.dart';
import '../../widgets/user_avatar.dart';
import 'task_details_utils.dart';

class TaskAssignees extends StatelessWidget {
  final Task task;
  final String? role;
  final bool loadingMembers;
  final List<UserModel> members;
  final VoidCallback onEditAssignees;

  const TaskAssignees({
    super.key,
    required this.task,
    required this.role,
    required this.loadingMembers,
    required this.members,
    required this.onEditAssignees,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskDetailsUtils.buildSectionTitle(
          AppPreferences.tr('NGƯỜI THỰC HIỆN', 'ASSIGNEES'),
          trailing: role == 'viewer'
              ? const SizedBox.shrink()
              : TextButton.icon(
                  onPressed: onEditAssignees,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(AppPreferences.tr('Thay đổi', 'Change')),
                ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: task.assigneeIds.isNotEmpty
              ? Column(
                  children: task.assigneeIds.map((uid) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          UserAvatar(userId: uid, radius: 20, showName: true),
                          const SizedBox(width: 12),
                          const Spacer(),
                          if (!loadingMembers) _buildAssigneeRoleChip(uid),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : Text(
                  AppPreferences.tr('Chưa giao cho ai', 'Unassigned'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAssigneeRoleChip(String userId) {
    if (members.isEmpty) return const SizedBox.shrink();
    final member = members.cast<UserModel?>().firstWhere(
      (m) => m?.id == userId,
      orElse: () => null,
    );
    if (member == null || member.role == null) return const SizedBox.shrink();

    final isAdmin = member.role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? Colors.orange.withOpacity(0.1)
            : Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdmin
              ? Colors.orange.withOpacity(0.5)
              : Colors.blueAccent.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        isAdmin
            ? AppPreferences.tr('Quản trị viên', 'Admin')
            : AppPreferences.tr('Thành viên', 'Member'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isAdmin ? Colors.orange[800] : Colors.blueAccent,
        ),
      ),
    );
  }
}
