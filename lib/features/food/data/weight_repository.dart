import '../../../shared/services/offline_writer.dart';
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
    final inserted = await OfflineWriter.insert(
      table: 'body_weight_logs',
      payload: entry.toInsert(),
    );
    return WeightEntry.fromJson(inserted);
  }

  /// Record [kg] for [date], updating that day's entry if one already exists
  /// (else inserting). Keeps a single point per day so profile/goal weight
  /// edits and Body-tab logs share one timeline without duplicates.
  Future<WeightEntry> upsertForDate({
    required double kg,
    required DateTime date,
    String? note,
  }) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final day = DateTime(date.year, date.month, date.day);
    final ds =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    try {
      final rows = await SupabaseService.client
          .from('body_weight_logs')
          .select('id')
          .eq('date', ds)
          .limit(1);
      final list = (rows as List);
      if (list.isNotEmpty) {
        final id = (list.first as Map)['id'] as String;
        await OfflineWriter.update(
          table: 'body_weight_logs',
          id: id,
          payload: {
            'weight_kg': kg,
            if (note != null && note.isNotEmpty) 'note': note,
          },
        );
        return WeightEntry(
            id: id, userId: userId, date: day, kg: kg, note: note);
      }
    } catch (_) {
      // Offline / lookup failed — fall through to a plain insert.
    }
    return add(kg: kg, date: day, note: note);
  }

  Future<void> delete(String id) async {
    await OfflineWriter.delete(table: 'body_weight_logs', id: id);
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
    final inserted = await OfflineWriter.insert(
      table: 'measurements',
      payload: entry.toInsert(),
    );
    return MeasurementEntry.fromJson(inserted);
  }
}
