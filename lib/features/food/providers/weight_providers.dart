import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/weight_repository.dart';
import '../domain/weight_entry.dart';

final weightRepositoryProvider =
    Provider<WeightRepository>((_) => WeightRepository());

/// Record a weight edit made in the profile/goal editor as today's point on the
/// weight-history timeline, so the Body-tab graph stays in sync with the
/// profile weight (which drives the calorie engine). Best-effort — a failed
/// history write never blocks the profile save. The caller is responsible for
/// writing `users.weight_kg` itself (the engine's canonical input).
Future<void> recordWeightHistoryPoint(WidgetRef ref, double kg) async {
  try {
    await ref.read(weightRepositoryProvider).upsertForDate(
          kg: kg,
          date: DateTime.now(),
        );
    ref.invalidate(weightLogProvider);
  } catch (_) {
    // History point is non-critical; ignore failures.
  }
}

/// Last 90 days of weight logs, oldest → newest.
final weightLogProvider =
    FutureProvider.autoDispose<List<WeightEntry>>((ref) async {
  final repo = ref.watch(weightRepositoryProvider);
  return repo.last(days: 90);
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
