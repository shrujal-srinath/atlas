import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/stats/stats_baseline.dart';

void main() {
  group('computeScoreBaseline', () {
    test('empty series → no data', () {
      final b = computeScoreBaseline(const []);
      expect(b.recentAvg, 0);
      expect(b.baselineAvg, 0);
      expect(b.hasData, false);
    });

    test('flat series → 0% delta, marked up, has data', () {
      final b = computeScoreBaseline(List.filled(30, 80));
      expect(b.recentAvg, 80);
      expect(b.baselineAvg, 80);
      expect(b.deltaPct, 0);
      expect(b.isUp, true);
      expect(b.hasData, true);
    });

    test('recent above baseline → positive delta', () {
      final scores = [...List.filled(23, 60), ...List.filled(7, 90)];
      final b = computeScoreBaseline(scores, recentWindow: 7);
      expect(b.recentAvg, 90);
      expect(b.baselineAvg.round(), 67); // (23*60 + 7*90)/30
      expect(b.isUp, true);
      expect(b.deltaPct, greaterThan(0));
    });

    test('recent below baseline → negative delta', () {
      final scores = [...List.filled(23, 80), ...List.filled(7, 40)];
      final b = computeScoreBaseline(scores, recentWindow: 7);
      expect(b.recentAvg, 40);
      expect(b.isUp, false);
      expect(b.deltaPct, lessThan(0));
    });

    test('rest days (0) are excluded from the means', () {
      final b = computeScoreBaseline(const [100, 0, 50], recentWindow: 3);
      expect(b.recentAvg, 75); // (100 + 50) / 2, the 0 skipped
      expect(b.recentDays, 2);
    });

    test('hasData requires enough scored days on both sides', () {
      final b = computeScoreBaseline(const [80, 0, 0, 80], recentWindow: 4);
      expect(b.recentDays, 2); // only 2 non-zero
      expect(b.hasData, false);
    });
  });
}
