import 'package:flutter/material.dart';
import '../../app_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/board_repository.dart';
import '../../injection_container.dart' as di;
import 'user_avatar.dart';

class BoardMemberSelectDialog extends StatefulWidget {
  final String boardId;
  final List<String> currentAssigneeIds;

  const BoardMemberSelectDialog({
    super.key,
    required this.boardId,
    this.currentAssigneeIds = const [],
  });

  @override
  State<BoardMemberSelectDialog> createState() =>
      _BoardMemberSelectDialogState();
}

class _BoardMemberSelectDialogState extends State<BoardMemberSelectDialog> {
  List<UserModel> _members = [];
  late List<String> _selectedIds;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.currentAssigneeIds);
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final repository = di.sl<BoardRepository>();
      final members = await repository.getBoardMembers(widget.boardId);
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        AppPreferences.tr('Giao việc cho thành viên', 'Assign members'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 300,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(
                  '${AppPreferences.tr('Lỗi', 'Error')}: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : _members.isEmpty
            ? Center(
                child: Text(
                  AppPreferences.tr(
                    'Bảng này chưa có thành viên nào.',
                    'No members in this board yet.',
                  ),
                ),
              )
            : ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  final isSelected = _selectedIds.contains(member.id);

                  return CheckboxListTile(
                    secondary: UserAvatar(userId: member.id, radius: 18),
                    value: isSelected,
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.displayName ?? member.email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildRoleChip(member.role),
                      ],
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(member.id);
                        } else {
                          _selectedIds.remove(member.id);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppPreferences.tr('Hủy', 'Cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedIds),
          child: Text(AppPreferences.tr('Xác nhận', 'Confirm')),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String? role) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isAdmin
            ? Colors.orange.withOpacity(0.1)
            : Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAdmin
              ? Colors.orange.withOpacity(0.5)
              : Colors.blueAccent.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        isAdmin ? AppPreferences.tr('AD', 'AD') : AppPreferences.tr('MB', 'MB'),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: isAdmin ? Colors.orange[800] : Colors.blueAccent,
        ),
      ),
    );
  }
}
