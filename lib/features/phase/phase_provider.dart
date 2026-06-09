import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dev/dev_mode.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';
import 'phase_config.dart';

/// Latest open phase row from `phase_history`, falls back to the default
/// weights for the user's `current_phase` if no history exists yet.
final activePhaseProvider = FutureProvider<({String name, PhaseWeights weights})>(
  (ref) async {
    if (ref.watch(devModeProvider)) {
      final name = mockUser.currentPhase;
      return (name: name, weights: phaseWeightsFor(name));
    }

    final session = ref.watch(sessionProvider);
    if (session == null) {
      return (name: 'Rehab + Bulk', weights: phaseWeightsFor('Rehab + Bulk'));
    }

    try {
      final row = await SupabaseService.client
          .from('phase_history')
          .select()
          .eq('user_id', session.user.id)
          .filter('ended_at', 'is', null)
          .maybeSingle();

      if (row != null) {
        final name = row['phase_name'] as String;
        final weights = PhaseWeights.fromJson(
            (row['weights'] as Map).cast<String, dynamic>());
        return (name: name, weights: weights);
      }
    } catch (_) {
      // table may not exist yet (migration not applied); fall through.
    }

    final user = await ref.watch(appUserProvider.future);
    final name = user?.currentPhase ?? 'Rehab + Bulk';
    return (name: name, weights: phaseWeightsFor(name));
  },
);

/// Records a phase change: closes any open row, inserts a new one with the
/// default weights for the chosen phase, and invalidates dependent providers.
/// Accepts either a [Ref] (from a provider) or a [WidgetRef] (from a widget).
Future<void> recordPhaseChange(WidgetRef ref, String newPhase) async {
  final session = ref.read(sessionProvider);
  if (session == null) return;
  final uid = session.user.id;
  final weights = phaseWeightsFor(newPhase);

  try {
    await SupabaseService.client
        .from('phase_history')
        .update({'ended_at': DateTime.now().toIso8601String()})
        .eq('user_id', uid)
        .filter('ended_at', 'is', null);

    await SupabaseService.client.from('phase_history').insert({
      'user_id': uid,
      'phase_name': newPhase,
      'weights': weights.toJson(),
    });
  } catch (_) {
    // best-effort; phase still updates on users row.
  }

  ref.invalidate(activePhaseProvider);
}
