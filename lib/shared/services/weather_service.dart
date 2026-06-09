import 'dart:convert';

import 'package:http/http.dart' as http;

/// Open-Meteo wrapper. No API key needed; the free endpoint returns hourly
/// precipitation + probability for any lat/lon.
///
/// We default to Bangalore (12.97, 77.59) — wire a real location later when
/// settings expose lat/lon. The whole service is best-effort: a network or
/// schema error returns an empty forecast so callers can fall back gracefully.
class WeatherService {
  static const double defaultLat = 12.97;
  static const double defaultLon = 77.59;

  static const _base = 'https://api.open-meteo.com/v1/forecast';

  Future<HourlyForecast> next6Hours({
    double lat = defaultLat,
    double lon = defaultLon,
  }) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'hourly': 'precipitation,precipitation_probability',
      'forecast_days': '1',
      'timezone': 'auto',
    });

    try {
      final res =
          await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return HourlyForecast.empty;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final hourly = body['hourly'] as Map<String, dynamic>?;
      if (hourly == null) return HourlyForecast.empty;
      final times = (hourly['time'] as List?)?.cast<String>() ?? const [];
      final precip = (hourly['precipitation'] as List?)?.cast<num>() ?? const [];
      final prob = (hourly['precipitation_probability'] as List?)?.cast<num>() ??
          const [];

      // Slice to the next 6 hours, starting from now.
      final now = DateTime.now();
      final slots = <ForecastSlot>[];
      for (int i = 0; i < times.length && slots.length < 6; i++) {
        final t = DateTime.tryParse(times[i]);
        if (t == null) continue;
        if (t.isBefore(now.subtract(const Duration(minutes: 30)))) continue;
        slots.add(ForecastSlot(
          time: t,
          precipitationMm: i < precip.length ? precip[i].toDouble() : 0,
          precipitationProb: i < prob.length ? prob[i].toInt() : 0,
        ));
      }
      return HourlyForecast(slots: slots);
    } catch (_) {
      return HourlyForecast.empty;
    }
  }
}

class HourlyForecast {
  final List<ForecastSlot> slots;
  const HourlyForecast({required this.slots});

  static const HourlyForecast empty = HourlyForecast(slots: []);

  /// True when ANY of the next [windowHours] hourly slots has measurable
  /// precipitation OR a probability >= [probabilityThreshold]%.
  bool rainExpectedWithin({
    int windowHours = 2,
    double mmThreshold = 0.2,
    int probabilityThreshold = 55,
  }) {
    final window = slots.take(windowHours);
    for (final s in window) {
      if (s.precipitationMm >= mmThreshold) return true;
      if (s.precipitationProb >= probabilityThreshold) return true;
    }
    return false;
  }
}

class ForecastSlot {
  final DateTime time;
  final double precipitationMm;
  final int precipitationProb;
  const ForecastSlot({
    required this.time,
    required this.precipitationMm,
    required this.precipitationProb,
  });
}
