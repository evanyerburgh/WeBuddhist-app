import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/features/plans/domain/entities/plan.dart';
import 'package:flutter_pecha/features/plans/presentation/providers/plans_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/author_repository.dart';
import '../../data/datasource/author_remote_datasource.dart';
import '../../data/models/author/author_model.dart';

// Repository provider
final authorRepositoryProvider = Provider<AuthorRepository>((ref) {
  return AuthorRepository(
    authorRemoteDatasource: AuthorRemoteDatasource(
      dio: ref.watch(dioProvider),
    ),
  );
});

// Get author by ID provider
final authorByIdFutureProvider = FutureProvider.family<AuthorModel, String>((
  ref,
  id,
) {
  return ref.watch(authorRepositoryProvider).getAuthorById(id);
});

// Get plans by author ID provider (using repository and converting to domain entities)
final authorPlansFutureProvider =
    FutureProvider.family<List<Plan>, String>((ref, authorId) async {
      // Fetch all plans and filter by author
      final plansModels = await ref.watch(plansRepositoryProvider).getPlans(
        language: 'en',
        limit: 100,
      );
      // Convert to domain entities and filter by author
      return plansModels
          .map((model) => model.toEntity())
          .where((plan) => plan.authorId == authorId)
          .toList();
    });

// Author state notifier for managing local state
class AuthorState {
  final List<AuthorModel> authors;
  final bool isLoading;
  final String? errorMessage;

  const AuthorState({
    this.authors = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  AuthorState copyWith({
    List<AuthorModel>? authors,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthorState(
      authors: authors ?? this.authors,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthorNotifier extends StateNotifier<AuthorState> {
  final AuthorRepository repository;
  AuthorNotifier(this.repository) : super(const AuthorState());

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final authorNotifierProvider =
    StateNotifierProvider<AuthorNotifier, AuthorState>((ref) {
      final repository = ref.watch(authorRepositoryProvider);
      return AuthorNotifier(repository);
    });
