import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_preferences.dart';
import '../../data/repositories/user_settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = UserSettingsRepository();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  bool _inAppNotifications = true;
  bool _emailNotifications = true;
  String _themeMode = 'system';
  String _languageCode = 'vi';

  String? _userId;
  String? _avatarUrl;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarExtension;

  bool _isMissingColumnError(Object error) {
    return error is PostgrestException && error.code == '42703';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    _userId = user.id;
    try {
      Map<String, dynamic>? profile;
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('display_name,email,avatar_url,bio')
            .eq('id', user.id)
            .maybeSingle();
        profile = response;
      } catch (e) {
        if (!_isMissingColumnError(e)) rethrow;
        final response = await Supabase.instance.client
            .from('profiles')
            .select('display_name,email,avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        profile = response;
      }

      final settings = await _repo.getSettings(user.id);
      if (!mounted) return;

      setState(() {
        _displayNameController.text =
            (profile?['display_name'] as String?) ??
            user.email?.split('@').first ??
            '';
        _bioController.text = (profile?['bio'] as String?) ?? '';
        _avatarUrl = profile?['avatar_url'] as String?;
        _inAppNotifications = settings.inAppNotifications;
        _emailNotifications = settings.emailNotifications;
        _themeMode = settings.themeMode;
        _languageCode = settings.languageCode;
      });
    } catch (_) {
      // Ignore load errors.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showSnack(
          _t('Không đọc được dữ liệu ảnh', 'Could not read image data'),
        );
        return;
      }

      final fileName = file.name.toLowerCase();
      String extension = 'jpg';
      if (fileName.endsWith('.png')) {
        extension = 'png';
      } else if (fileName.endsWith('.webp')) {
        extension = 'webp';
      } else if (fileName.endsWith('.gif')) {
        extension = 'gif';
      } else if (fileName.endsWith('.jpeg') || fileName.endsWith('.jpg')) {
        extension = 'jpg';
      }

      setState(() {
        _pendingAvatarBytes = file.bytes;
        _pendingAvatarExtension = extension;
      });
    } catch (e) {
      _showSnack('${_t('Chọn ảnh thất bại', 'Image selection failed')}: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_userId == null) return;

    final displayName = _displayNameController.text.trim();
    final bio = _bioController.text.trim();
    if (displayName.isEmpty) {
      _showSnack(
        _t('Tên hiển thị không được để trống', 'Display name cannot be empty'),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? newAvatarUrl;
      if (_pendingAvatarBytes != null && _pendingAvatarExtension != null) {
        newAvatarUrl = await _repo.uploadAvatar(
          userId: _userId!,
          bytes: _pendingAvatarBytes!,
          fileExtension: _pendingAvatarExtension!,
        );
        _avatarUrl = newAvatarUrl;
        _pendingAvatarBytes = null;
        _pendingAvatarExtension = null;
      }

      await _repo.updateProfile(
        userId: _userId!,
        displayName: displayName,
        bio: bio,
        avatarUrl: newAvatarUrl,
      );

      await _repo.updateSettings(
        userId: _userId!,
        inAppNotifications: _inAppNotifications,
        emailNotifications: _emailNotifications,
        themeMode: _themeMode,
        languageCode: _languageCode,
      );
      AppPreferences.apply(themeMode: _themeMode, languageCode: _languageCode);

      _showSnack(_t('Đã lưu tất cả thay đổi', 'All changes saved'));
    } catch (e) {
      final message = e is PostgrestException
          ? (e.message.isNotEmpty ? e.message : e.toString())
          : e.toString();
      _showSnack(
        '${_t('Lưu cài đặt thất bại', 'Failed to save settings')}: $message',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveBasicSettings() async {
    if (_userId == null) return;
    try {
      await _repo.updateSettings(
        userId: _userId!,
        inAppNotifications: _inAppNotifications,
        emailNotifications: _emailNotifications,
        themeMode: _themeMode,
        languageCode: _languageCode,
      );
    } catch (_) {
      // Background save errors ignored
    }
  }

  String _t(String vi, String en) => _languageCode == 'en' ? en : vi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [
                    const Color(0xFF1A1D21),
                    const Color(0xFF14171A),
                    const Color(0xFF0D0F11),
                  ]
                : [
                    const Color(0xFFF6F9FF),
                    const Color(0xFFEFF4FF),
                    const Color(0xFFF8FBFF),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                        child: Row(
                          children: [
                            _iconShell(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                _t('Cài đặt', 'Settings'),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF12263F),
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ),
                            _saveButton(),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _sectionCard(
                            title: _t('Tài khoản', 'Account'),
                            icon: Icons.person_outline_rounded,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: const Color(0xFFDFE9FF),
                                      backgroundImage:
                                          _pendingAvatarBytes != null
                                          ? MemoryImage(_pendingAvatarBytes!)
                                          : (_avatarUrl != null
                                                ? NetworkImage(_avatarUrl!)
                                                : null),
                                      child:
                                          (_pendingAvatarBytes == null &&
                                              _avatarUrl == null)
                                          ? const Icon(
                                              Icons.person_outline_rounded,
                                              color: Color(0xFF2E66FF),
                                              size: 30,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _saving ? null : _pickAvatar,
                                        icon: const Icon(
                                          Icons.photo_camera_outlined,
                                        ),
                                        label: Text(
                                          _t(
                                            'Đổi ảnh đại diện',
                                            'Change avatar',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _displayNameController,
                                  decoration: InputDecoration(
                                    labelText: _t(
                                      'Tên hiển thị',
                                      'Display name',
                                    ),
                                    hintText: _t(
                                      'Nhập tên của bạn',
                                      'Enter your name',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.badge_outlined,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).cardColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.blueGrey.withOpacity(0.2),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.blueGrey.withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _bioController,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    labelText: _t('Mô tả bản thân', 'Bio'),
                                    hintText: _t(
                                      'Viết vài dòng giới thiệu về bạn',
                                      'Write a few lines about yourself',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.edit_note_rounded,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).cardColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.blueGrey.withOpacity(0.2),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.blueGrey.withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: _t('Thông báo', 'Notifications'),
                            icon: Icons.notifications_active_outlined,
                            child: Column(
                              children: [
                                _switchTile(
                                  title: _t(
                                    'Thông báo trong app',
                                    'In-app notifications',
                                  ),
                                  subtitle: _t(
                                    'Hiển thị chuông, badge và thông báo nội bộ',
                                    'Show bell, badge and internal notifications',
                                  ),
                                  value: _inAppNotifications,
                                  onChanged: (value) async {
                                    setState(() => _inAppNotifications = value);
                                    await _saveBasicSettings();
                                  },
                                ),
                                const SizedBox(height: 10),
                                _switchTile(
                                  title: _t(
                                    'Thông báo qua email',
                                    'Email notifications',
                                  ),
                                  subtitle: _t(
                                    'Nhận email khi có bình luận mới',
                                    'Receive email when there are new comments',
                                  ),
                                  value: _emailNotifications,
                                  onChanged: (value) async {
                                    setState(() => _emailNotifications = value);
                                    await _saveBasicSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: _t('Giao diện', 'Appearance'),
                            icon: Icons.palette_outlined,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t('Chế độ hiển thị', 'Theme mode'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF344560),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _choiceChip(
                                      'system',
                                      _t('Theo hệ thống', 'System'),
                                    ),
                                    _choiceChip('light', _t('Sáng', 'Light')),
                                    _choiceChip('dark', _t('Tối', 'Dark')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: _t('Ngôn ngữ', 'Language'),
                            icon: Icons.language_rounded,
                            child: DropdownButtonFormField<String>(
                              value: _languageCode,
                              items: [
                                DropdownMenuItem(
                                  value: 'vi',
                                  child: Text(_t('Tiếng Việt', 'Vietnamese')),
                                ),
                                const DropdownMenuItem(
                                  value: 'en',
                                  child: Text('English'),
                                ),
                              ],
                              onChanged: (value) {
                                final next = value ?? 'vi';
                                _updatePrefsOptimistically(lang: next);
                              },
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.translate),
                                filled: true,
                                fillColor: Theme.of(context).cardColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.blueGrey.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.blueGrey.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: _t('Về ứng dụng', 'About'),
                            icon: Icons.info_outline_rounded,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withOpacity(0.05)
                                    : const Color(0xFFF7FAFF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white.withOpacity(0.1)
                                      : const Color(0xFFCFDBF3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.apps_rounded,
                                    color: const Color(0xFF2859D6),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'TaskMate\n${_t('Phiên bản', 'Version')} 1.0.0',
                                      style: TextStyle(
                                        height: 1.4,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withOpacity(0.8)
                                            : const Color(0xFF1D2E45),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _saveButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saving ? null : _saveSettings,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: _saving
                  ? [Colors.grey.shade400, Colors.grey.shade400]
                  : [const Color(0xFF2F6BFF), const Color(0xFF00A3FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F6BFF).withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _t('Lưu', 'Save'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _iconShell({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : const Color(0xFFD7E2F3),
          ),
        ),
        child: Icon(
          icon,
          size: 19,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF233A59),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF212529)
            : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white12
              : const Color(0xFFDDE7F7),
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF284B8D).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E66FF), Color(0xFF56A9FF)],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF142C4A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white10
              : const Color(0xFFD7E4FA),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1F334F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.8,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white60
                        : const Color(0xFF5A6E8D),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF2E66FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _choiceChip(String value, String label) {
    final selected = _themeMode == value;
    return GestureDetector(
      onTap: () => _updatePrefsOptimistically(theme: value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: selected ? const Color(0xFF2E66FF) : const Color(0xFFF4F7FC),
          border: Border.all(
            color: selected ? const Color(0xFF2E66FF) : const Color(0xFFD2DCEC),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E66FF).withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF344560),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Timer? _prefDebounce;
  void _updatePrefsOptimistically({String? theme, String? lang}) {
    setState(() {
      if (theme != null) _themeMode = theme;
      if (lang != null) _languageCode = lang;
    });

    _prefDebounce?.cancel();
    _prefDebounce = Timer(const Duration(milliseconds: 300), () {
      AppPreferences.apply(themeMode: _themeMode, languageCode: _languageCode);
    });
  }
}
