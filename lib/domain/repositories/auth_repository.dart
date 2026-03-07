import '../entities/user.dart';

abstract class AuthRepository {
  Future<UserModel> signUp({required String email, required String password});
  Future<UserModel> signIn({required String email, required String password});
  Future<void> signOut();
  UserModel? getCurrentUser();
  Stream<UserModel?> get authStateChanges;
  Future<void> resetPassword({required String email});
  Future<void> updatePassword({required String newPassword});
}
