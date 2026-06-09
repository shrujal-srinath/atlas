import '../../../shared/services/supabase_service.dart';
import '../domain/journal_entry.dart';

class JournalRepository {
  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<JournalEntry?> getForDate(DateTime date) async {
    final row = await SupabaseService.client
        .from('daily_journal')
        .select()
        .eq('date', _dateStr(date))
        .maybeSingle();
    if (row == null) return null;
    return JournalEntry.fromJson(row);
  }

  /// Upsert keyed by (user_id, date). Returns the persisted entry.
  Future<JournalEntry> upsert(JournalEntry entry) async {
    final row = await SupabaseService.client
        .from('daily_journal')
        .upsert(entry.toUpsert(), onConflict: 'user_id,date')
        .select()
        .single();
    return JournalEntry.fromJson(row);
  }

  /// Entries between [start] and [end] inclusive, ordered by date asc.
  Future<List<JournalEntry>> range(DateTime start, DateTime end) async {
    final rows = await SupabaseService.client
        .from('daily_journal')
        .select()
        .gte('date', _dateStr(start))
        .lte('date', _dateStr(end))
        .order('date');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(JournalEntry.fromJson)
        .toList();
  }
}
