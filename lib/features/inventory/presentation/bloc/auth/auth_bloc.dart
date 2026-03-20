import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- NOWY IMPORT

import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/login_user.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/logout_user.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/check_auth_status.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/get_user_role.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/request_password_change.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUser loginUser;
  final LogoutUser logoutUser;
  final CheckAuthStatus checkAuthStatus;
  final GetUserRole getUserRole;
  final RequestPasswordChange requestPasswordChange;

  AuthBloc({
    required this.loginUser,
    required this.logoutUser,
    required this.checkAuthStatus,
    required this.getUserRole,
    required this.requestPasswordChange,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<PasswordChangeRequested>(_onPasswordChangeRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final isLoggedIn = await checkAuthStatus();
      if (isLoggedIn) {
        final role = await getUserRole() ?? 'user';

        // --- ZMIANA: Pobieramy zapisany e-mail z pamięci urządzenia ---
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('user_email') ?? '';

        emit(Authenticated(role, email)); // <-- Przekazujemy oba parametry
      } else {
        emit(Unauthenticated());
      }
    } catch (_) {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await loginUser(email: event.email, password: event.password);
      final role = await getUserRole() ?? 'user';

      // --- POPRAWKA NULL SAFETY ---
      // Tworzymy bezpieczną zmienną (jeśli event.email to null, dajemy pusty tekst '')
      final String safeEmail = event.email ?? '';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', safeEmail);

      emit(Authenticated(role, safeEmail)); // Przekazujemy bezpieczny email
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      emit(AuthError(message));
      emit(Unauthenticated());
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await logoutUser();

    // --- ZMIANA: Czyścimy zapisany e-mail przy wylogowaniu ---
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');

    emit(Unauthenticated());
  }

  Future<void> _onPasswordChangeRequested(
    PasswordChangeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await requestPasswordChange(event.email);
      emit(const PasswordChangeSuccess(
          "Password reset request sent to administrator."));
      emit(Unauthenticated());
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      emit(AuthError(message));
      emit(Unauthenticated());
    }
  }
}
