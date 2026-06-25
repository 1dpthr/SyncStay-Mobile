/// Supabase credentials — Dashboard → Project Settings → API
class SupabaseConfig {
  /// Base project URL only (NOT /rest/v1/)
  static const url = 'https://hvqhqrxjiimxaqnpldom.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh2cWhxcnhqaWlteGFxbnBsZG9tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0MTE1ODEsImV4cCI6MjA5NTk4NzU4MX0.qDiZpyHcsviXwgu0hNxZV-BvrdHgvGZ3xM1CWyMjS8A';

  static bool get isConfigured =>
      url.startsWith('https://') && !url.contains('YOUR_') && !anonKey.contains('YOUR_');
}
