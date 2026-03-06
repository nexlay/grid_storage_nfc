part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

// Stan początkowy
class AuthInitial extends AuthState {}

// Kręcące się kółko
class AuthLoading extends AuthState {}

// Zalogowany (wiemy jaka rola)
class Authenticated extends AuthState {
  final String role; // 'web_admin' lub 'web_user'

  const Authenticated(this.role);

  @override
  List<Object?> get props => [role];
}

// Niezalogowany (pokaż ekran logowania)
class Unauthenticated extends AuthState {}

// Błąd (pokaż SnackBar)
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
