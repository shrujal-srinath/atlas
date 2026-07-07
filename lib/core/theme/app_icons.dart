import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Registry of habit icons. Keys are stable strings stored in `habit.icon`.
/// Anything not in the registry (e.g. legacy emoji rows) falls back to
/// [defaultHabitIcon] so existing data keeps rendering cleanly.
const Map<String, IconData> kHabitIcons = {
  // Athletic
  'run':         LucideIcons.footprints,
  'bike':        LucideIcons.bike,
  'dumbbell':    LucideIcons.dumbbell,
  'yoga':        LucideIcons.flower2,
  'swim':        LucideIcons.waves,
  'walk':        LucideIcons.move,
  'snowflake':   LucideIcons.snowflake,
  'heart-pulse': LucideIcons.heartPulse,
  'target':      LucideIcons.target,
  'stretch':     LucideIcons.activity,

  // Building / mind
  'book':        LucideIcons.bookOpen,
  'code':        LucideIcons.code2,
  'pen':         LucideIcons.edit3,
  'brain':       LucideIcons.brain,
  'guitar':      LucideIcons.music2,
  'palette':     LucideIcons.palette,
  'compass':     LucideIcons.compass,
  'leaf':        LucideIcons.leaf,

  // Health / care
  'pill':        LucideIcons.pill,
  'stethoscope': LucideIcons.stethoscope,
  'bandage':     LucideIcons.cross,
  'droplet':     LucideIcons.droplet,
  'bed':         LucideIcons.bed,
  'salad':       LucideIcons.salad,
  'apple':       LucideIcons.apple,
  'egg':         LucideIcons.egg,

  // Breaking
  'pizza':       LucideIcons.pizza,
  'cigarette':   LucideIcons.cigarette,
  'beer':        LucideIcons.beer,
  'phone':       LucideIcons.smartphone,
  'gamepad':     LucideIcons.gamepad2,
  'shopping':    LucideIcons.shoppingCart,
  'cloud-rain':  LucideIcons.cloudRain,
  'flame':       LucideIcons.flame,
  'zap':         LucideIcons.zap,
};

const IconData defaultHabitIcon = LucideIcons.circleDot;

IconData habitIcon(String? key) {
  if (key == null) return defaultHabitIcon;
  return kHabitIcons[key] ?? defaultHabitIcon;
}

/// Ordered list for the picker UI.
const List<String> kHabitIconOrder = [
  'run','bike','dumbbell','yoga','swim','walk','snowflake','heart-pulse','target','stretch',
  'book','code','pen','brain','guitar','palette','compass','leaf',
  'pill','stethoscope','bandage','droplet','bed','salad','apple','egg',
  'pizza','cigarette','beer','phone','gamepad','shopping','cloud-rain','flame','zap',
];

/// Icon categories used by the habit-creation picker tabs. Display labels —
/// keep them aligned with the current section/type taxonomy (Building/Breaking
/// were retired 2026-06-26; "Break" matches the habit-type pill).
const Map<String, List<String>> kHabitIconCategories = {
  'Athletic': [
    'run','bike','dumbbell','yoga','swim','walk','snowflake','heart-pulse','target','stretch',
  ],
  'Mind': [
    'book','code','pen','brain','guitar','palette','compass','leaf',
  ],
  'Health': [
    'pill','stethoscope','bandage','droplet','bed','salad','apple','egg',
  ],
  'Break': [
    'pizza','cigarette','beer','phone','gamepad','shopping','cloud-rain','flame','zap',
  ],
};

/// Accent colour swatches (key → hex). Drives the habit card accent.
const Map<String, int> kHabitColorSwatch = {
  'teal':     0xFF2DD4BF,
  'athletic': 0xFF38BDF8,
  'building': 0xFFF5B544,
  'breaking': 0xFFF4564E,
  'indigo':   0xFF818CF8,
  'rose':     0xFFFB7185,
  'lime':     0xFFA3E635,
  'violet':   0xFFC084FC,
};

const List<String> kHabitColorOrder = [
  'teal','athletic','building','breaking','indigo','rose','lime','violet',
];
