/// SmartDoz - Bildirim Modeli (Missed Dose ve diğer tipler)
class MissedDoseNotification {
  final int id;
  final int userId;
  final String userName;
  final int caregiverId;
  final int? doseLogId;
  final int? medicationId;
  final String medicationName;
  final String notificationType; // MISSED_DOSE, OVERDOSE, EXPIRY, etc
  final String title;
  final String message;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  MissedDoseNotification({
    required this.id,
    required this.userId,
    required this.userName,
    required this.caregiverId,
    required this.doseLogId,
    required this.medicationId,
    required this.medicationName,
    required this.notificationType,
    required this.title,
    required this.message,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
  });

  factory MissedDoseNotification.fromJson(Map<String, dynamic> json) {
    return MissedDoseNotification(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      userName: json['user_name'] as String? ?? '',
      caregiverId: json['caregiver_id'] as int,
      doseLogId: json['dose_log_id'] as int?,
      medicationId: json['medication_id'] as int?,
      medicationName: json['medication_name'] as String? ?? '',
      notificationType: json['notification_type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationList {
  final int total;
  final int unreadCount;
  final List<MissedDoseNotification> notifications;

  NotificationList({
    required this.total,
    required this.unreadCount,
    required this.notifications,
  });

  factory NotificationList.fromJson(Map<String, dynamic> json) {
    final notifList = (json['notifications'] as List<dynamic>?)
        ?.map((e) => MissedDoseNotification.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    return NotificationList(
      total: json['total'] as int? ?? 0,
      unreadCount: json['unread_count'] as int? ?? 0,
      notifications: notifList,
    );
  }
}
