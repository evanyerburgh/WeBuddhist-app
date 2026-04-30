import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/plans/presentation/providers/plan_days_providers.dart';
import 'package:flutter_pecha/features/plans/presentation/providers/user_plans_provider.dart';
import 'package:flutter_pecha/features/reader/data/models/navigation_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _logger = AppLogger('PlanSubtaskCompletion');

/// Marks the current subtask in [navigationContext] as complete and
/// invalidates the providers feeding the plan day screen so the UI refreshes
/// when the user returns.
///
/// No-ops in any of the following situations (preview or out-of-bounds):
/// - source is not [NavigationSource.plan]
/// - the current item has no `subtaskId` (preview mode)
/// - the subtask is already completed
/// - the index is out of bounds
///
/// Centralised here so both `ReaderScreen`'s swipe wrapper and
/// `PlanTextScreen`'s bottom bar share identical completion behaviour.
void completeCurrentPlanSubtask(WidgetRef ref, NavigationContext? navContext) {
  if (navContext == null || navContext.source != NavigationSource.plan) {
    return;
  }

  final currentItem = navContext.currentItem;
  if (currentItem == null) return;

  final subtaskId = currentItem.subtaskId;
  if (subtaskId == null || subtaskId.isEmpty) return;
  if (currentItem.isCompleted) return;

  final planId = navContext.planId;
  final dayNumber = navContext.dayNumber;

  Future.microtask(() async {
    try {
      final result = await ref.read(
        completeSubTaskFutureProvider(subtaskId).future,
      );
      result.fold(
        (failure) =>
            _logger.error('Failed to complete subtask: ${failure.message}'),
        (_) {
          _logger.info('Marked subtask $subtaskId as complete on navigation');
          if (planId != null && dayNumber != null) {
            ref.invalidate(
              userPlanDayContentFutureProvider(
                PlanDaysParams(planId: planId, dayNumber: dayNumber),
              ),
            );
            ref.invalidate(userPlanDaysCompletionStatusProvider(planId));
          }
        },
      );
    } catch (e) {
      _logger.error('Failed to complete subtask $subtaskId', e);
    }
  });
}
