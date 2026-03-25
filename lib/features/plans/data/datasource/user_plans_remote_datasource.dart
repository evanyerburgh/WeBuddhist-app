import 'package:dio/dio.dart';
import 'package:flutter_pecha/core/error/exceptions.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/plans/data/models/plan_progress_model.dart';
import 'package:flutter_pecha/features/plans/data/models/response/user_plan_day_detail_response.dart';
import 'package:flutter_pecha/features/plans/data/models/response/user_plan_day_completion_status_response.dart';
import 'package:flutter_pecha/features/plans/data/models/response/user_plan_list_response_model.dart';

class UserPlansRemoteDatasource {
  final Dio dio;
  final _logger = AppLogger('UserPlansRemoteDatasource');

  UserPlansRemoteDatasource({required this.dio});

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

  // get user plans by user id
  Future<UserPlanListResponseModel> fetchUserPlans({
    required String language,
    int? skip,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{'language': language};

      if (skip != null) {
        queryParams['skip'] = skip;
      }
      if (limit != null) {
        queryParams['limit'] = limit;
      }

      final response = await dio.get(
        '/users/me/plans',
        queryParameters: queryParams,
      );

      _logger.debug('Response status: ${response.statusCode}');
      _logger.debug('Response data type: ${response.data.runtimeType}');
      _logger.debug('Response data: ${response.data}');

      if (response.statusCode == 200) {
        // Handle case where response.data might be a String (HTML/plain text)
        if (response.data is String) {
          _logger.error('Received plain text response instead of JSON: ${response.data}');
          throw const ServerException('Invalid response format from server');
        }
        return UserPlanListResponseModel.fromJson(response.data);
      } else {
        _logger.error('Failed to load user plans: ${response.statusCode}');
        if (response.statusCode == 401) {
          throw const AuthenticationException('Unauthorized');
        } else if (response.statusCode == 403) {
          throw const AuthorizationException('Forbidden');
        } else if (response.statusCode == 404) {
          throw const NotFoundException('User plans not found');
        } else if (response.statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to load user plans: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to load user plans');
    }
  }

  //subscribe user to a plan
  Future<bool> subscribeToPlan(String planId) async {
    try {
      final response = await dio.post(
        '/users/me/plans',
        data: {'plan_id': planId},
      );

      if (response.statusCode == 204) {
        return true;
      } else {
        if (response.statusCode == 401) {
          throw const AuthenticationException('Unauthorized');
        } else if (response.statusCode == 403) {
          throw const AuthorizationException('Forbidden');
        } else if (response.statusCode == 404) {
          throw const NotFoundException('Plan not found');
        } else if (response.statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to subscribe to plan: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to subscribe to plan');
    }
  }

  // get user plan progress details
  Future<List<PlanProgressModel>> getUserPlanProgressDetails(
    String planId,
  ) async {
    try {
      final response = await dio.get('/users/me/plans/$planId');
      if (response.statusCode == 200) {
        final jsonData = response.data as List<dynamic>;
        return jsonData.map((json) => PlanProgressModel.fromJson(json)).toList();
      } else {
        if (response.statusCode == 401) {
          throw const AuthenticationException('Unauthorized');
        } else if (response.statusCode == 403) {
          throw const AuthorizationException('Forbidden');
        } else if (response.statusCode == 404) {
          throw const NotFoundException('Plan progress not found');
        } else if (response.statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to load user plan progress details: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to load user plan progress details');
    }
  }

  // fetch user plan day content or details
  Future<UserPlanDayDetailResponse> fetchUserPlanDayContent(
    String planId,
    int dayNumber,
  ) async {
    try {
      final response = await dio.get('/users/me/plan/$planId/days/$dayNumber');
      if (response.statusCode == 200) {
        return UserPlanDayDetailResponse.fromJson(response.data);
      } else {
        if (response.statusCode == 401) {
          throw const AuthenticationException('Unauthorized');
        } else if (response.statusCode == 403) {
          throw const AuthorizationException('Forbidden');
        } else if (response.statusCode == 404) {
          throw const NotFoundException('Plan day not found');
        } else if (response.statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to load user plan day content: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to load user plan day content');
    }
  }

  /// Fetch completion status for all days in a plan (bulk endpoint)
  /// Returns a map where key is dayNumber and value is isCompleted status
  Future<Map<int, bool>> fetchPlanDaysCompletionStatus(String planId) async {
    try {
      final response = await dio.get('/users/me/plans/$planId/days/completion_status');

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;
        final completionResponse =
            UserPlanDayCompletionStatusResponse.fromJson(jsonData);

        return completionResponse.toCompletionStatusMap();
      } else {
        _logger.error(
          'Failed to load plan days completion status: ${response.statusCode}',
        );
        if (response.statusCode == 401) {
          throw const AuthenticationException('Unauthorized');
        } else if (response.statusCode == 403) {
          throw const AuthorizationException('Forbidden');
        } else if (response.statusCode == 404) {
          throw const NotFoundException('Plan not found');
        } else if (response.statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to load plan days completion status: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to load plan days completion status');
    }
  }

  // sub tasks completion post request
  Future<bool> completeSubTask(String subTaskId) async {
    try {
      final response = await dio.post('/users/me/sub-tasks/$subTaskId/complete');

      if (response.statusCode == 204) {
        return true;
      } else {
        final errorMessage = 'HTTP ${response.statusCode}: ${response.data}';
        _logger.error('Failed to complete sub task: $errorMessage');
        if (response.statusCode == 401) {
          throw const AuthenticationException('Unauthorized');
        } else if (response.statusCode == 403) {
          throw const AuthorizationException('Forbidden');
        } else if (response.statusCode == 404) {
          throw const NotFoundException('Sub task not found');
        } else if (response.statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to complete sub task: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to complete sub task');
    }
  }

  // task completion post request
  Future<bool> completeTask(String taskId) async {
    try {
      final response = await dio.post('/users/me/tasks/$taskId/complete');

      if (response.statusCode == 204) {
        return true;
      } else {
        final errorMessage = 'HTTP ${response.statusCode}: ${response.data}';
        _logger.error('Failed to complete task: $errorMessage');
        if (response.statusCode == 401) {
          throw const AuthenticationException('Unauthorized');
        } else if (response.statusCode == 403) {
          throw const AuthorizationException('Forbidden');
        } else if (response.statusCode == 404) {
          throw const NotFoundException('Task not found');
        } else if (response.statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to complete task: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to complete task');
    }
  }

  // delete task request
  Future<bool> deleteTask(String taskId) async {
    try {
      final response = await dio.delete('/users/me/task/$taskId');

      if (response.statusCode == 204) {
        return true;
      } else {
        final errorMessage = 'HTTP ${response.statusCode}: ${response.data}';
        _logger.error('Failed to delete task: $errorMessage');
        if (response.statusCode == 401) {
          throw const AuthenticationException('Unauthorized');
        } else if (response.statusCode == 403) {
          throw const AuthorizationException('Forbidden');
        } else if (response.statusCode == 404) {
          throw const NotFoundException('Task not found');
        } else if (response.statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to delete task: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to delete task');
    }
  }

  // unenroll from plan request
  Future<bool> unenrollFromPlan(String planId) async {
    try {
      final response = await dio.delete('/users/me/plans/$planId');

      if (response.statusCode == 204) {
        return true;
      } else {
        final errorMessage = 'HTTP ${response.statusCode}: ${response.data}';
        _logger.error('Failed to unenroll from plan: $errorMessage');
        if (response.statusCode == 401) {
          throw const AuthenticationException('Unauthorized');
        } else if (response.statusCode == 403) {
          throw const AuthorizationException('Forbidden');
        } else if (response.statusCode == 404) {
          throw const NotFoundException('Plan enrollment not found');
        } else if (response.statusCode == 429) {
          throw const RateLimitException('Too many requests');
        } else {
          throw ServerException('Failed to unenroll from plan: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
      _throwDioException(e, 'Failed to unenroll from plan');
    }
  }
}
