import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FoodSubTab { diary, body, insights }

/// Persists the last-selected sub-tab inside the Food shell across rebuilds
/// and bottom-nav switches.
final foodSubTabProvider = StateProvider<FoodSubTab>((_) => FoodSubTab.diary);
