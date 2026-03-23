import 'package:flutter_pecha/core/utils/local_storage_service.dart';
import 'package:flutter_pecha/features/auth/data/datasource/auth_remote_datasource.dart';
import 'package:flutter_pecha/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_pecha/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/clear_guest_mode_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/continue_as_guest_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/get_credentials_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/get_valid_id_token_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/has_valid_credentials_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/initialize_auth_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/is_guest_mode_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/logout_usecase.dart';
import 'package:flutter_pecha/features/auth/domain/usecases/refresh_id_token_usecase.dart';
import 'package:flutter_pecha/features/auth/auth_service.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/user_notifier.dart';
import 'package:flutter_pecha/features/auth/presentation/providers/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Provider for Auth Service (working implementation)
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.instance;
});

/// Provider for basic HTTP client (for remote data source)
/// This breaks the circular dependency between ApiClient and AuthRepository
final basicHttpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// Provider for Auth Remote Data Source
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final client = ref.watch(basicHttpClientProvider);
  return AuthRemoteDatasourceImpl(client: client);
});

/// Provider for Auth Repository (wraps AuthService)
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);

  return AuthRepositoryImpl(
    authService: authService,
    remoteDataSource: remoteDataSource,
  );
});

// ========== Use Case Providers ==========

/// Provider for LoginUseCase.
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LoginUseCase(repository);
});

/// Provider for InitializeAuthUseCase.
final initializeAuthUseCaseProvider = Provider<InitializeAuthUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return InitializeAuthUseCase(repository);
});

/// Provider for HasValidCredentialsUseCase.
final hasValidCredentialsUseCaseProvider = Provider<HasValidCredentialsUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return HasValidCredentialsUseCase(repository);
});

/// Provider for GetCredentialsUseCase.
final getCredentialsUseCaseProvider = Provider<GetCredentialsUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return GetCredentialsUseCase(repository);
});

/// Provider for GetValidIdTokenUseCase.
final getValidIdTokenUseCaseProvider = Provider<GetValidIdTokenUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return GetValidIdTokenUseCase(repository);
});

/// Provider for RefreshIdTokenUseCase.
final refreshIdTokenUseCaseProvider = Provider<RefreshIdTokenUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return RefreshIdTokenUseCase(repository);
});

/// Provider for ContinueAsGuestUseCase.
final continueAsGuestUseCaseProvider = Provider<ContinueAsGuestUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return ContinueAsGuestUseCase(repository);
});

/// Provider for IsGuestModeUseCase.
final isGuestModeUseCaseProvider = Provider<IsGuestModeUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return IsGuestModeUseCase(repository);
});

/// Provider for ClearGuestModeUseCase.
final clearGuestModeUseCaseProvider = Provider<ClearGuestModeUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return ClearGuestModeUseCase(repository);
});

/// Provider for LogoutUseCase (LocalLogout).
final localLogoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LogoutUseCase(repository);
});

/// Provider for GetCurrentUserUseCase.
final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return GetCurrentUserUseCase(repository);
});

// ========== State Management Providers ==========

/// Provider for Auth State Management
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    initializeAuthUseCase: ref.watch(initializeAuthUseCaseProvider),
    hasValidCredentialsUseCase: ref.watch(hasValidCredentialsUseCaseProvider),
    getCredentialsUseCase: ref.watch(getCredentialsUseCaseProvider),
    continueAsGuestUseCase: ref.watch(continueAsGuestUseCaseProvider),
    isGuestModeUseCase: ref.watch(isGuestModeUseCaseProvider),
    clearGuestModeUseCase: ref.watch(clearGuestModeUseCaseProvider),
    localLogoutUseCase: ref.watch(localLogoutUseCaseProvider),
    ref: ref,
  );
});

/// Provider for User State Management
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final localStorageService = ref.watch(localStorageServiceProvider);
  return UserNotifier(
    getCurrentUserUseCase: ref.watch(getCurrentUserUseCaseProvider),
    localStorageService: localStorageService,
  );
});
