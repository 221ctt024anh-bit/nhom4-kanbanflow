import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_constants.dart';
import '../../domain/entities/user.dart' as user_ent;
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient supabaseClient;

  AuthRepositoryImpl({required this.supabaseClient});

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await supabaseClient.auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseConstants.resetPasswordRedirectTo,
      );
    } catch (e) {
      throw Exception('Loi khi gui email khoi phuc: $e');
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await supabaseClient.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw Exception('Loi khi cap nhat mat khau: $e');
    }
  }

  @override
  Stream<user_ent.UserModel?> get authStateChanges {
    return supabaseClient.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return user_ent.UserModel(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'],
        avatarUrl: user.userMetadata?['avatar_url'],
      );
    });
  }

  @override
  user_ent.UserModel? getCurrentUser() {
    final user = supabaseClient.auth.currentUser;
    if (user == null) return null;
    return user_ent.UserModel(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'],
      avatarUrl: user.userMetadata?['avatar_url'],
    );
  }

  @override
  Future<user_ent.UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user!;
    return user_ent.UserModel(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'],
      avatarUrl: user.userMetadata?['avatar_url'],
    );
  }

  @override
  Future<void> signOut() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId != null) {
      try {
        await supabaseClient
            .from('profiles')
            .update({
              'is_online': false,
              'last_seen_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
      } catch (_) {}
    }
    await supabaseClient.auth.signOut();
  }

  @override
  Future<user_ent.UserModel> signUp({
    required String email,
    required String password,
  }) async {
    final response = await supabaseClient.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user!;

    await supabaseClient.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'display_name': email.split('@')[0],
    });

    return user_ent.UserModel(
      id: user.id,
      email: user.email ?? '',
      displayName: email.split('@')[0],
      avatarUrl: null,
    );
  }
}
