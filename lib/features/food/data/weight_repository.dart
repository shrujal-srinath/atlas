import '../../../shared/services/supabase_service.dart';
import '../domain/weight_entry.dart';

/// Reads/writes body weight + circumference measurements.
class WeightRepository {
  Future<List<WeightEntry>> last({int days = 90}) async {
    final start = DateTime.now().subtract(Duration(days: days));
    final ds =
        '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final rows = await SupabaseService.client
        .from('body_weight_logs')
        .select()
        .gte('date', ds)
        .order('date');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(WeightEntry.fromJson)
        .toList();
  }

  Future<WeightEntry> add({
    required double kg,
    DateTime? date,
    String? note,
  }) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final d = date ?? DateTime.now();
    final entry = WeightEntry(
      id: '', userId: userId,
      date: DateTime(d.year, d.month, d.day),
      kg: kg, note: note,
    );
    final inserted = await SupabaseService.client
        .from('body_weight_logs')
        .insert(entry.toInsert())
        .select()
        .single();
    return WeightEntry.fromJson(inserted);
  }

  Future<void> delete(String id) async {
    await SupabaseService.client.from('body_weight_logs').delete().eq('id', id);
  }

  Future<List<MeasurementEntry>> latestMeasurements() async {
    // Return the most-recent value per kind.
    final rows = await SupabaseService.client
        .from('measurements')
        .select()
        .order('date', ascending: false)
        .limit(60);
    final seen = <MeasurementKind, MeasurementEntry>{};
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final e = MeasurementEntry.fromJson(r);
      seen.putIfAbsent(e.kind, () => e);
    }
    return seen.values.toList();
  }

  Future<MeasurementEntry> addMeasurement({
    required MeasurementKind kind,
    required double cm,
    DateTime? date,
  }) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final d = date ?? DateTime.now();
    final entry = MeasurementEntry(
      id: '', userId: userId,
      date: DateTime(d.year, d.month, d.day),
      kind: kind, cm: cm,
    );
    final inserted = await SupabaseService.client
        .from('measurements')
        .insert(entry.toInsert())
        .select()
        .single();
    return MeasurementEntry.fromJson(inserted);
  }
}
