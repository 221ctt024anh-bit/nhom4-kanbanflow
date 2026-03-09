import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class SupabaseNotificationListener {
  static RealtimeChannel? _channel;

  static void start(String userId) {
    if (_channel != null) {
      stop();
    }

    _channel = Supabase.instance.client
        .channel('public:user_notifications:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            final title = data['title'] ?? 'Thông báo mới';
            final message =
                data['message'] ?? 'Bạn có một thông báo mới từ TaskMate';

            NotificationService.showNotification(title: title, body: message);
          },
        );

    _channel?.subscribe();
  }

  static void stop() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
