import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> getCurrentUser(String idToken);
}

class AuthRemoteDatasourceImpl extends AuthRemoteDataSource {
  final Dio _dio;
  final String baseUrl = dotenv.env['BASE_API_URL']!;

  AuthRemoteDatasourceImpl({required Dio dio}) : _dio = dio;

  @override
  Future<UserModel> getCurrentUser(String idToken) async {
    try {
      final response = await _dio.get(
        '/users/info',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      } else {
        if (response.statusCode == 401) {
          throw const AuthenticationException('Unauthorized');
        } else if (response.statusCode == 403) {
          throw const AuthorizationException('Forbidden');
        } else if (response.statusCode == 404) {
          throw const NotFoundException('User not found');
        } else if (response.statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to get user: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
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
          throw const NotFoundException('User not found');
        } else if (statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to get user: $statusCode');
        }
      } else {
        throw const NetworkException('Network error');
      }
    }
  }
}
