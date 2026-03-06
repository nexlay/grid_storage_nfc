import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Importy Twoich UseCase'ów (z folderu inventory)
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/login_user.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/logout_user.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/check_auth_status.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/get_user_role.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  // Wstrzykujemy UseCase'y, a nie Repository bezpośrednio
  final LoginUser loginUser;
  final LogoutUser logoutUser;
  final CheckAuthStatus checkAuthStatus;
  final GetUserRole getUserRole;

  AuthBloc({
    required this.loginUser,
    required this.logoutUser,
    required this.checkAuthStatus,
    required this.getUserRole,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final isLoggedIn = await checkAuthStatus();
      if (isLoggedIn) {
        final role = await getUserRole() ?? 'web_user';
        emit(Authenticated(role));
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
      // Wywołanie UseCase z nazwanymi parametrami
      await loginUser(email: event.email, password: event.password);

      final role = await getUserRole() ?? 'web_user';
      emit(Authenticated(role));
    } catch (e) {
      // Usuwamy "Exception: " żeby komunikat był ładniejszy
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
    emit(Unauthenticated());
  }

  Future<void> _onDeleteAccountRequested(
    DeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Na razie tylko logujemy fakt, w przyszłości UseCase deleteAccount
    emit(AuthError("Delete account not fully implemented via UseCase yet"));
  }
}
