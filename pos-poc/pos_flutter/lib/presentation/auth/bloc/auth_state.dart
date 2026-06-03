import 'package:equatable/equatable.dart';
import '../../../data/models/employee.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final Employee? employee;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.employee,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    Employee? employee,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      employee: employee ?? this.employee,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, employee, errorMessage];
}
