import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/plan.dart';
import '../../domain/usecases/plans_usecases.dart';
import 'use_case_providers.dart';
import 'plan_search_provider.dart';
import 'find_plans_paginated_provider.dart';

final _logger = AppLogger('PlansProviders');

// Get all plans provider
final plansFutureProvider = FutureProvider<List<Plan>>((ref) async {
  final locale = ref.watch(localeProvider);
  final languageCode = locale.languageCode;
  final getPlansUseCase = ref.watch(getPlansUseCaseProvider);

  final result = await getPlansUseCase(GetPlansParams(
    language: languageCode,
  ));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (plans) => plans,
  );
});

final planByIdFutureProvider = FutureProvider.family<Plan, String>((
  ref,
  id,
) async {
  final getPlanDetailUseCase = ref.watch(getPlanDetailUseCaseProvider);

  final result = await getPlanDetailUseCase(GetPlanDetailParams(planId: id));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (plan) {
      if (plan == null) {
        throw Exception('Plan not found');
      }
      return plan;
    },
  );
});

// Find plans with pagination provider
final findPlansPaginatedProvider =
    StateNotifierProvider<FindPlansNotifier, FindPlansState>((ref) {
      _logger.debug('🏗️ Creating FindPlansNotifier instance...');
      final getPlansUseCase = ref.watch(getPlansUseCaseProvider);
      final locale = ref.watch(localeProvider);
      _logger.debug('📝 Locale: ${locale.languageCode}');
      final notifier = FindPlansNotifier(
        getPlansUseCase: getPlansUseCase,
        languageCode: locale.languageCode,
      );
      _logger.debug('✅ FindPlansNotifier instance created');
      return notifier;
    });

// Plan search provider
final planSearchProvider =
    StateNotifierProvider<PlanSearchNotifier, PlanSearchState>((ref) {
      final getPlansUseCase = ref.watch(getPlansUseCaseProvider);
      final locale = ref.watch(localeProvider);
      return PlanSearchNotifier(
        getPlansUseCase: getPlansUseCase,
        languageCode: locale.languageCode,
      );
    });
