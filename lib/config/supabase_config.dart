import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase configuration for TV Subscription Payment App
class SupabaseConfig {
  // Supabase project credentials from environment variables
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? 'https://rsaylanpqnenfecsevoj.supabase.co';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJzYXlsYW5wcW5lbmZlY3Nldm9qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU4NjgwMzQsImV4cCI6MjA3MTQ0NDAzNH0.20znyBUCdLBifOrFsAEMe_SU3d2C_BFjE7vjtCLdFHs';
  
  // Service role key for admin operations (bypasses RLS)
  // ⚠️ NEVER expose this in client apps! Only use server-side or for admin operations
  static String get supabaseServiceKey => dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJzYXlsYW5wcW5lbmZlY3Nldm9qIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTg2ODAzNCwiZXhwIjoyMDcxNDQ0MDM0fQ.uqT2vjCeDMl1kLSZ8V6dQdS5MGiV6e3TICLw7OtJK-k';
  
  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: dotenv.env['DEBUG_MODE'] == 'true', // Set to false in production
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