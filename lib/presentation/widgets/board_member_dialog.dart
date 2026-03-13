import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/friend_user.dart';
import '../../domain/repositories/board_repository.dart';
import '../../data/repositories/friend_repository.dart';
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
  List<FriendUser> _friends = [];
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
      final friendRepo = di.sl<FriendRepository>();

      final results = await Future.wait([
        repository.getBoardMembers(widget.boardId),
        friendRepo.getFriends(),
      ]);

      setState(() {
        _members = results[0] as List<UserModel>;
        _friends = results[1] as List<FriendUser>;
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

  Future<void> _inviteFriend(FriendUser friend) async {
    setState(() {
      _isInviting = true;
      _error = null;
    });

    try {
      final repository = di.sl<BoardRepository>();
      await repository.addMember(widget.boardId, friend.email);
      await _loadMembers(); // Reload list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppPreferences.tr(
                'Đã mời ${friend.displayName ?? friend.email} thành công!',
                'Invited ${friend.displayName ?? friend.email} successfully!',
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

  Future<void> _updateRole(String userId, String currentRole) async {
    final String? newRole = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppPreferences.tr('Chọn vai trò', 'Select Role')),
        children: ['admin', 'member', 'viewer'].map((r) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, r),
            child: Text(
              r == 'admin'
                  ? AppPreferences.tr('Quản trị viên', 'Admin')
                  : r == 'member'
                  ? AppPreferences.tr('Thành viên', 'Member')
                  : AppPreferences.tr('Chỉ xem', 'Viewer'),
            ),
          );
        }).toList(),
      ),
    );

    if (newRole != null && newRole != currentRole) {
      try {
        final repository = di.sl<BoardRepository>();
        await repository.updateMemberRole(widget.boardId, userId, newRole);
        _loadMembers();
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
      }
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
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        height: 450,
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
              // Filter friends who are NOT already members
              _buildSuggestions(),
              const SizedBox(height: 12),
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
                        final isMemberOwner = member.id == widget.ownerId;
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: (isOwner && !isMemberOwner)
                                    ? () => _updateRole(
                                        member.id,
                                        member.role ?? 'member',
                                      )
                                    : null,
                                child: _buildRoleChip(
                                  isMemberOwner ? 'owner' : member.role,
                                ),
                              ),
                              if (isOwner && !isMemberOwner) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () => _removeMember(member.id),
                                ),
                              ],
                            ],
                          ),
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

  Widget _buildSuggestions() {
    final suggestions = _friends
        .where((f) => !_members.any((m) => m.id == f.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppPreferences.tr('Gợi ý bạn bè', 'Suggested Friends'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        if (suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              AppPreferences.tr('Không có gợi ý mới', 'No new suggestions'),
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          )
        else
          SizedBox(
            height: 75,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final friend = suggestions[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: _isInviting ? null : () => _inviteFriend(friend),
                    borderRadius: BorderRadius.circular(30),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blueAccent.withOpacity(0.1),
                          backgroundImage: friend.avatarUrl != null
                              ? NetworkImage(friend.avatarUrl!)
                              : null,
                          child: friend.avatarUrl == null
                              ? Text(
                                  (friend.displayName ?? friend.email)
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueAccent,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 60,
                          child: Text(
                            friend.displayName ?? friend.email.split('@').first,
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRoleChip(String? role) {
    Color color;
    String label;

    switch (role) {
      case 'owner':
        color = Colors.purple;
        label = AppPreferences.tr('Chủ bảng', 'Owner');
        break;
      case 'admin':
        color = Colors.orange;
        label = AppPreferences.tr('Quản trị viên', 'Admin');
        break;
      case 'viewer':
        color = Colors.grey;
        label = AppPreferences.tr('Chỉ xem', 'Viewer');
        break;
      case 'member':
      default:
        color = Colors.blueAccent;
        label = AppPreferences.tr('Thành viên', 'Member');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color.withOpacity(0.8),
        ),
      ),
    );
  }
}
