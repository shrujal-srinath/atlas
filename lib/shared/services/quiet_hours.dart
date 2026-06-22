/// Quiet-hours (Do-Not-Disturb) window for local notifications.
///
/// Pure value type — no Flutter/plugin imports — so the policy is unit-testable
/// in isolation. Parsed from the user's `quiet_hours_start` / `quiet_hours_end`
/// `HH:mm` columns. When either side is missing (or the window is zero-length)
/// the window is "off" and [QuietHours.parse] returns null, leaving every
/// scheduled time untouched.
///
/// Semantics: any notification whose fire time lands inside the window is
/// pushed forward to the window's end (`endMinutes`). Windows that wrap past
/// midnight (e.g. 22:00 → 07:00) are handled.
class QuietHours {
  /// Minutes-from-midnight the window opens (inclusive).
  final int startMinutes;

  /// Minutes-from-midnight the window closes (exclusive).
  final int endMinutes;

  const QuietHours(this.startMinutes, this.endMinutes);

  /// Parses two `HH:mm` strings. Returns null when the window is unset or
  /// zero-length (treated as "off").
  static QuietHours? parse(String? start, String? end) {
    final s = _parseHHmm(start);
    final e = _parseHHmm(end);
    if (s == null || e == null) return null;
    if (s == e) return null; // zero-length window = disabled
    return QuietHours(s, e);
  }

  /// True when [minutesOfDay] (0..1439) falls inside the quiet window.
  bool contains(int minutesOfDay) {
    if (startMinutes < endMinutes) {
      return minutesOfDay >= startMinutes && minutesOfDay < endMinutes;
    }
    // Wraps midnight: inside if after start OR before end.
    return minutesOfDay >= startMinutes || minutesOfDay < endMinutes;
  }

  /// Shifts an `(hour, minute)` out of the quiet window to its end. Times that
  /// already sit outside the window are returned unchanged.
  (int hour, int minute) shift(int hour, int minute) {
    final m = hour * 60 + minute;
    if (!contains(m)) return (hour, minute);
    return (endMinutes ~/ 60, endMinutes % 60);
  }

  static int? _parseHHmm(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  @override
  bool operator ==(Object other) =>
      other is QuietHours &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(startMinutes, endMinutes);
}
