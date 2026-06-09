import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/weight_repository.dart';
import '../domain/weight_entry.dart';

final weightRepositoryProvider =
    Provider<WeightRepository>((_) => WeightRepository());

/// Last 90 days of weight logs, oldest → newest.
final weightLogProvider =
    FutureProvider.autoDispose<List<WeightEntry>>((ref) async {
  final repo = ref.watch(weightRepositoryProvider);
  return repo.last(days: 90);
});

/// Latest weight entry — null if none ever logged.
final latestWeightProvider = Provider.autoDispose<WeightEntry?>((ref) {
  final list = ref.watch(weightLogProvider).valueOrNull ?? const [];
  if (list.isEmpty) return null;
  return list.last;
});

/// Weight delta over [days] vs the most recent entry. Null if not enough data.
final weightDeltaProvider =
    Provider.autoDispose.family<double?, int>((ref, days) {
  final list = ref.watch(weightLogProvider).valueOrNull ?? const [];
  if (list.length < 2) return null;
  final latest = list.last;
  final cutoff = latest.date.subtract(Duration(days: days));
  WeightEntry? base;
  for (final w in list) {
    if (!w.date.isAfter(cutoff)) base = w;
  }
  if (base == null) return null;
  return latest.kg - base.kg;
});

final measurementsProvider =
    FutureProvider.autoDispose<List<MeasurementEntry>>((ref) async {
  final repo = ref.watch(weightRepositoryProvider);
  return repo.latestMeasurements();
});
