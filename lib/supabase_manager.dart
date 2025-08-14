import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseManager {
  static final SupabaseClient client = Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: 'https://lhsnchyeaxvhbkrpsbds.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxoc25jaHllYXh2aGJrcnBzYmRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1OTY3MTksImV4cCI6MjA1NzE3MjcxOX0.7BB6uXH_4BpEaZoWv97ex-fuFPmPxI5C8mh-PDsYmTA',
    );
  }
}
