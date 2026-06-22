import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/shared/services/quiet_hours.dart';

void main() {
  group('QuietHours.parse', () {
    test('returns null when either bound is missing', () {
      expect(QuietHours.parse(null, '07:00'), isNull);
      expect(QuietHours.parse('22:00', null), isNull);
      expect(QuietHours.parse(null, null), isNull);
    });

    test('returns null for a zero-length window (treated as off)', () {
      expect(QuietHours.parse('22:00', '22:00'), isNull);
    });

    test('returns null for malformed or out-of-range times', () {
      expect(QuietHours.parse('9pm', '7am'), isNull);
      expect(QuietHours.parse('24:00', '07:00'), isNull);
      expect(QuietHours.parse('22:61', '07:00'), isNull);
    });

    test('parses a valid window into minutes-from-midnight', () {
      final q = QuietHours.parse('22:30', '07:00')!;
      expect(q.startMinutes, 22 * 60 + 30);
      expect(q.endMinutes, 7 * 60);
    });
  });

  group('contains', () {
    test('same-day window', () {
      final q = QuietHours.parse('09:00', '17:00')!;
      expect(q.contains(8 * 60), isFalse); // 08:00 before
      expect(q.contains(9 * 60), isTrue); // start inclusive
      expect(q.contains(12 * 60), isTrue);
      expect(q.contains(17 * 60), isFalse); // end exclusive
    });

    test('window wrapping past midnight', () {
      final q = QuietHours.parse('22:00', '07:00')!;
      expect(q.contains(23 * 60), isTrue);
      expect(q.contains(0), isTrue); // midnight
      expect(q.contains(6 * 60 + 59), isTrue);
      expect(q.contains(7 * 60), isFalse); // end exclusive
      expect(q.contains(12 * 60), isFalse); // midday is outside
    });
  });

  group('shift', () {
    test('leaves times outside the window untouched', () {
      final q = QuietHours.parse('22:00', '07:00')!;
      expect(q.shift(8, 0), (8, 0));
      expect(q.shift(20, 30), (20, 30));
    });

    test('pushes times inside the window to the window end', () {
      final q = QuietHours.parse('22:00', '07:00')!;
      expect(q.shift(23, 15), (7, 0)); // late night -> 07:00
      expect(q.shift(6, 0), (7, 0)); // early morning -> 07:00
    });

    test('handles a same-day window end with non-zero minutes', () {
      final q = QuietHours.parse('13:00', '14:30')!;
      expect(q.shift(13, 45), (14, 30));
      expect(q.shift(15, 0), (15, 0));
    });
  });
}
