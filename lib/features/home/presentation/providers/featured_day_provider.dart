import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/features/plans/data/models/response/featured_day_response.dart';
import 'package:flutter_pecha/features/home/domain/usecases/get_featured_day_usecase.dart';
import 'package:flutter_pecha/features/home/presentation/providers/use_case_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Featured day tasks provider - returns List<FeaturedDayTask>
// Watches localeProvider to refresh when language changes
//
// This provider uses the GetFeaturedDayUseCase to fetch featured day content,
// maintaining clean architecture by routing through the use case layer.
final featuredDayFutureProvider = FutureProvider<List<FeaturedDayTask>>((
  ref,
) async {
  final locale = ref.watch(localeProvider);
  final repository = ref.watch(featuredDayDomainRepositoryProvider);
  final useCase = ref.watch(getFeaturedDayUseCaseProvider);

  final result = await useCase(GetFeaturedDayParams(language: locale.languageCode));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (response) {
      if (response.tasks.isEmpty) {
        return [];
      } else {
        return repository.mapToFeaturedDayTasks(response);
      }
    },
  );
});
