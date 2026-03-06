part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

// Sprawdzenie na starcie aplikacji (Splash Screen)
class AuthCheckRequested extends AuthEvent {}

// Kliknięcie "Zaloguj"
class LoginRequested extends AuthEvent {
  final String? email;
  final String? password;

  const LoginRequested({this.email, this.password});

  @override
  List<Object?> get props => [email, password];
}

// Kliknięcie "Wyloguj"
class LogoutRequested extends AuthEvent {}

// Kliknięcie "Usuń konto"
class DeleteAccountRequested extends AuthEvent {}
