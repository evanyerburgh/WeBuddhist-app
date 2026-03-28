import 'package:fpdart/fpdart.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/features/texts/data/models/search/search_response.dart';
import 'package:flutter_pecha/features/texts/data/models/search/multilingual_search_response.dart';
import 'package:flutter_pecha/features/texts/data/models/search/title_search_response.dart';
import 'package:flutter_pecha/shared/domain/base_classes/usecase.dart';
import 'package:flutter_pecha/features/texts/data/repositories/texts_repository.dart';

/// Search text in text use case.
class SearchTextInTextUseCase extends UseCase<SearchResponse, SearchTextInTextParams> {
  final TextsRepository _repository;

  SearchTextInTextUseCase(this._repository);

  @override
  Future<Either<Failure, SearchResponse>> call(SearchTextInTextParams params) async {
    if (params.query.trim().isEmpty) {
      return const Left(ValidationFailure('Search query cannot be empty'));
    }
    try {
      final result = await _repository.searchTextRepository(
        query: params.query,
        textId: params.textId,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure('Failed to search text: $e'));
    }
  }
}

class SearchTextInTextParams {
  final String query;
  final String? textId;

  const SearchTextInTextParams({
    required this.query,
    this.textId,
  });
}

/// Multilingual search use case.
class MultilingualSearchUseCase extends UseCase<MultilingualSearchResponse, MultilingualSearchParams> {
  final TextsRepository _repository;

  MultilingualSearchUseCase(this._repository);

  @override
  Future<Either<Failure, MultilingualSearchResponse>> call(MultilingualSearchParams params) async {
    if (params.query.trim().isEmpty) {
      return const Left(ValidationFailure('Search query cannot be empty'));
    }
    try {
      final result = await _repository.multilingualSearchRepository(
        query: params.query,
        language: params.language,
        textId: params.textId,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure('Failed to perform multilingual search: $e'));
    }
  }
}

class MultilingualSearchParams {
  final String query;
  final String? language;
  final String? textId;

  const MultilingualSearchParams({
    required this.query,
    this.language,
    this.textId,
  });
}

/// Title search use case.
class TitleSearchUseCase extends UseCase<TitleSearchResponse, TitleSearchParams> {
  final TextsRepository _repository;

  TitleSearchUseCase(this._repository);

  @override
  Future<Either<Failure, TitleSearchResponse>> call(TitleSearchParams params) async {
    try {
      final result = await _repository.titleSearchRepository(
        title: params.title,
        author: params.author,
        limit: params.limit,
        offset: params.offset,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure('Failed to search by title: $e'));
    }
  }
}

class TitleSearchParams {
  final String? title;
  final String? author;
  final int limit;
  final int offset;

  const TitleSearchParams({
    this.title,
    this.author,
    this.limit = 20,
    this.offset = 0,
  });
}

/// Author search use case.
class AuthorSearchUseCase extends UseCase<TitleSearchResponse, AuthorSearchParams> {
  final TextsRepository _repository;

  AuthorSearchUseCase(this._repository);

  @override
  Future<Either<Failure, TitleSearchResponse>> call(AuthorSearchParams params) async {
    try {
      final result = await _repository.authorSearchRepository(
        author: params.author,
        limit: params.limit,
        offset: params.offset,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure('Failed to search by author: $e'));
    }
  }
}

class AuthorSearchParams {
  final String? author;
  final int limit;
  final int offset;

  const AuthorSearchParams({
    this.author,
    this.limit = 20,
    this.offset = 0,
  });
}
