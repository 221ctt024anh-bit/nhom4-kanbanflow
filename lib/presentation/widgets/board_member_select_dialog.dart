import 'package:flutter/material.dart';
import '../../app_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/board_repository.dart';
import '../../injection_container.dart' as di;
import 'user_avatar.dart';

class BoardMemberSelectDialog extends StatefulWidget {
  final String boardId;
  final String? currentAssigneeId;

  const BoardMemberSelectDialog({
    super.key,
    required this.boardId,
    this.currentAssigneeId,
  });

  @override
  State<BoardMemberSelectDialog> createState() =>
      _BoardMemberSelectDialogState();
}

class _BoardMemberSelectDialogState extends State<BoardMemberSelectDialog> {
  List<UserModel> _members = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        AppPreferences.tr('Giao việc cho thành viên', 'Assign to Member'),
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 300,
        height: 350,
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
                itemCount: _members.length + 1, // +1 for "Bỏ giao việc"
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: const Icon(
                          Icons.person_off,
                          color: Colors.black54,
                        ),
                      ),
                      title: Text(
                        AppPreferences.tr('Bỏ giao việc', 'Unassign'),
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      onTap: () {
                        Navigator.pop(
                          context,
                          "",
                        ); // Trả về chuỗi rỗng để hiểu là huỷ
                      },
                    );
                  }

                  final member = _members[index - 1];
                  final isSelected = member.id == widget.currentAssigneeId;

                  return ListTile(
                    leading: UserAvatar(userId: member.id, radius: 18),
                    title: Text(member.displayName ?? member.email),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.blueAccent,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context, member.id);
                    },
                  );
                },
              ),
      ),
    );
  }
}
