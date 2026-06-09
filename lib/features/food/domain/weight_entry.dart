/// One row in the body_weight_logs table.
class WeightEntry {
  final String id;
  final String userId;
  final DateTime date;
  final double kg;
  final String? note;

  const WeightEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.kg,
    this.note,
  });

  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        date: DateTime.parse(j['date'] as String),
        kg: (j['weight_kg'] as num).toDouble(),
        note: j['note'] as String?,
      );

  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'weight_kg': kg,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

enum MeasurementKind { chest, waist, hip, bicep, thigh, neck }

extension MeasurementKindX on MeasurementKind {
  String get db => name;
  String get label => switch (this) {
        MeasurementKind.chest => 'Chest',
        MeasurementKind.waist => 'Waist',
        MeasurementKind.hip   => 'Hip',
        MeasurementKind.bicep => 'Bicep',
        MeasurementKind.thigh => 'Thigh',
        MeasurementKind.neck  => 'Neck',
      };
}

MeasurementKind _parseKind(String s) =>
    MeasurementKind.values.firstWhere((k) => k.name == s,
        orElse: () => MeasurementKind.waist);

class MeasurementEntry {
  final String id;
  final String userId;
  final DateTime date;
  final MeasurementKind kind;
  final double cm;

  const MeasurementEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.kind,
    required this.cm,
  });

  factory MeasurementEntry.fromJson(Map<String, dynamic> j) => MeasurementEntry(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        date: DateTime.parse(j['date'] as String),
        kind: _parseKind(j['kind'] as String),
        cm: (j['cm'] as num).toDouble(),
      );

  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'kind': kind.db,
        'cm': cm,
      };
}
