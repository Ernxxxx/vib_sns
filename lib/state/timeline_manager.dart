import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/timeline_post.dart';
import '../utils/color_extensions.dart';
import 'profile_controller.dart';

class TimelineManager extends ChangeNotifier {
  TimelineManager({required ProfileController profileController})
      : _profileController = profileController,
        _paused = profileController.needsSetup ||
            FirebaseAuth.instance.currentUser == null {
    _authSubscription =
        FirebaseAuth.instance.userChanges().listen((User? user) {
      if (user != null && !_paused) {
        _subscribeToPosts();
      }
    });
    if (!_paused) {
      _subscribeToPosts();
    }
  }

  final ProfileController _profileController;
  final List<TimelinePost> _posts = [];
  bool _isLoaded = false;
  bool _paused;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<User?>? _authSubscription;
  final Map<String, bool> _pendingLikeStates = {};

  List<TimelinePost> get posts => List.unmodifiable(_posts);
  bool get isLoaded => _isLoaded;

  Future<void> addPost({
    required String caption,
    Uint8List? imageBytes,
    List<String> hashtags = const <String>[],
  }) async {
    final profile = _profileController.profile;
    final docRef = FirebaseFirestore.instance.collection('timelinePosts').doc();
    String? imageUrl;
    String? encodedImage;
    Uint8List? optimizedBytes;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final payload = _prepareImagePayload(imageBytes);
      optimizedBytes = payload.bytes;
      encodedImage = payload.inlineBase64;
      final storageRef =
          FirebaseStorage.instance.ref('timelinePosts/${docRef.id}.jpg');
      try {
        await storageRef.putData(
          optimizedBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrl = await storageRef.getDownloadURL();
      } catch (error, stackTrace) {
        debugPrint('TimelineManager: failed to upload image: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    await docRef.set({
      'id': docRef.id,
      'authorId': profile.id,
      'authorName': profile.displayName.isEmpty
          ? '\u3042\u306a\u305f'
          : profile.displayName,
      'authorColorValue': profile.avatarColor.toARGB32(),
      'caption': caption.trim(),
      'createdAt': DateTime.now().toIso8601String(),
      'imageBase64': encodedImage,
      'imageUrl': imageUrl,
      'likeCount': 0,
      'likedBy': <String>[],
      'hashtags': hashtags,
    });
  }

  Future<void> deletePost(TimelinePost post) async {
    final viewerId = _profileController.profile.id;
    if (post.authorId != viewerId) {
      throw StateError('You can only delete your own posts.');
    }
    final docRef =
        FirebaseFirestore.instance.collection('timelinePosts').doc(post.id);
    await docRef.delete();
    final storageRef =
        FirebaseStorage.instance.ref('timelinePosts/${post.id}.jpg');
    try {
      await storageRef.delete();
    } catch (_) {
      // Ignore if file doesn't exist.
    }
  }

  Future<void> seedBotPosts() async {
    final postsCollection =
        FirebaseFirestore.instance.collection('timelinePosts');
    final now = DateTime.now();
    final seeds = [
      {
        'authorId': 'bot_1',
        'authorName': 'BOT Resonance',
        'caption':
            '\u65b0\u3057\u3044\u30cf\u30c3\u30b7\u30e5\u30bf\u30b0\u306e\u6d41\u884c\u3092\u30c1\u30a7\u30c3\u30af\u4e2d\u3002',
        'hashtags': ['#AI', '#トレンド', '#共鳴'],
      },
      {
        'authorId': 'bot_2',
        'authorName': 'BOT Journey',
        'caption':
            '\u5bd2\u3044\u591c\u306e\u8857\u3092\u30bf\u30a4\u30e0\u30ab\u30e1\u30e9\u3067\u6295\u5f71\u4e2d\u3002',
        'hashtags': ['#旅', '#夜景', '#写真'],
      },
      {
        'authorId': 'bot_3',
        'authorName': 'BOT Chill',
        'caption':
            '\u30ab\u30d5\u30a7\u3067\u30d6\u30ec\u30a4\u30f3\u30b9\u30c8\u30fc\u30e0\u3092\u30ab\u30b9\u30bf\u30de\u30a4\u30ba\u3002',
        'hashtags': ['#カフェ', '#音楽', '#リラックス'],
      },
    ];
    for (final template in seeds) {
      final doc = postsCollection.doc();
      await doc.set({
        'id': doc.id,
        'authorId': template['authorId'],
        'authorName': template['authorName'],
        'authorColorValue': Colors.blueGrey.toARGB32(),
        'caption': template['caption'],
        'createdAt': now.toIso8601String(),
        'imageBase64': null,
        'imageUrl': null,
        'likeCount': 0,
        'likedBy': <String>[],
        'hashtags': template['hashtags'],
      });
    }
  }

  Future<void> toggleLike(String postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) {
      return;
    }
    final post = _posts[index];
    final viewer = _profileController.profile;
    final viewerId = viewer.id;
    if (viewerId.isEmpty) return;
    final wasLiked = post.isLiked;
    final nextLiked = !wasLiked;
    final delta = nextLiked ? 1 : -1;
    post.isLiked = nextLiked;
    post.likeCount = (post.likeCount + delta).clamp(0, 999999);
    if (nextLiked) {
      if (!post.likedBy.contains(viewerId)) {
        post.likedBy.add(viewerId);
      }
    } else {
      post.likedBy.remove(viewerId);
    }
    notifyListeners();
    _pendingLikeStates[postId] = nextLiked;

    final docRef =
        FirebaseFirestore.instance.collection('timelinePosts').doc(post.id);
    try {
      await docRef.update({
        'likeCount': FieldValue.increment(delta),
        'likedBy': nextLiked
            ? FieldValue.arrayUnion([viewerId])
            : FieldValue.arrayRemove([viewerId]),
      });
      // Let the Firestore snapshot listener clear the pending state when server catches up.
    } catch (error, stackTrace) {
      debugPrint('Failed to update timeline like: $error');
      debugPrintStack(stackTrace: stackTrace);
      _pendingLikeStates.remove(postId);
      // Revert optimistic update on failure.
      post.isLiked = wasLiked;
      post.likeCount = (post.likeCount - delta).clamp(0, 999999);
      if (wasLiked) {
        if (!post.likedBy.contains(viewerId)) {
          post.likedBy.add(viewerId);
        }
      } else {
        post.likedBy.remove(viewerId);
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  void pauseForLogout() {
    _paused = true;
    _subscription?.cancel();
    _subscription = null;
    _posts.clear();
    _isLoaded = false;
    notifyListeners();
  }

  void resumeAfterLogin() {
    _paused = false;
    _subscribeToPosts();
  }

  void _subscribeToPosts() {
    if (_paused) {
      return;
    }
    if (!_hasAuthUser) {
      debugPrint(
          'TimelineManager: deferring timeline subscription until FirebaseAuth user is available');
      return;
    }
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('timelinePosts')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen((snapshot) {
      final viewerId = _profileController.profile.id;
      final nextPosts = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = data['id'] ?? doc.id;
            return TimelinePost.fromMap(
              data,
              viewerId: viewerId,
            );
          })
          .whereType<TimelinePost>()
          .toList();
      // Preserve pending like states to avoid overwriting optimistic updates.
      for (final post in nextPosts) {
        final pendingLike = _pendingLikeStates[post.id];
        if (pendingLike != null) {
          if (post.isLiked == pendingLike) {
            // Server caught up, clear pending state.
            _pendingLikeStates.remove(post.id);
          } else {
            // Keep the optimistic state until server catches up.
            post.isLiked = pendingLike;
            if (pendingLike && !post.likedBy.contains(viewerId)) {
              post.likedBy.add(viewerId);
            } else if (!pendingLike) {
              post.likedBy.remove(viewerId);
            }
          }
        }
      }
      _posts
        ..clear()
        ..addAll(nextPosts);
      _isLoaded = true;
      notifyListeners();
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('Failed to load timeline posts: $error');
    });
  }

  Future<void> clearPostsForCurrentProfile() async {
    _posts.clear();
    notifyListeners();
  }

  bool get _hasAuthUser => FirebaseAuth.instance.currentUser != null;

  ({Uint8List bytes, String? inlineBase64}) _prepareImagePayload(
    Uint8List source,
  ) {
    const inlineByteLimit = 700000; // ~933KB once base64-encoded.
    try {
      final decoded = img.decodeImage(source);
      if (decoded == null) {
        return (
          bytes: source,
          inlineBase64:
              source.length <= inlineByteLimit ? base64Encode(source) : null,
        );
      }
      const maxSide = 1440;
      img.Image processed = decoded;
      if (decoded.width > maxSide || decoded.height > maxSide) {
        processed = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxSide : null,
          height: decoded.height > decoded.width ? maxSide : null,
          interpolation: img.Interpolation.linear,
        );
      }
      Uint8List encoded = Uint8List.fromList(
        img.encodeJpg(processed, quality: 80),
      );
      String? inlineBase64;
      const qualities = [80, 72, 64, 56, 48];
      for (final quality in qualities) {
        encoded = Uint8List.fromList(
          img.encodeJpg(processed, quality: quality),
        );
        if (encoded.length <= inlineByteLimit) {
          inlineBase64 = base64Encode(encoded);
          break;
        }
      }
      return (bytes: encoded, inlineBase64: inlineBase64);
    } catch (_) {
      return (
        bytes: source,
        inlineBase64:
            source.length <= inlineByteLimit ? base64Encode(source) : null,
      );
    }
  }
}
