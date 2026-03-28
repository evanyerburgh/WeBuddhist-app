import 'package:flutter_pecha/core/di/core_providers.dart';
import 'package:flutter_pecha/features/texts/data/datasource/text_remote_datasource.dart';
import 'package:flutter_pecha/features/texts/data/repositories/texts_repository.dart';
import 'package:flutter_pecha/features/texts/domain/usecases/text_content_usecases.dart';
import 'package:flutter_pecha/features/texts/domain/usecases/text_search_usecases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ========== Repository Provider ==========

/// Provider for the TextsRepository (data layer implementation).
/// This repository handles caching, offline support, and API communication.
final textsRepositoryProvider = Provider<TextsRepository>((ref) {
  return TextsRepository(
    remoteDatasource: TextRemoteDatasource(
      dio: ref.watch(dioProvider),
    ),
  );
});

// ========== Content Use Case Providers ==========

/// Provider for GetTextContentUseCase.
final getTextContentUseCaseProvider = Provider<GetTextContentUseCase>((ref) {
  final repository = ref.watch(textsRepositoryProvider);
  return GetTextContentUseCase(repository);
});

/// Provider for GetTextVersionUseCase.
final getTextVersionUseCaseProvider = Provider<GetTextVersionUseCase>((ref) {
  final repository = ref.watch(textsRepositoryProvider);
  return GetTextVersionUseCase(repository);
});

/// Provider for GetCommentaryTextUseCase.
final getCommentaryTextUseCaseProvider = Provider<GetCommentaryTextUseCase>((ref) {
  final repository = ref.watch(textsRepositoryProvider);
  return GetCommentaryTextUseCase(repository);
});

/// Provider for GetTextDetailsUseCase.
final getTextDetailsUseCaseProvider = Provider<GetTextDetailsUseCase>((ref) {
  final repository = ref.watch(textsRepositoryProvider);
  return GetTextDetailsUseCase(repository);
});

// ========== Search Use Case Providers ==========

/// Provider for SearchTextInTextUseCase.
final searchTextInTextUseCaseProvider = Provider<SearchTextInTextUseCase>((ref) {
  final repository = ref.watch(textsRepositoryProvider);
  return SearchTextInTextUseCase(repository);
});

/// Provider for MultilingualSearchUseCase.
final multilingualSearchUseCaseProvider = Provider<MultilingualSearchUseCase>((ref) {
  final repository = ref.watch(textsRepositoryProvider);
  return MultilingualSearchUseCase(repository);
});

/// Provider for TitleSearchUseCase.
final titleSearchUseCaseProvider = Provider<TitleSearchUseCase>((ref) {
  final repository = ref.watch(textsRepositoryProvider);
  return TitleSearchUseCase(repository);
});

/// Provider for AuthorSearchUseCase.
final authorSearchUseCaseProvider = Provider<AuthorSearchUseCase>((ref) {
  final repository = ref.watch(textsRepositoryProvider);
  return AuthorSearchUseCase(repository);
});
