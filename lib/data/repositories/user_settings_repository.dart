import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_settings.dart';

class UserSettingsRepository {
  final SupabaseClient _client;

  UserSettingsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<UserSettings> getSettings(String userId) async {
    final response = await _client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      await _client.from('user_settings').insert({'user_id': userId});
      return UserSettings(
        userId: userId,
        inAppNotifications: true,
        emailNotifications: true,
        themeMode: 'system',
        languageCode: 'vi',
      );
    }

    return UserSettings(
      userId: response['user_id'] as String,
      inAppNotifications: (response['in_app_notifications'] as bool?) ?? true,
      emailNotifications: (response['email_notifications'] as bool?) ?? true,
      themeMode: (response['theme_mode'] as String?) ?? 'system',
      languageCode: (response['language_code'] as String?) ?? 'vi',
    );
  }

  Future<void> updateSettings({
    required String userId,
    bool? inAppNotifications,
    bool? emailNotifications,
    String? themeMode,
    String? languageCode,
  }) async {
    final payload = <String, dynamic>{'user_id': userId};
    if (inAppNotifications != null) {
      payload['in_app_notifications'] = inAppNotifications;
    }
    if (emailNotifications != null) {
      payload['email_notifications'] = emailNotifications;
    }
    if (themeMode != null) {
      payload['theme_mode'] = themeMode;
    }
    if (languageCode != null) {
      payload['language_code'] = languageCode;
    }

    await _client.from('user_settings').upsert(payload, onConflict: 'user_id');
  }

  Future<void> updateDisplayName({
    required String userId,
    required String displayName,
  }) async {
    await _client
        .from('profiles')
        .update({'display_name': displayName})
        .eq('id', userId);
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final safeExtension = fileExtension.toLowerCase().replaceAll('.', '');
    final filePath = '$userId/avatar.$safeExtension';
    final contentType = lookupMimeType('avatar.$safeExtension') ?? 'image/jpeg';

    await _client.storage.from('profile-avatars').uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: true,
        contentType: contentType,
      ),
    );

    return _client.storage.from('profile-avatars').getPublicUrl(filePath);
  }

  Future<void> updateAvatarUrl({
    required String userId,
    required String avatarUrl,
  }) async {
    await _client
        .from('profiles')
        .update({'avatar_url': avatarUrl})
        .eq('id', userId);
  }

  Future<void> updateBio({
    required String userId,
    required String bio,
  }) async {
    try {
      await _client.from('profiles').update({'bio': bio}).eq('id', userId);
    } catch (e) {
      if (e is PostgrestException && e.code == '42703') {
        return;
      }
      rethrow;
    }
  }
}
