/// Achievement catalog — 20 rules per home-master-plan §6.
/// The engine in Sprint 7 evaluates these against user stats; for now the
/// Progression screen just renders the catalog and overlays unlocks from the
/// `user_achievements` table.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AchievementDef {
  final String id;
  final String name;
  final String description;
  final String unlockHint;
  final IconData icon;
  final int xpReward;
  final bool hidden;
  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockHint,
    required this.icon,
    required this.xpReward,
    this.hidden = false,
  });
}

const List<AchievementDef> achievementCatalog = [
  AchievementDef(
    id: 'early_bird',
    name: 'Early Bird',
    description: '14 dawn runs',
    unlockHint: 'Run before 7 AM, 14 days',
    icon: LucideIcons.sunrise,
    xpReward: 100,
  ),
  AchievementDef(
    id: 'zen_mind',
    name: 'Zen Mind',
    description: '30-day meditation',
    unlockHint: 'Meditate 30 days in a row',
    icon: LucideIcons.moon,
    xpReward: 200,
  ),
  AchievementDef(
    id: 'iron_will',
    name: 'Iron Will',
    description: '7 perfect days',
    unlockHint: '7 perfect days in a row',
    icon: LucideIcons.droplet,
    xpReward: 250,
  ),
  AchievementDef(
    id: 'centurion',
    name: 'Centurion',
    description: '100 gym sessions',
    unlockHint: 'Log 100 gym sessions',
    icon: LucideIcons.dumbbell,
    xpReward: 500,
  ),
  AchievementDef(
    id: 'bookworm',
    name: 'Bookworm',
    description: '1,000 pages read',
    unlockHint: 'Read 1,000 pages cumulative',
    icon: LucideIcons.bookOpen,
    xpReward: 300,
  ),
  AchievementDef(
    id: 'unbroken',
    name: 'Unbroken',
    description: '30d no missed critical',
    unlockHint: '30 days, no missed Critical habit',
    icon: LucideIcons.target,
    xpReward: 300,
  ),
  AchievementDef(
    id: 'first_light',
    name: 'First Light',
    description: 'Log your first habit',
    unlockHint: 'Complete any habit',
    icon: LucideIcons.sparkles,
    xpReward: 25,
  ),
  AchievementDef(
    id: 'trifecta',
    name: 'Trifecta',
    description: '100% all sections, same day',
    unlockHint: 'Hit 100% Athletic + Mind + Body in one day',
    icon: LucideIcons.layers,
    xpReward: 150,
  ),
  AchievementDef(
    id: 'hydromancer',
    name: 'Hydromancer',
    description: '14 days water target',
    unlockHint: 'Hit water target 14 days in a row',
    icon: LucideIcons.droplets,
    xpReward: 150,
  ),
  AchievementDef(
    id: 'macro_boss',
    name: 'Macro Boss',
    description: '30 days protein target',
    unlockHint: 'Hit protein target 30 days in a row',
    icon: LucideIcons.beef,
    xpReward: 200,
  ),
  AchievementDef(
    id: 'marathon_mind',
    name: 'Marathon Mind',
    description: '200 km cumulative',
    unlockHint: 'Run 200 km cumulative',
    icon: LucideIcons.footprints,
    xpReward: 400,
  ),
  AchievementDef(
    id: 'iron_lift',
    name: 'Iron Lift',
    description: '10,000 kg cumulative',
    unlockHint: 'Log 10,000 kg cumulative volume',
    icon: LucideIcons.dumbbell,
    xpReward: 400,
  ),
  AchievementDef(
    id: 'streakzilla',
    name: 'Streakzilla',
    description: '60-day streak',
    unlockHint: '60-day streak on any habit',
    icon: LucideIcons.flame,
    xpReward: 500,
  ),
  AchievementDef(
    id: 'reflector',
    name: 'Reflector',
    description: '30 journal entries',
    unlockHint: 'Submit 30 journal entries',
    icon: LucideIcons.edit3,
    xpReward: 200,
  ),
  AchievementDef(
    id: 'phoenix',
    name: 'Phoenix',
    description: 'Resume after a break',
    unlockHint: 'Resume after ≥14d broken streak',
    icon: LucideIcons.flame,
    xpReward: 150,
    hidden: true,
  ),
  AchievementDef(
    id: 'night_owl',
    name: 'Night Owl',
    description: '30 evening habits',
    unlockHint: 'Complete an evening habit 30 times',
    icon: LucideIcons.moonStar,
    xpReward: 150,
  ),
  AchievementDef(
    id: 'bowlers_arm',
    name: "Bowler's Arm",
    description: '5,000 deliveries',
    unlockHint: 'Log 5,000 deliveries',
    icon: LucideIcons.zap,
    xpReward: 500,
    hidden: true,
  ),
  AchievementDef(
    id: 'perfectionist',
    name: 'Perfectionist',
    description: '30 perfect days in a month',
    unlockHint: '30 perfect days in a single month',
    icon: LucideIcons.award,
    xpReward: 1000,
    hidden: true,
  ),
  AchievementDef(
    id: 'comeback',
    name: 'Comeback',
    description: 'Recover ≥10 score in a day',
    unlockHint: 'Recover 10 score points in one day',
    icon: LucideIcons.trendingUp,
    xpReward: 100,
    hidden: true,
  ),
  AchievementDef(
    id: 'veteran',
    name: 'Veteran',
    description: '365-day app login',
    unlockHint: '365-day login streak',
    icon: LucideIcons.trophy,
    xpReward: 1500,
    hidden: true,
  ),

  // ── Streak tiers (any habit). Stack with `streakzilla` (60d).
  AchievementDef(
    id: 'streak_3',
    name: 'Three in a Row',
    description: '3-day streak',
    unlockHint: '3-day streak on any habit',
    icon: LucideIcons.flame,
    xpReward: 30,
  ),
  AchievementDef(
    id: 'streak_7',
    name: 'Week One',
    description: '7-day streak',
    unlockHint: '7-day streak on any habit',
    icon: LucideIcons.flame,
    xpReward: 75,
  ),
  AchievementDef(
    id: 'streak_30',
    name: 'Lock-In',
    description: '30-day streak',
    unlockHint: '30-day streak on any habit',
    icon: LucideIcons.flame,
    xpReward: 250,
  ),
  AchievementDef(
    id: 'streak_100',
    name: 'Centurion Streak',
    description: '100-day streak',
    unlockHint: '100-day streak on any habit',
    icon: LucideIcons.flame,
    xpReward: 1000,
    hidden: true,
  ),

  // ── Level milestones.
  AchievementDef(
    id: 'level_5',
    name: 'Apprentice',
    description: 'Reach Level 5',
    unlockHint: 'Reach Level 5',
    icon: LucideIcons.star,
    xpReward: 100,
  ),
  AchievementDef(
    id: 'level_10',
    name: 'Specialist',
    description: 'Reach Level 10',
    unlockHint: 'Reach Level 10',
    icon: LucideIcons.star,
    xpReward: 200,
  ),
  AchievementDef(
    id: 'level_20',
    name: 'Master',
    description: 'Reach Level 20',
    unlockHint: 'Reach Level 20',
    icon: LucideIcons.crown,
    xpReward: 500,
    hidden: true,
  ),

  // ── Architect (number of active habits).
  AchievementDef(
    id: 'architect_5',
    name: 'Architect',
    description: '5 habits running',
    unlockHint: 'Have 5 active habits',
    icon: LucideIcons.layoutDashboard,
    xpReward: 50,
  ),
  AchievementDef(
    id: 'architect_10',
    name: 'Composer',
    description: '10 habits running',
    unlockHint: 'Have 10 active habits',
    icon: LucideIcons.layoutDashboard,
    xpReward: 100,
  ),
  AchievementDef(
    id: 'architect_25',
    name: 'System Builder',
    description: '25 habits running',
    unlockHint: 'Have 25 active habits',
    icon: LucideIcons.layoutDashboard,
    xpReward: 250,
    hidden: true,
  ),
];
