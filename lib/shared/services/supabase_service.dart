import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  // Overridable at build time via --dart-define so prod keys never have to
  // live in source. The defaults are the current project's public anon
  // credentials (RLS is the real gate), so existing builds keep working.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wtiejjohcjoukjqkpgim.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0aWVqam9oY2pvdWtqcWtwZ2ltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3MDUyMDAsImV4cCI6MjA5MzI4MTIwMH0.gxxxKZJeLqP-NB0tolD1DBWI-kNI3cTWCCbkOOcp01w',
  );

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
