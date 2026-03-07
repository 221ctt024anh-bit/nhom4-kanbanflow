import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Đệm tạm Profile người dùng để tránh gọi API nhiều lần
final Map<String, Map<String, dynamic>> _userCache = {};

class UserAvatar extends StatefulWidget {
  final String userId;
  final double radius;
  final bool showName;

  const UserAvatar({
    super.key,
    required this.userId,
    this.radius = 16,
    this.showName = false,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    if (_userCache.containsKey(widget.userId)) {
      if (mounted) {
        setState(() {
          _profile = _userCache[widget.userId];
        });
      }
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('email, display_name, avatar_url')
          .eq('id', widget.userId)
          .maybeSingle();

      if (response != null) {
        _userCache[widget.userId] = response;
        if (mounted) {
          setState(() {
            _profile = response;
          });
        }
      }
    } catch (_) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey[200],
        child: Icon(Icons.person, size: widget.radius, color: Colors.grey[400]),
      );
    }

    final displayName = _profile!['display_name'] as String?;
    final email = _profile!['email'] as String? ?? '';
    final avatarUrl = _profile!['avatar_url'] as String?;

    final nameToDisplay = displayName ?? email.split('@').first;
    final initials = nameToDisplay.isNotEmpty
        ? nameToDisplay.substring(0, 1).toUpperCase()
        : '?';

    Widget avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: widget.radius * 0.8,
              ),
            )
          : null,
    );

    if (widget.showName) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              nameToDisplay,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return avatar;
  }
}
