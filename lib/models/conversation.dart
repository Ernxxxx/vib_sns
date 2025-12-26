import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  Conversation({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCounts = const {},
    this.pinnedBy = const {},
    this.mutedBy = const {},
  });

  final String id;
  final List<String> participantIds;
  String? lastMessage;
  DateTime? lastMessageAt;
  Map<String, int> unreadCounts;
  Map<String, bool> pinnedBy; // userId -> isPinned
  Map<String, bool> mutedBy; // userId -> isMuted

  /// Get the other participant's ID given the current user's ID
  String getOtherParticipantId(String currentUserId) {
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  /// Get unread count for a specific user
  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  /// Check if pinned for a specific user
  bool isPinnedFor(String userId) {
    return pinnedBy[userId] ?? false;
  }

  /// Check if muted for a specific user
  bool isMutedFor(String userId) {
    return mutedBy[userId] ?? false;
  }

  factory Conversation.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawUnread = map['unreadCounts'];
    Map<String, int> unreadCounts = {};
    if (rawUnread is Map) {
      unreadCounts = rawUnread.map(
        (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
      );
    }

    final rawPinned = map['pinnedBy'];
    Map<String, bool> pinnedBy = {};
    if (rawPinned is Map) {
      pinnedBy = rawPinned.map(
        (key, value) => MapEntry(key.toString(), value == true),
      );
    }

    final rawMuted = map['mutedBy'];
    Map<String, bool> mutedBy = {};
    if (rawMuted is Map) {
      mutedBy = rawMuted.map(
        (key, value) => MapEntry(key.toString(), value == true),
      );
    }

    return Conversation(
      id: docId ?? map['id'] as String? ?? '',
      participantIds: List<String>.from(map['participantIds'] ?? []),
      lastMessage: map['lastMessage'] as String?,
      lastMessageAt: _parseDateTime(map['lastMessageAt']),
      unreadCounts: unreadCounts,
      pinnedBy: pinnedBy,
      mutedBy: mutedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'unreadCounts': unreadCounts,
      'pinnedBy': pinnedBy,
      'mutedBy': mutedBy,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
