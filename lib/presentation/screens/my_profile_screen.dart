import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_preferences.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _loading = true;
  String _displayName = 'User';
  String _email = '';
  String _bio = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final profile = await _client
          .from('profiles')
          .select('display_name,email,avatar_url,bio')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _displayName =
            (profile?['display_name'] as String?) ??
            (user.email?.split('@').first ?? 'User');
        _email = (profile?['email'] as String?) ?? (user.email ?? '');
        _avatarUrl = profile?['avatar_url'] as String?;
        _bio = (profile?['bio'] as String?) ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _displayName = user.email?.split('@').first ?? 'User';
        _email = user.email ?? '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppPreferences.tr('Trang cá nhân', 'Profile')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: Colors.blueAccent.withOpacity(0.15),
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null
                            ? Text(
                                _displayName.isEmpty
                                    ? 'U'
                                    : _displayName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                      if (_bio.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF334155)),
                        ),
                      ],
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/settings');
                          await _loadProfile();
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(
                          AppPreferences.tr('Chỉnh sửa hồ sơ', 'Edit profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
