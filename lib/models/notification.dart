class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final String? targetUserId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    DateTime? timestamp,
    this.targetUserId,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum NotificationType {
  roomAssigned,
  paymentConfirmed,
  roommateMatched,
  requestReceived,
  info
}
