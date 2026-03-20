part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final String role; // 'admin' lub 'user'
  final String email;

  const Authenticated(this.role, this.email);

  @override
  List<Object?> get props => [role, email];
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class PasswordChangeSuccess extends AuthState {
  final String message;

  const PasswordChangeSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
