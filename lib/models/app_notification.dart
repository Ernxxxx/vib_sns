import 'package:flutter/material.dart';

import 'profile.dart';

enum AppNotificationType { encounter, like, follow, timelineLike }

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.profile,
    this.encounterId,
    this.read = false,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final Profile? profile;
  final String? encounterId;
  bool read;

  IconData get icon {
    switch (type) {
      case AppNotificationType.encounter:
        return Icons.bluetooth_searching;
      case AppNotificationType.like:
        return Icons.favorite;
      case AppNotificationType.follow:
        return Icons.person_add;
      case AppNotificationType.timelineLike:
        return Icons.favorite;
    }
  }

  Color iconColor(ThemeData theme) {
    switch (type) {
      case AppNotificationType.encounter:
        return theme.colorScheme.primary;
      case AppNotificationType.like:
        return Colors.pinkAccent;
      case AppNotificationType.follow:
        return theme.colorScheme.tertiary;
      case AppNotificationType.timelineLike:
        return Colors.pink;
    }
  }

  void markRead() {
    read = true;
  }
}
