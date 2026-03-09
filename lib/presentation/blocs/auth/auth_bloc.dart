import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  StreamSubscription? _authSubscription;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<SignInRequested>(_onSignInRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
    on<UpdatePasswordRequested>(_onUpdatePasswordRequested);
    on<AuthStatusChanged>(_onAuthStatusChanged);

    _authSubscription = authRepository.authStateChanges.listen((user) {
      add(AuthStatusChanged(user));
    });
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }

  void _onAuthStatusChanged(AuthStatusChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(Authenticated(event.user!));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    final user = authRepository.getCurrentUser();
    if (user != null) {
      emit(Authenticated(user));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignInRequested(
    SignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.signInWithGoogle();
      // OAuth process will happen in browser, no need to emit Authenticated here
      // The authStateChanges stream will handle the session once it returns
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.signUp(email: event.email, password: event.password);
      // Ngắt session mới tạo (nếu có) để ép người dùng phải đăng nhập lại theo ý muốn
      await authRepository.signOut();

      emit(
        const AuthActionSuccess(
          'Đăng ký thành công! Hãy đăng nhập để tiếp tục.',
        ),
      );
      emit(Unauthenticated());
    } catch (e) {
      if (e.toString().contains('CONFIRMATION_REQUIRED')) {
        emit(
          const AuthActionSuccess(
            'Đăng ký thành công! Vui lòng kiểm tra email để xác nhận tài khoản.',
          ),
        );
      } else {
        emit(AuthError(e.toString()));
      }
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.resetPassword(email: event.email);
      emit(const AuthActionSuccess('Đã gửi email khôi phục mật khẩu.'));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }

  Future<void> _onUpdatePasswordRequested(
    UpdatePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.updatePassword(newPassword: event.newPassword);
      emit(const AuthActionSuccess('Cập nhật mật khẩu thành công.'));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(Unauthenticated());
    }
  }
}
