import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/plans/data/repositories/plans_repository.dart';
import 'package:flutter_pecha/features/plans/domain/entities/plan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = AppLogger('FindPlansNotifier');

/// State for paginated plans list
class FindPlansState {
  final List<Plan> plans;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int skip;

  const FindPlansState({
    this.plans = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.skip = 0,
  });

  FindPlansState copyWith({
    List<Plan>? plans,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? skip,
  }) {
    return FindPlansState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      skip: skip ?? this.skip,
    );
  }
}

/// StateNotifier for paginated find plans
class FindPlansNotifier extends StateNotifier<FindPlansState> {
  final PlansRepository repository;
  final String languageCode;
  static const int _limit = 20;

  FindPlansNotifier({required this.repository, required this.languageCode})
    : super(const FindPlansState()) {
    _logger.debug('🏗️ FindPlansNotifier CREATED with language: $languageCode');
    loadInitial();
  }

  @override
  void dispose() {
    _logger.debug('💥 FindPlansNotifier DISPOSED - this will reset state!');
    super.dispose();
  }

  /// Load initial plans
  Future<void> loadInitial() async {
    _logger.debug('🔄 loadInitial() called - current state: ${state.plans.length} plans, isLoading: ${state.isLoading}');

    if (state.isLoading) {
      _logger.debug('⏸️ Already loading, skipping');
      return;
    }

    _logger.debug('📊 Setting isLoading: true');
    state = state.copyWith(isLoading: true, error: null);
    _logger.debug('📊 State after setting loading: ${state.plans.length} plans, isLoading: ${state.isLoading}');

    try {
      _logger.debug('🌐 Calling repository.getPlans(language: $languageCode, skip: 0, limit: $_limit)');
      final plans = await repository.getPlans(
        language: languageCode,
        skip: 0,
        limit: _limit,
      );

      _logger.debug('✅ Got ${plans.length} plans from repository');

      if (mounted) {
        _logger.debug('📦 Updating state with ${plans.length} plans');
        final planEntities = plans.map((model) => model.toEntity()).toList();
        final newState = state.copyWith(
          plans: planEntities,
          isLoading: false,
          hasMore: plans.length >= _limit,
          skip: plans.length,
          error: null,
        );
        state = newState;
        _logger.debug('✅ State updated: ${state.plans.length} plans, hasMore: ${state.hasMore}');
      } else {
        _logger.debug('⚠️ Not mounted, skipping state update');
      }
    } catch (e) {
      _logger.error('❌ Error loading plans: $e');
      if (mounted) {
        _logger.debug('📊 Setting error state');
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }

    _logger.debug('🏁 loadInitial() finished - final state: ${state.plans.length} plans, isLoading: ${state.isLoading}');
  }

  /// Load more plans
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final newPlans = await repository.getPlans(
        language: languageCode,
        skip: state.skip,
        limit: _limit,
      );

      if (mounted) {
        final planEntities = newPlans.map((model) => model.toEntity()).toList();
        state = state.copyWith(
          plans: [...state.plans, ...planEntities],
          isLoadingMore: false,
          hasMore: newPlans.length >= _limit,
          skip: state.skip + newPlans.length,
          error: null,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoadingMore: false, error: e.toString());
      }
    }
  }

  /// Retry loading
  void retry() {
    if (state.plans.isEmpty) {
      loadInitial();
    } else {
      loadMore();
    }
  }

  /// Refresh from start
  Future<void> refresh() async {
    state = const FindPlansState();
    await loadInitial();
  }
}
