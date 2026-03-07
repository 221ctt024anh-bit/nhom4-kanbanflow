import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/board_repository.dart';
import '../../injection_container.dart' as di;
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';

class BoardMemberDialog extends StatefulWidget {
  final String boardId;
  final String ownerId;

  const BoardMemberDialog({
    super.key,
    required this.boardId,
    required this.ownerId,
  });

  @override
  State<BoardMemberDialog> createState() => _BoardMemberDialogState();
}

class _BoardMemberDialogState extends State<BoardMemberDialog> {
  final TextEditingController _emailController = TextEditingController();
  List<UserModel> _members = [];
  bool _isLoading = true;
  bool _isInviting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
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

  Future<void> _inviteMember() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isInviting = true;
      _error = null;
    });

    try {
      final repository = di.sl<BoardRepository>();
      await repository.addMember(widget.boardId, email);
      _emailController.clear();
      await _loadMembers(); // Reload list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppPreferences.tr(
                'Đã mời thành viên thành công!',
                'Member invited successfully!',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInviting = false;
        });
      }
    }
  }

  Future<void> _removeMember(String userId) async {
    try {
      final repository = di.sl<BoardRepository>();
      await repository.removeMember(widget.boardId, userId);
      await _loadMembers();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        (context.read<AuthBloc>().state as Authenticated).user.id;
    final isOwner = currentUserId == widget.ownerId;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        AppPreferences.tr('Thành viên & Phân quyền', 'Board Members'),
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            if (isOwner) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: AppPreferences.tr(
                          'Nhập email người dùng...',
                          'Enter user email...',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isInviting ? null : _inviteMember,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isInviting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            AppPreferences.tr('Mời', 'Invite'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${AppPreferences.tr('Lỗi', 'Error')}: $_error',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _members.isEmpty
                  ? Center(
                      child: Text(
                        AppPreferences.tr(
                          'Chưa có thành viên nào.',
                          'No members yet.',
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            child: Text(
                              member.displayName
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  member.email.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(member.displayName ?? member.email),
                          subtitle: Text(
                            member.email,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: (isOwner && member.id != widget.ownerId)
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _removeMember(member.id),
                                )
                              : (member.id == widget.ownerId
                                    ? Chip(
                                        label: Text(
                                          AppPreferences.tr(
                                            'Chủ sở hữu',
                                            'Owner',
                                          ),
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        padding: EdgeInsets.zero,
                                      )
                                    : null),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppPreferences.tr('Đóng', 'Close')),
        ),
      ],
    );
  }
}
