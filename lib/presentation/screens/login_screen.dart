import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app_preferences.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Deep Slate
                  Color(0xFF1E293B), // Navy Slate
                  Color(0xFF334155), // Light Slate
                ],
              ),
            ),
          ),

          // 2. Abstract Geometric Shapes (Glassmorphism blobs)
          Positioned(
            top: -100,
            right: -50,
            child: _buildBlob(
              size: 300,
              color: Colors.blueAccent.withOpacity(0.15),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -80,
            child: _buildBlob(
              size: 250,
              color: Colors.indigoAccent.withOpacity(0.15),
            ),
          ),

          // 3. Main Content
          BlocConsumer<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    content: Text(state.message),
                  ),
                );
              }
              if (state is AuthActionSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.greenAccent,
                    behavior: SnackBarBehavior.floating,
                    content: Text(state.message),
                  ),
                );
              }
            },
            builder: (context, state) {
              final isLoading = state is AuthLoading;

              return SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo Section with Glow
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.3),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            size: 72,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Title Section
                        Text(
                          'TaskMate',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: const Offset(0, 4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppPreferences.tr(
                            'Quản lý công việc đỉnh cao',
                            'Modern Task Management',
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 64),

                        // Glassmorphism Center Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppPreferences.tr(
                                      'Chào mừng bạn',
                                      'Welcome Back',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  _buildGoogleButton(context, isLoading),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Version or Footer
                        Text(
                          'v1.0.0',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildGoogleButton(BuildContext context, bool isLoading) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading
            ? null
            : () => context.read<AuthBloc>().add(GoogleSignInRequested()),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF0F172A),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.login_rounded,
                        color: Color(0xFF0F172A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Flexible(
                      child: Text(
                        'Sign in with Google',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
