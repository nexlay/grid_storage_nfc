part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String? email;
  final String? password;

  const LoginRequested({this.email, this.password});

  @override
  List<Object?> get props => [email, password];
}

class LogoutRequested extends AuthEvent {}

class PasswordChangeRequested extends AuthEvent {
  final String email;

  const PasswordChangeRequested(this.email);

  @override
  List<Object?> get props => [email];
}
