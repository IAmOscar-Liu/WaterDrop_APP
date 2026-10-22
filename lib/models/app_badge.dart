/// Authoritative, user-scoped snapshot from GET /api/app/badge.
class AppBadge {
  const AppBadge({
    required this.version,
    required this.total,
    required this.claimableUnopenedBoxes,
    required this.unreadNotifications,
    required this.unreadChatMessages,
    this.nextReconcileAt,
  });
  final int version,
      total,
      claimableUnopenedBoxes,
      unreadNotifications,
      unreadChatMessages;
  final DateTime? nextReconcileAt;

  factory AppBadge.fromJson(dynamic value) {
    if (value is! Map) throw const FormatException('Invalid badge snapshot');
    int count(String key, {int minimum = 0}) {
      final n = value[key];
      if (n is! int || n < minimum) throw FormatException('Invalid badge $key');
      return n;
    }

    final version = count('version', minimum: 1);
    final boxes = count('claimableUnopenedBoxes');
    final notifications = count('unreadNotifications');
    final chats = count('unreadChatMessages');
    final total = count('total');
    if (total != boxes + notifications + chats) {
      throw const FormatException('Invalid badge sum');
    }
    if (!value.containsKey('nextReconcileAt')) {
      throw const FormatException('Missing badge deadline');
    }
    final raw = value['nextReconcileAt'];
    final deadline = raw is String ? DateTime.tryParse(raw) : null;
    if (raw != null && (deadline == null || !deadline.isUtc)) {
      throw const FormatException('Invalid badge deadline');
    }
    return AppBadge(
      version: version,
      total: total,
      claimableUnopenedBoxes: boxes,
      unreadNotifications: notifications,
      unreadChatMessages: chats,
      nextReconcileAt: deadline,
    );
  }
}
