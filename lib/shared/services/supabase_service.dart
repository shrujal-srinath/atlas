import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  static const supabaseUrl = 'https://wtiejjohcjoukjqkpgim.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0aWVqam9oY2pvdWtqcWtwZ2ltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3MDUyMDAsImV4cCI6MjA5MzI4MTIwMH0.gxxxKZJeLqP-NB0tolD1DBWI-kNI3cTWCCbkOOcp01w';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
