import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/features/texts/data/models/search/multilingual_search_response.dart';
import 'package:flutter_pecha/features/texts/data/models/search/search_response.dart';
import 'package:flutter_pecha/features/texts/data/models/search/title_search_response.dart';
import 'package:flutter_pecha/features/texts/data/models/text/commentary_text_response.dart';
import 'package:flutter_pecha/features/texts/data/models/text/detail_response.dart';
import 'package:flutter_pecha/features/texts/data/models/text/reader_response.dart';
import 'package:flutter_pecha/features/texts/data/models/text/toc_response.dart';
import 'package:flutter_pecha/features/texts/data/models/text/version_response.dart';

class TextRemoteDatasource {
  final Dio dio;
  final String baseUrl = dotenv.env['BASE_API_URL']!;

  TextRemoteDatasource({required this.dio});

  // Helper method to handle Dio errors
  Never _throwDioException(DioException e, String defaultMessage) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const NetworkException('Connection timeout');
    } else if (e.type == DioExceptionType.connectionError) {
      throw const NetworkException('No internet connection');
    } else if (e.response?.statusCode != null) {
      final statusCode = e.response!.statusCode!;
      if (statusCode == 401) {
        throw const AuthenticationException('Unauthorized');
      } else if (statusCode == 403) {
        throw const AuthorizationException('Forbidden');
      } else if (statusCode == 404) {
        throw const NotFoundException('Resource not found');
      } else if (statusCode == 429) {
        throw const RateLimitException('Too many requests');
      } else {
        throw ServerException('$defaultMessage: $statusCode');
      }
    } else {
      throw const NetworkException('Network error');
    }
  }

  // Helper method to handle status codes
  void _handleStatusCode(int statusCode, String defaultMessage) {
    if (statusCode == 401) {
      throw const AuthenticationException('Unauthorized');
    } else if (statusCode == 403) {
      throw const AuthorizationException('Forbidden');
    } else if (statusCode == 404) {
      throw const NotFoundException('Resource not found');
    } else if (statusCode == 429) {
      throw const RateLimitException('Too many requests');
    } else if (statusCode != 200) {
      throw ServerException('$defaultMessage: $statusCode');
    }
  }

  // to get the texts
  Future<TextDetailResponse> fetchTexts({
    required String termId,
    String? language,
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final response = await dio.get(
        '/texts',
        queryParameters: {
          'collection_id': termId,
          if (language != null) 'language': language,
          'skip': skip,
          'limit': limit,
        },
      );

      _handleStatusCode(response.statusCode!, 'Failed to load texts');
      return TextDetailResponse.fromJson(response.data);
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to load texts');
    }
  }

  // get the content of the text
  Future<TocResponse> fetchTextContent({
    required String textId,
    String? language,
  }) async {
    try {
      final response = await dio.get(
        '/texts/$textId/contents',
        queryParameters: {'language': language ?? 'en'},
      );

      _handleStatusCode(response.statusCode!, 'Failed to load text content');
      return TocResponse.fromJson(response.data);
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to load text content');
    }
  }

  // get the version of the text
  Future<VersionResponse> fetchTextVersion({
    required String textId,
    String? language,
  }) async {
    try {
      final response = await dio.get(
        '/texts/$textId/versions',
        queryParameters: {'language': language ?? 'en'},
      );

      _handleStatusCode(response.statusCode!, 'Failed to load text version');
      return VersionResponse.fromJson(response.data);
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to load text version');
    }
  }

  // get the commentary text of the text
  Future<CommentaryTextResponse> fetchCommentaryText({
    required String textId,
    String? language,
  }) async {
    try {
      final response = await dio.get(
        '/texts/$textId/commentaries',
        queryParameters: {'language': language ?? 'en'},
      );

      _handleStatusCode(response.statusCode!, 'Failed to load commentary text');
      return CommentaryTextResponse.fromJson(response.data);
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to load commentary text');
    }
  }

  // post request to get the details of the text
  Future<ReaderResponse> fetchTextDetails({
    required String textId,
    String? contentId,
    String? versionId,
    String? segmentId,
    String? direction,
  }) async {
    try {
      final response = await dio.post(
        '/texts/$textId/details',
        data: {
          if (contentId != null) 'content_id': contentId,
          if (segmentId != null) 'segment_id': segmentId,
          'direction': direction,
        },
      );

      _handleStatusCode(response.statusCode!, 'Failed to load text details');
      return ReaderResponse.fromJson(response.data);
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to load text details');
    }
  }

  // search the text by query
  Future<SearchResponse> searchText({
    required String query,
    String? language,
    String? textId,
  }) async {
    try {
      final response = await dio.get(
        '/search',
        queryParameters: {
          'query': query,
          'search_type': 'SOURCE',
          if (language != null) 'language': language,
          if (textId != null) 'text_id': textId,
        },
      );

      _handleStatusCode(response.statusCode!, 'Failed to search text');
      return SearchResponse.fromJson(response.data);
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to search text');
    }
  }

  // multilingual search
  Future<MultilingualSearchResponse> multilingualSearch({
    required String query,
    String? language,
    String? textId,
  }) async {
    try {
      final response = await dio.get(
        '/search/multilingual',
        queryParameters: {
          'query': query,
          'search_type': 'exact',
          if (language != null) 'language': language,
          if (textId != null) 'text_id': textId,
        },
      );

      _handleStatusCode(response.statusCode!, 'Failed to search text');
      return MultilingualSearchResponse.fromJson(response.data);
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to search text');
    }
  }

  // title search
  Future<TitleSearchResponse> titleSearch({
    String? title,
    String? author,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await dio.get(
        '/texts/title-search',
        queryParameters: {
          if (title != null && title.isNotEmpty) 'title': title,
          if (author != null && author.isNotEmpty) 'author': author,
          'limit': limit,
          'offset': offset,
        },
      );

      _handleStatusCode(response.statusCode!, 'Failed to search titles');
      final jsonList = response.data as List<dynamic>;
      return TitleSearchResponse.fromJson(
        jsonList,
        total: jsonList.length,
        limit: limit,
        offset: offset,
      );
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to search titles');
    }
  }

  // author search - uses same endpoint as title search but with author parameter
  Future<TitleSearchResponse> authorSearch({
    String? author,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await dio.get(
        '/texts/title-search',
        queryParameters: {
          if (author != null && author.isNotEmpty) 'author': author,
          'limit': limit,
          'offset': offset,
        },
      );

      _handleStatusCode(response.statusCode!, 'Failed to search authors');
      final jsonList = response.data as List<dynamic>;
      return TitleSearchResponse.fromJson(
        jsonList,
        total: jsonList.length,
        limit: limit,
        offset: offset,
      );
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to search authors');
    }
  }
}
