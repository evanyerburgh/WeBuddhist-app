import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_model.dart';
import 'package:flutter_pecha/features/recitation/data/models/recitation_content_model.dart';

class RecitationsQueryParams {
  final String? language;
  final String? search;

  RecitationsQueryParams({this.language, this.search});

  Map<String, dynamic> toQueryParams() {
    final Map<String, dynamic> params = {};
    if (language != null) params['language'] = language!;
    if (search != null && search!.isNotEmpty) params['search'] = search!;
    return params;
  }
}

class RecitationsRemoteDatasource {
  final Dio dio;
  final _logger = AppLogger('RecitationsRemoteDatasource');

  RecitationsRemoteDatasource({required this.dio});

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
    } else if (statusCode != 200 && statusCode != 201 && statusCode != 204) {
      throw ServerException('$defaultMessage: $statusCode');
    }
  }

  // Get all recitations
  Future<List<RecitationModel>> fetchRecitations({
    RecitationsQueryParams? queryParams,
  }) async {
    try {
      final response = await dio.get(
        '/recitations',
        queryParameters: queryParams?.toQueryParams(),
      );

      _handleStatusCode(response.statusCode!, 'Failed to fetch recitations');

      final responseData = response.data as Map<String, dynamic>;
      final List<dynamic> recitationsData =
          responseData['recitations'] as List<dynamic>? ?? [];

      return recitationsData
          .map(
            (json) => RecitationModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to fetch recitations');
    }
  }

  // Get saved recitations
  Future<List<RecitationModel>> fetchSavedRecitations() async {
    try {
      final response = await dio.get('/users/me/recitations');

      _handleStatusCode(response.statusCode!, 'Failed to fetch saved recitations');

      final responseData = response.data as Map<String, dynamic>;
      final List<dynamic> recitationsData =
          responseData['recitations'] as List<dynamic>? ?? [];
      return recitationsData
          .map(
            (json) => RecitationModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to fetch saved recitations');
    }
  }

  // Get recitation content by text ID
  Future<RecitationContentModel> fetchRecitationContent(
    String id, {
    required String language,
    List<String>? recitation,
    List<String>? translations,
    List<String>? transliterations,
    List<String>? adaptations,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'language': language,
        'recitation': recitation ?? [],
        'translations': translations ?? [],
        'transliterations': transliterations ?? [],
        'adaptations': adaptations ?? [],
      };

      _logger.debug('Fetching recitation content for ID: $id');
      _logger.debug('Request body: $requestBody');

      final response = await dio.post(
        '/recitations/$id',
        data: requestBody,
      );

      _handleStatusCode(response.statusCode!, 'Failed to fetch recitation content');
      return RecitationContentModel.fromJson(response.data);
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to fetch recitation content');
    }
  }

  // Save recitation to user's saved recitations
  Future<bool> saveRecitation(String id) async {
    try {
      final response = await dio.post(
        '/users/me/recitations',
        data: {'text_id': id},
      );

      _handleStatusCode(response.statusCode!, 'Failed to save recitation');
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to save recitation');
    }
  }

  // Unsave recitation from user's saved recitations
  Future<bool> unsaveRecitation(String textId) async {
    try {
      final response = await dio.delete('/users/me/recitations/$textId');

      _handleStatusCode(response.statusCode!, 'Failed to unsave recitation');
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to unsave recitation');
    }
  }

  // Update recitations order
  Future<bool> updateRecitationsOrder(
    List<Map<String, dynamic>> recitations,
  ) async {
    try {
      _logger.debug('Updating recitations order: $recitations');
      final response = await dio.put(
        '/users/me/recitations/order',
        data: {'recitations': recitations},
      );

      _handleStatusCode(response.statusCode!, 'Failed to update recitations order');
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to update recitations order');
    }
  }
}
