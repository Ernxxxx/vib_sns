import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TimelinePost {
  TimelinePost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorUsername,
    required this.authorColorValue,
    required this.caption,
    required this.createdAt,
    this.imageBase64,
    this.imageUrl,
    this.authorAvatarImageBase64,
    this.likeCount = 0,
    this.isLiked = false,
    this.replyCount = 0,
    this.parentPostId,
    this.replyToId,
    this.replyToAuthorName,
    List<String>? likedBy,
    List<String>? hashtags,
  })  : hashtags = hashtags ?? const <String>[],
        likedBy = List<String>.from(likedBy ?? const <String>[]);

  final String id;
  final String authorId;
  final String authorName;
  final String? authorUsername;
  final int authorColorValue;
  final String caption;
  final DateTime createdAt;
  final String? imageBase64;
  final String? imageUrl;
  final String? authorAvatarImageBase64;
  int likeCount;
  bool isLiked;
  int replyCount;
  final String? parentPostId;
  final String? replyToId;
  final String? replyToAuthorName;
  final List<String> hashtags;
  final List<String> likedBy;
  Uint8List? _cachedImageBytes;
  String? _cachedImageKey;
  MemoryImage? _cachedAvatarImage;
  String? _cachedAvatarKey;

  Color get authorColor => Color(authorColorValue);

  Uint8List? decodeImage() {
    if (imageBase64 == null || imageBase64!.isEmpty) {
      return null;
    }
    if (_cachedImageBytes != null && _cachedImageKey == imageBase64) {
      return _cachedImageBytes;
    }
    try {
      final decoded = base64Decode(imageBase64!);
      _cachedImageBytes = decoded;
      _cachedImageKey = imageBase64;
      return decoded;
    } catch (_) {
      _cachedImageBytes = null;
      _cachedImageKey = null;
      return null;
    }
  }

  ImageProvider? resolveAvatarImage() {
    final raw = authorAvatarImageBase64;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final key = raw.trim();
    if (_cachedAvatarImage != null && _cachedAvatarKey == key) {
      return _cachedAvatarImage;
    }
    try {
      final bytes = base64Decode(key);
      if (bytes.isEmpty) {
        return null;
      }
      _cachedAvatarImage = MemoryImage(bytes);
      _cachedAvatarKey = key;
      return _cachedAvatarImage;
    } catch (_) {
      _cachedAvatarImage = null;
      _cachedAvatarKey = null;
      return null;
    }
  }

  /// Get formatted username with @ prefix
  String? get formattedAuthorUsername =>
      authorUsername != null && authorUsername!.isNotEmpty
          ? '@$authorUsername'
          : null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorUsername': authorUsername,
        'authorColorValue': authorColorValue,
        'caption': caption,
        'createdAt': createdAt.toIso8601String(),
        'imageBase64': imageBase64,
        'imageUrl': imageUrl,
        'authorAvatarImageBase64': authorAvatarImageBase64,
        'likeCount': likeCount,
        'replyCount': replyCount,
        'parentPostId': parentPostId,
        'replyToId': replyToId,
        'replyToAuthorName': replyToAuthorName,
        'likedBy': likedBy,
        'hashtags': hashtags,
      };

  static TimelinePost? fromMap(
    Map<String, dynamic>? map, {
    String? viewerId,
  }) {
    if (map == null) return null;
    try {
      final createdRaw = map['createdAt'];
      final createdAt = createdRaw is Timestamp
          ? createdRaw.toDate()
          : createdRaw is DateTime
              ? createdRaw
              : DateTime.tryParse(createdRaw?.toString() ?? '') ??
                  DateTime.now();
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) {
        return null;
      }
      final authorId = map['authorId'] as String? ?? '';
      final authorName = map['authorName'] as String? ?? '';
      final authorColor =
          (map['authorColorValue'] as num?)?.toInt() ?? 0xFF9E9E9E;
      final caption = map['caption'] as String? ?? '';
      final likedByRaw = map['likedBy'];
      final likedBy = likedByRaw is Iterable
          ? likedByRaw.map((e) => e.toString()).toList()
          : <String>[];
      final likeCount = (map['likeCount'] as num?)?.toInt() ?? likedBy.length;
      final replyCount = (map['replyCount'] as num?)?.toInt() ?? 0;
      final isLiked = viewerId != null && likedBy.contains(viewerId);
      final imageBase64 = map['imageBase64'] as String?;
      final authorAvatarImageBase64 = map['authorAvatarImageBase64'] as String?;
      final authorUsername = map['authorUsername'] as String?;
      final parentPostId = map['parentPostId'] as String?;
      final replyToId = map['replyToId'] as String?;
      final replyToAuthorName = map['replyToAuthorName'] as String?;
      final hashtagsRaw = map['hashtags'];
      final hashtags = hashtagsRaw is Iterable
          ? hashtagsRaw.map((tag) => tag.toString()).toList()
          : const <String>[];
      return TimelinePost(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorUsername: authorUsername,
        authorColorValue: authorColor,
        caption: caption,
        createdAt: createdAt,
        imageBase64: imageBase64,
        imageUrl: map['imageUrl'] as String?,
        authorAvatarImageBase64: authorAvatarImageBase64,
        likeCount: likeCount,
        replyCount: replyCount,
        parentPostId: parentPostId,
        replyToId: replyToId,
        replyToAuthorName: replyToAuthorName,
        isLiked: isLiked,
        likedBy: likedBy,
        hashtags: hashtags,
      );
    } catch (_) {
      return null;
    }
  }
}
