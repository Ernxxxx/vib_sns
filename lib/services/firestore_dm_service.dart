import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/conversation.dart';
import '../models/direct_message.dart';

class FirestoreDmService {
  FirestoreDmService();

  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _conversationsRef =>
      _firestore.collection('conversations');

  /// Get all conversations for a user
  Stream<List<Conversation>> watchConversations(String userId) {
    return _conversationsRef
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Conversation.fromMap(doc.data(), docId: doc.id);
      }).toList();
    });
  }

  /// Get or create a conversation between two users
  Future<Conversation> getOrCreateConversation({
    required String userId1,
    required String userId2,
  }) async {
    // Sort IDs to ensure consistent lookup
    final sortedIds = [userId1, userId2]..sort();

    // Check if conversation already exists
    final query = await _conversationsRef
        .where('participantIds', isEqualTo: sortedIds)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return Conversation.fromMap(
        query.docs.first.data(),
        docId: query.docs.first.id,
      );
    }

    // Create new conversation
    final docRef = _conversationsRef.doc();
    final conversationData = <String, dynamic>{
      'participantIds': sortedIds,
      'unreadCounts': {userId1: 0, userId2: 0},
      'lastMessage': null,
      'lastMessageAt': null,
      'type': 'text', // Default type
    };
    await docRef.set(conversationData);
    return Conversation(
      id: docRef.id,
      participantIds: sortedIds,
      unreadCounts: {userId1: 0, userId2: 0},
    );
  }

  /// Watch messages in a conversation
  Stream<List<DirectMessage>> watchMessages(String conversationId) {
    return _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['conversationId'] = conversationId;
        return DirectMessage.fromMap(data);
      }).toList();
    });
  }

  /// Uploads an image to Firebase Storage and returns the download URL.
  Future<String> uploadImage(File imageFile) async {
    final filename = '${_uuid.v4()}.jpg';
    final ref = _storage.ref().child('dm_images').child(filename);

    final metadata = SettableMetadata(contentType: 'image/jpeg');

    await ref.putFile(imageFile, metadata);
    return await ref.getDownloadURL();
  }

  /// Send a message (text or image)
  Future<DirectMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String recipientId,
    String? text,
    File? imageFile,
  }) async {
    if ((text == null || text.isEmpty) && imageFile == null) {
      throw ArgumentError('Must provide either text or imageFile');
    }

    String? imageUrl;
    String messageType = 'text';
    String previewText = text ?? '画像が送信されました';

    // 1. Upload image if present
    if (imageFile != null) {
      imageUrl = await uploadImage(imageFile);
      messageType = 'image';
      if (text == null || text.isEmpty) {
        previewText = '画像が送信されました';
      }
    }

    final messagesRef =
        _conversationsRef.doc(conversationId).collection('messages');
    final docRef = messagesRef.doc();
    final now = DateTime.now();

    final message = DirectMessage(
      id: docRef.id,
      conversationId: conversationId,
      senderId: senderId,
      text: text ?? '',
      createdAt: now,
      type: messageType,
      imageUrl: imageUrl,
    );

    // Send message and update conversation in a batch
    final batch = _firestore.batch();

    batch.set(docRef, message.toMap());

    batch.update(_conversationsRef.doc(conversationId), {
      'lastMessage': previewText,
      'lastMessageAt': now.toIso8601String(),
      'unreadCounts.$recipientId': FieldValue.increment(1),
    });

    await batch.commit();
    return message;
  }

  /// Mark messages as read
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    await _conversationsRef.doc(conversationId).update({
      'unreadCounts.$userId': 0,
    });
  }

  /// Get total unread message count for a user
  Stream<int> watchTotalUnreadCount(String userId) {
    return watchConversations(userId).map((conversations) {
      var total = 0;
      for (final conv in conversations) {
        total += conv.getUnreadCount(userId);
      }
      return total;
    });
  }

  /// Delete a conversation (for cleanup purposes)
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete all messages first
      final messagesQuery = await _conversationsRef
          .doc(conversationId)
          .collection('messages')
          .get();
      final batch = _firestore.batch();
      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_conversationsRef.doc(conversationId));
      await batch.commit();
    } catch (error, stackTrace) {
      debugPrint('Failed to delete conversation: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Toggle pin status for a conversation
  Future<void> togglePin({
    required String conversationId,
    required String userId,
    required bool isPinned,
  }) async {
    await _conversationsRef.doc(conversationId).update({
      'pinnedBy.$userId': isPinned,
    });
  }

  /// Toggle mute status for a conversation
  Future<void> toggleMute({
    required String conversationId,
    required String userId,
    required bool isMuted,
  }) async {
    await _conversationsRef.doc(conversationId).update({
      'mutedBy.$userId': isMuted,
    });
  }
}
