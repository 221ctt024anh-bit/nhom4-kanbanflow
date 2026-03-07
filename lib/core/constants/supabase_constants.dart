class SupabaseConstants {
  /// The project URL provided by Supabase
  static const String supabaseUrl = 'https://vhxzbhwtkvpyiirmnspr.supabase.co';

  /// The public anon key provided by Supabase
  static const String supabaseAnonKey =
      'sb_publishable_3yS3_jzGxe9gSSU-Al6HUw_rQ-7uOvB';

  /// URL used by Supabase email links to return to this app for password recovery.
  /// Make sure this exact URL is whitelisted in Supabase Auth Redirect URLs.
  static const String resetPasswordRedirectTo = 'taskmate://reset-password';
}
