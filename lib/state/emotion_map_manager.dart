import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/emotion_post.dart';
import 'profile_controller.dart';

class EmotionMapManager extends ChangeNotifier {
  EmotionMapManager({required ProfileController profileController})
      : _profileController = profileController,
        _paused = profileController.needsSetup ||
            FirebaseAuth.instance.currentUser == null {
    _profileController.addListener(_handleProfileChanged);
    _activeProfileId = _profileController.profile.id;
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

  static const _collectionPath = 'emotion_map_posts';
  static const _maxPosts = 500;

  final ProfileController _profileController;
  final List<EmotionMapPost> _posts = [];
  String? _activeProfileId;
  bool _isLoaded = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _postsSub;
  bool _paused;
  StreamSubscription<User?>? _authSubscription;

  List<EmotionMapPost> get posts => List.unmodifiable(_posts);
  bool get isLoaded => _isLoaded;

  Future<void> addPost({
    required EmotionType emotion,
    required double latitude,
    required double longitude,
    String? message,
  }) async {
    final profileId = _activeProfileId;
    if (profileId == null) {
      return;
    }
    final trimmedMessage = message?.trim();
    final now = DateTime.now();
    final post = EmotionMapPost(
      id: const Uuid().v4(),
      emotion: emotion,
      latitude: latitude,
      longitude: longitude,
      createdAt: now,
      message: trimmedMessage?.isEmpty ?? true ? null : trimmedMessage,
      profileId: profileId,
    );
    _posts.insert(0, post);
    notifyListeners();

    final docRef =
        FirebaseFirestore.instance.collection(_collectionPath).doc(post.id);
    await docRef.set({
      'id': post.id,
      'emotion': emotion.id,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
      if (post.message != null && post.message!.isNotEmpty)
        'message': post.message,
      'profileId': profileId,
    });
  }

  Future<void> removePost(String postId) async {
    final index = _posts.indexWhere((element) => element.id == postId);
    if (index == -1) {
      return;
    }
    final removed = _posts.removeAt(index);
    notifyListeners();
    await FirebaseFirestore.instance
        .collection(_collectionPath)
        .doc(removed.id)
        .delete();
  }

  void _subscribeToPosts() {
    if (_paused) {
      return;
    }
    if (!_hasAuthUser) {
      debugPrint(
          'EmotionMapManager: deferring map subscription until FirebaseAuth user is available');
      return;
    }
    _postsSub?.cancel();
    _postsSub = FirebaseFirestore.instance
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true)
        .limit(_maxPosts)
        .snapshots()
        .listen((snapshot) {
      final loaded = <EmotionMapPost>[];
      for (final doc in snapshot.docs) {
        final post = _fromDocument(doc);
        if (post != null) {
          loaded.add(post);
        }
      }
      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _posts
        ..clear()
        ..addAll(loaded);
      _isLoaded = true;
      notifyListeners();
    });
  }

  EmotionMapPost? _fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final emotionId = data['emotion'] as String?;
    final emotion = EmotionTypeX.fromId(emotionId);
    if (emotion == null) return null;

    final latitude = data['latitude'];
    final longitude = data['longitude'];
    if (latitude is! num || longitude is! num) {
      return null;
    }

    final createdAtRaw = data['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    } else if (createdAtRaw is num) {
      createdAt =
          DateTime.fromMillisecondsSinceEpoch(createdAtRaw.toInt(), isUtc: true)
              .toLocal();
    }
    createdAt ??= DateTime.now();

    return EmotionMapPost(
      id: doc.id,
      emotion: emotion,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      createdAt: createdAt,
      message: (data['message'] as String?)?.trim(),
      profileId: data['profileId'] as String?,
    );
  }

  void _handleProfileChanged() {
    final nextProfileId = _profileController.profile.id;
    if (_activeProfileId == nextProfileId) {
      notifyListeners();
      return;
    }
    _activeProfileId = nextProfileId;
  }

  void pauseForLogout() {
    _paused = true;
    _postsSub?.cancel();
    _postsSub = null;
    _posts.clear();
    _isLoaded = false;
    notifyListeners();
  }

  void resumeAfterLogin() {
    final wasPaused = _paused;
    _paused = false;
    if (!wasPaused && _postsSub != null) {
      return;
    }
    _subscribeToPosts();
  }

  @override
  void dispose() {
    _profileController.removeListener(_handleProfileChanged);
    _authSubscription?.cancel();
    _postsSub?.cancel();
    super.dispose();
  }

  bool get _hasAuthUser => FirebaseAuth.instance.currentUser != null;
}
