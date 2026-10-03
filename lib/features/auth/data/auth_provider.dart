import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skipit/core/services/supabase_provider.dart';
import 'package:skipit/core/config/app_config.dart';

/// Auth state that can be: loading, authenticated, unauthenticated, or error.
enum AuthStatus { loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.loading,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

/// Auth notifier handling all authentication state and operations.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final supabase = ref.watch(supabaseClientProvider);
    _listenAuthChanges(supabase);
    
    // Check initial session
    final session = supabase.auth.currentSession;
    if (session != null) {
      return AuthState(
        status: AuthStatus.authenticated,
        user: supabase.auth.currentUser,
      );
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  void _listenAuthChanges(SupabaseClient supabase) {
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) && data.session != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: data.session?.user,
        );
      } else if (event == AuthChangeEvent.signedOut || data.session == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  SupabaseClient get _supabase => ref.read(supabaseClientProvider);

  /// Sign up with email and password.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: AppConfig.signupRedirectUrl,
      );

      if (response.user != null) {
        // Create profile record
        try {
          await _supabase.from('profiles').insert({
            'id': response.user!.id,
            'full_name': fullName,
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          // Ignore profile insertion issues if it fails or already exists
          print('Profile creation during signup failed: $e');
        }

        if (response.session != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: response.user,
          );
        } else {
          state = AuthState(
            status: AuthStatus.unauthenticated,
            errorMessage: 'Signup successful! Please check your email to confirm your account, then log in.',
          );
        }
      } else {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Failed to create user. Please try again.',
        );
      }
    } on AuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Sign in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // State will be updated by the onAuthStateChange listener
    } on AuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Sign in with Google OAuth.
  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.googleRedirectUrl,
      );
    } on AuthException catch (e) {
      print('Supabase Google OAuth error: ${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Google Sign-In: ${e.message}',
      );
    } catch (e) {
      print('Google sign-in error: $e');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Google Sign-In failed: ${e.toString()}',
      );
    }
  }

  /// Send password reset email.
  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to send reset email.',
      );
      return false;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Clear any error message.
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// The main auth provider for the app.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
