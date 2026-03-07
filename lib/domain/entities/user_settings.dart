class UserSettings {
  final String userId;
  final bool inAppNotifications;
  final bool emailNotifications;
  final String themeMode;
  final String languageCode;

  const UserSettings({
    required this.userId,
    required this.inAppNotifications,
    required this.emailNotifications,
    required this.themeMode,
    required this.languageCode,
  });
}
