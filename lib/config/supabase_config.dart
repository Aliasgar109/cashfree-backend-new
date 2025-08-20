import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration for TV Subscription Payment App
class SupabaseConfig {
  // Supabase project credentials
  static const String supabaseUrl = 'https://lqplvvcabvqisxowmsrw.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxxcGx2dmNhYnZxaXN4b3dtc3J3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0MzI3MDYsImV4cCI6MjA3MTAwODcwNn0.JaT4iAfdPZsdd93pO-0WBZwln9bQewixBws9OiEmmoU';
  
  // Service role key for admin operations (bypasses RLS)
  // ⚠️ NEVER expose this in client apps! Only use server-side or for admin operations
  static const String supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxxcGx2dmNhYnZxaXN4b3dtc3J3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTQzMjcwNiwiZXhwIjoyMDcxMDA4NzA2fQ.5kSQ2B96Qx9ulxgFx4DX8orAfJHff3yiddUCwA4wsS4';
  
  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Set to false in production
    );
  }
  
  /// Get Supabase client instance (normal user operations)
  static SupabaseClient get client => Supabase.instance.client;
  
  /// Get Supabase admin client (bypasses RLS for admin operations)
  static SupabaseClient get adminClient => SupabaseClient(
    supabaseUrl, 
    supabaseServiceKey,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
    ),
  );
  
  /// Database table names
  static const String usersTable = 'users';
  static const String paymentsTable = 'payments';
  static const String walletTransactionsTable = 'wallet_transactions';
  static const String settingsTable = 'settings';
  static const String receiptsTable = 'receipts';
  static const String notificationsTable = 'notifications';
  
  /// Storage bucket names
  static const String receiptsBucket = 'receipts';
  static const String documentsBucket = 'documents';
}