import 'package:flutter/widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';

/// A scoring section the user can configure. The three built-ins
/// (`athletic`/`mind`/`body`) are permanent — they anchor the nutrition blend
/// (Body) and skills (Mind) and match every existing `habits.section` value —
/// but they're renameable/recolourable. Users may add extra custom sections.
///
/// Sections are DATA (stored in the Focus blob), not a fixed enum, so the score
/// engine, stats and habit assignment all iterate the user's actual list.
class SectionDef {
  final String id;
  final String name;
  final String colorKey;
  final int order;
  final bool builtIn;

  /// For a custom section, the built-in section id it rolls up to for scoring
  /// (so its habits count toward that core section's weight). Built-ins parent
  /// themselves.
  final String parent;

  const SectionDef({
    required this.id,
    required this.name,
    required this.colorKey,
    required this.order,
    required this.builtIn,
    required this.parent,
  });

  SectionDef copyWith({
    String? name,
    String? colorKey,
    int? order,
    String? parent,
  }) =>
      SectionDef(
        id: id,
        name: name ?? this.name,
        colorKey: colorKey ?? this.colorKey,
        order: order ?? this.order,
        builtIn: builtIn,
        parent: parent ?? this.parent,
      );

  factory SectionDef.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final rawName = (j['name'] as String?)?.trim();
    final builtIn = j['builtIn'] as bool? ?? kBuiltInSectionIds.contains(id);
    return SectionDef(
      id: id,
      name: (rawName != null && rawName.isNotEmpty) ? rawName : id,
      colorKey: j['color'] as String? ?? 'slate',
      order: (j['order'] as num?)?.toInt() ?? 0,
      builtIn: builtIn,
      parent: builtIn ? id : (j['parent'] as String? ?? kAthleticId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorKey,
        'order': order,
        'builtIn': builtIn,
        'parent': parent,
      };
}

/// The default registry — the three built-ins.
List<SectionDef> defaultSections() => const [
      SectionDef(
          id: kAthleticId,
          name: 'Athletic',
          colorKey: kAthleticId,
          order: 0,
          builtIn: true,
          parent: kAthleticId),
      SectionDef(
          id: kMindId,
          name: 'Mind',
          colorKey: kMindId,
          order: 1,
          builtIn: true,
          parent: kMindId),
      SectionDef(
          id: kBodyId,
          name: 'Body',
          colorKey: kBodyId,
          order: 2,
          builtIn: true,
          parent: kBodyId),
    ];

/// Colour palette for custom sections (built-ins use the theme's section
/// colours via [sectionColorForKey]).
const Map<String, Color> _kCustomSectionColors = {
  'violet': Color(0xFF7C5CFC),
  'teal': Color(0xFF0FB5A6),
  'amber': Color(0xFFE0A02E),
  'rose': Color(0xFFE0568A),
  'sky': Color(0xFF3B9BE0),
  'lime': Color(0xFF6FA82E),
  'slate': Color(0xFF6B7280),
};

/// Colour-key choices offered for a custom section.
List<String> get kCustomSectionColorKeys => _kCustomSectionColors.keys.toList();

/// Resolve a section colour key to a colour. Built-in keys use the theme so
/// they track light/dark; custom keys use the fixed palette above.
Color sectionColorForKey(AppPalette c, String key) => switch (key) {
      kAthleticId => HabitSection.athletic.color(c),
      kMindId => HabitSection.mind.color(c),
      kBodyId => HabitSection.body.color(c),
      _ => _kCustomSectionColors[key] ?? _kCustomSectionColors['slate']!,
    };

/// Ergonomic helpers on a section id (the value of `habit.sectionId`).
extension SectionIdX on String {
  /// Colour for this section id (built-in via theme, custom via palette).
  Color sectionColor(AppPalette c) => sectionColorForKey(c, this);

  /// Display name for this section id (honours renames + custom names).
  String get sectionName => sectionNameOf(this);
}
