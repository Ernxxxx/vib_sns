import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/profile.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    this.radius = 28,
    this.showBorder = true,
  });

  // profileId -> (base64, bytes) でキャッシュを管理
  // 同じprofileIdで異なるbase64が来たらキャッシュを更新
  static final Map<String, (String, Uint8List)> _imageCache =
      <String, (String, Uint8List)>{};

  final Profile profile;
  final double radius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final imageBase64 = profile.avatarImageBase64?.trim();
    MemoryImage? imageProvider;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      final cacheKey = profile.id;
      final cached = _imageCache[cacheKey];
      // キャッシュがあり、かつ同じbase64なら再利用
      if (cached != null && cached.$1 == imageBase64) {
        imageProvider = MemoryImage(cached.$2);
      } else {
        try {
          final bytes = base64Decode(imageBase64);
          if (bytes.isNotEmpty) {
            _imageCache[cacheKey] = (imageBase64, bytes);
            imageProvider = MemoryImage(bytes);
          }
        } catch (_) {
          imageProvider = null;
        }
      }
    }
    final hasImage = imageProvider != null;
    final backgroundColor =
        hasImage && !showBorder ? Colors.transparent : Colors.grey;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundImage: imageProvider,
      child: hasImage
          ? null
          : Icon(
              Icons.person,
              color: Colors.white,
              size: radius * 1.2,
            ),
    );
  }
}
