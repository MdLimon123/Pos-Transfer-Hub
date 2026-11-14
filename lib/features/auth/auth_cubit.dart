import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/failure.dart';
import 'auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.busy = false,
    this.error,
  });

  final AuthStatus status;
  final String? user;
  final bool busy;
  final String? error;

  @override
  List<Object?> get props => [status, user, busy, error];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthState()) {
    _repo.onUnauthorized = sessionExpired;
  }

  final AuthRepository _repo;

  Future<void> restore() async {
    final token = await _repo.restore();
    if (token == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } else {
      emit(AuthState(
          status: AuthStatus.authenticated, user: TokenInfo.parse(token)?.user));
    }
  }

  Future<void> login(String username, String password) async {
    emit(const AuthState(status: AuthStatus.unauthenticated, busy: true));
    try {
      final token = await _repo.login(username.trim(), password);
      emit(AuthState(
          status: AuthStatus.authenticated,
          user: TokenInfo.parse(token)?.user ?? username.trim()));
    } catch (e) {
      emit(AuthState(
          status: AuthStatus.unauthenticated, error: Failure.from(e).message));
    }
  }

  /// Lets a reviewer paste the token from the assessment e-mail.
  Future<void> loginWithToken(String token) async {
    final value = token.trim();
    final info = TokenInfo.parse(value);
    if (info == null || info.expired) {
      emit(const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'That token is invalid or has expired.'));
      return;
    }
    await _repo.saveToken(value);
    emit(AuthState(status: AuthStatus.authenticated, user: info.user));
  }

  Future<void> logout() async {
    await _repo.clear();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> sessionExpired() async {
    if (state.status != AuthStatus.authenticated) return;
    await _repo.clear();
    emit(const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Your session has expired. Please sign in again.'));
  }
}
