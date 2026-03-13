import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? role;

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.role,
  });

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  bool get isMember => role == 'member';
  bool get isViewer => role == 'viewer';

  bool get canManageBoard => role == 'owner' || role == 'admin';
  bool get canEditTask =>
      role == 'owner' || role == 'admin' || role == 'member';

  @override
  List<Object?> get props => [id, email, displayName, avatarUrl, role];
}
