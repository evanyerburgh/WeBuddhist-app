import 'package:flutter_pecha/features/plans/domain/entities/plan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/features/plans/presentation/providers/plans_providers.dart';

final plansByTagProvider = FutureProvider.family<List<Plan>, String>((ref, tag) async {
  final locale = ref.watch(localeProvider);
  final languageCode = locale.languageCode;
  final plansModels = await ref
      .watch(plansRepositoryProvider)
      .getPlans(language: languageCode, tag: tag);
  return plansModels.map((model) => model.toEntity()).toList();
});
