import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/features/texts/domain/usecases/text_content_usecases.dart';
import 'package:flutter_pecha/features/texts/domain/usecases/text_search_usecases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'use_case_providers.dart';

// Re-export the search param classes for backward compatibility
export 'package:flutter_pecha/features/texts/domain/usecases/text_search_usecases.dart'
    show TitleSearchParams, AuthorSearchParams;

class TextDetailsParams {
  final String textId;
  final String? contentId;
  final String? versionId;
  final String? segmentId;
  final String? direction;
  final String key;
  const TextDetailsParams({
    required this.textId,
    this.contentId,
    this.versionId,
    this.segmentId,
    this.direction,
  }) : key =
           '${textId}_${contentId ?? ''}_${versionId ?? ''}_${segmentId ?? ''}_${direction ?? ''}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextDetailsParams &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;
}

final textsFutureProvider = FutureProvider.family((ref, String termId) {
  final locale = ref.watch(localeProvider);
  final languageCode = locale.languageCode;
  final repository = ref.watch(textsRepositoryProvider);
  return repository.getTexts(termId: termId, language: languageCode);
});

final textContentFutureProvider = FutureProvider.family((ref, String textId) async {
  final locale = ref.watch(localeProvider);
  final languageCode = locale.languageCode;
  final getTextContentUseCase = ref.watch(getTextContentUseCaseProvider);

  final result = await getTextContentUseCase(GetTextContentParams(
    textId: textId,
    language: languageCode,
  ));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (result) => result,
  );
});

final textVersionFutureProvider = FutureProvider.family((ref, String textId) async {
  final locale = ref.watch(localeProvider);
  final languageCode = locale.languageCode;
  final getTextVersionUseCase = ref.watch(getTextVersionUseCaseProvider);

  final result = await getTextVersionUseCase(GetTextVersionParams(
    textId: textId,
    language: languageCode,
  ));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (result) => result,
  );
});

final commentaryTextFutureProvider = FutureProvider.family((
  ref,
  String textId,
) async {
  final locale = ref.watch(localeProvider);
  final languageCode = locale.languageCode;
  final getCommentaryTextUseCase = ref.watch(getCommentaryTextUseCaseProvider);

  final result = await getCommentaryTextUseCase(GetCommentaryTextParams(
    textId: textId,
    language: languageCode,
  ));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (result) => result,
  );
});

final textDetailsFutureProvider = FutureProvider.family((
  ref,
  TextDetailsParams params,
) async {
  final getTextDetailsUseCase = ref.watch(getTextDetailsUseCaseProvider);

  final result = await getTextDetailsUseCase(GetTextDetailsParams(
    textId: params.textId,
    contentId: params.contentId,
    versionId: params.versionId,
    segmentId: params.segmentId,
    direction: params.direction,
  ));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (result) => result,
  );
});

class SearchTextParams {
  final String query;
  final String textId;
  const SearchTextParams({required this.query, required this.textId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchTextParams &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          textId == other.textId;

  @override
  int get hashCode => query.hashCode ^ textId.hashCode;
}

final searchTextFutureProvider = FutureProvider.family((
  ref,
  SearchTextParams params,
) async {
  final searchTextInTextUseCase = ref.watch(searchTextInTextUseCaseProvider);

  final result = await searchTextInTextUseCase(SearchTextInTextParams(
    query: params.query,
    textId: params.textId,
  ));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (result) => result,
  );
});

class LibrarySearchParams {
  final String query;
  final String? textId;
  final String? language;
  const LibrarySearchParams({required this.query, this.textId, this.language});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibrarySearchParams &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          textId == other.textId &&
          language == other.language;

  @override
  int get hashCode => query.hashCode ^ textId.hashCode ^ language.hashCode;
}

final librarySearchProvider = FutureProvider.family((
  ref,
  LibrarySearchParams params,
) async {
  final searchTextInTextUseCase = ref.watch(searchTextInTextUseCaseProvider);

  final result = await searchTextInTextUseCase(SearchTextInTextParams(
    query: params.query,
    textId: params.textId,
  ));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (result) => result,
  );
});

final multilingualSearchProvider = FutureProvider.family((
  ref,
  LibrarySearchParams params,
) async {
  final multilingualSearchUseCase = ref.watch(multilingualSearchUseCaseProvider);
  // Use provided language parameter, otherwise fall back to locale
  final language = params.language ?? ref.watch(localeProvider).languageCode;

  final result = await multilingualSearchUseCase(MultilingualSearchParams(
    query: params.query,
    language: language,
    textId: params.textId,
  ));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (result) => result,
  );
});

// Export the param classes from use cases for backward compatibility
final titleSearchProvider = FutureProvider.family((
  ref,
  TitleSearchParams params,
) async {
  final titleSearchUseCase = ref.watch(titleSearchUseCaseProvider);

  final result = await titleSearchUseCase(params);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (result) => result,
  );
});

final authorSearchProvider = FutureProvider.family((
  ref,
  AuthorSearchParams params,
) async {
  final authorSearchUseCase = ref.watch(authorSearchUseCaseProvider);

  final result = await authorSearchUseCase(params);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (result) => result,
  );
});
