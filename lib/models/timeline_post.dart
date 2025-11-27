import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TimelinePost {
  TimelinePost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorColorValue,
    required this.caption,
    required this.createdAt,
    this.imageBase64,
    this.imageUrl,
    this.likeCount = 0,
    this.isLiked = false,
    List<String>? likedBy,
    List<String>? hashtags,
  })  : hashtags = hashtags ?? const <String>[],
        likedBy = List<String>.from(likedBy ?? const <String>[]);

  final String id;
  final String authorId;
  final String authorName;
  final int authorColorValue;
  final String caption;
  final DateTime createdAt;
  final String? imageBase64;
  final String? imageUrl;
  int likeCount;
  bool isLiked;
  final List<String> hashtags;
  final List<String> likedBy;
  Uint8List? _cachedImageBytes;
  String? _cachedImageKey;

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

  Map<String, dynamic> toMap() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorColorValue': authorColorValue,
        'caption': caption,
        'createdAt': createdAt.toIso8601String(),
        'imageBase64': imageBase64,
        'imageUrl': imageUrl,
        'likeCount': likeCount,
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
      final likeCount =
          (map['likeCount'] as num?)?.toInt() ?? likedBy.length;
      final isLiked = viewerId != null && likedBy.contains(viewerId);
      final imageBase64 = map['imageBase64'] as String?;
      final hashtagsRaw = map['hashtags'];
      final hashtags = hashtagsRaw is Iterable
          ? hashtagsRaw.map((tag) => tag.toString()).toList()
          : const <String>[];
      return TimelinePost(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorColorValue: authorColor,
        caption: caption,
        createdAt: createdAt,
        imageBase64: imageBase64,
        imageUrl: map['imageUrl'] as String?,
        likeCount: likeCount,
        isLiked: isLiked,
        likedBy: likedBy,
        hashtags: hashtags,
      );
    } catch (_) {
      return null;
    }
  }
}
