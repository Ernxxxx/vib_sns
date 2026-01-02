import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// バックグラウンドメッセージハンドラ（トップレベル関数である必要がある）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM Background message: ${message.messageId}');
  // バックグラウンドではシステム通知が自動表示されるため、特別な処理は不要
}

/// FCM（Firebase Cloud Messaging）のサービスクラス
/// トークン管理、メッセージ受信ハンドリング、画面遷移を担当
class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? _currentProfileId;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static bool _isInitialized = false;

  /// Android用通知チャンネル設定
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'vib_sns_notifications',
    'Vib SNS通知',
    description: 'Vib SNSからの通知を受信します',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// FCMの初期化
  /// [profileId] 現在ログイン中のユーザーのプロファイルID
  static Future<void> initialize(String profileId) async {
    if (_isInitialized && _currentProfileId == profileId) {
      debugPrint('FCMService: Already initialized for profile $profileId');
      return;
    }

    _currentProfileId = profileId;

    // Web/非対応プラットフォームはスキップ
    if (kIsWeb) {
      debugPrint('FCMService: Web platform not supported');
      return;
    }

    try {
      // バックグラウンドハンドラを設定
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // 通知権限をリクエスト
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
          'FCMService: Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('FCMService: Notification permission denied');
        return;
      }

      // ローカル通知の初期化（フォアグラウンド用）
      await _initializeLocalNotifications();

      // FCMトークンを取得・保存
      final token = await _messaging.getToken();
      if (token != null) {
        await saveToken(profileId, token);
      }

      // トークンリフレッシュのリスナーを設定
      _setupTokenRefreshListener(profileId);

      // フォアグラウンドメッセージハンドラを設定
      _setupForegroundMessageHandler();

      _isInitialized = true;
      debugPrint('FCMService: Initialized successfully');
    } catch (e) {
      debugPrint('FCMService: Initialization failed: $e');
    }
  }

  /// ローカル通知プラグインの初期化
  static Future<void> _initializeLocalNotifications() async {
    // Android設定 - カスタム通知アイコンを使用
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    // iOS設定
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android用チャンネルを作成
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }
  }

  /// ローカル通知がタップされたときのハンドラ
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('FCMService: Local notification tapped: ${response.payload}');
    // ペイロードから画面遷移情報を解析して遷移
    // 実際の遷移はNavigatorKeyを使用するか、グローバルキーを使用する
  }

  /// FCMトークンをFirestoreに保存
  static Future<void> saveToken(String profileId, String token) async {
    try {
      final tokenData = {
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // トークンのハッシュをドキュメントIDとして使用
      final tokenHash = token.hashCode.abs().toString();

      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(profileId)
          .collection('fcmTokens')
          .doc(tokenHash)
          .set(tokenData, SetOptions(merge: true));

      debugPrint('FCMService: Token saved for profile $profileId');
    } catch (e) {
      debugPrint('FCMService: Failed to save token: $e');
    }
  }

  /// トークンリフレッシュ時のリスナーを設定
  static void _setupTokenRefreshListener(String profileId) {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCMService: Token refreshed');
      saveToken(profileId, newToken);
    });
  }

  /// フォアグラウンドメッセージ受信ハンドラを設定
  static void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCMService: Foreground message received: ${message.data}');

      final notification = message.notification;
      if (notification == null) return;

      // フォアグラウンドではローカル通知を表示
      _showLocalNotification(
        title: notification.title ?? 'Vib SNS',
        body: notification.body ?? '',
        payload: message.data,
      );
    });
  }

  /// ローカル通知を表示
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'vib_sns_notifications',
      'Vib SNS通知',
      channelDescription: 'Vib SNSからの通知を受信します',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@drawable/ic_notification',
      color: const Color(0xFFFFFF00), // Vib SNSのテーマカラー（黄色）
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // ペイロードをJSON文字列に変換
    final payloadString = payload != null
        ? payload.entries.map((e) => '${e.key}:${e.value}').join(',')
        : null;

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payloadString,
    );
  }

  /// アプリ起動時の初期メッセージを処理（terminated状態からの起動）
  static Future<Map<String, dynamic>?> getInitialMessage() async {
    if (kIsWeb) return null;

    try {
      final message = await _messaging.getInitialMessage();
      if (message != null) {
        debugPrint('FCMService: Initial message: ${message.data}');
        return message.data;
      }
    } catch (e) {
      debugPrint('FCMService: Failed to get initial message: $e');
    }
    return null;
  }

  /// 通知タップ時のハンドラを設定（background状態からの復帰）
  static void setupInteractionHandler(
      void Function(Map<String, dynamic> data) onTap) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCMService: Message opened app: ${message.data}');
      onTap(message.data);
    });
  }

  /// 通知データから画面遷移を実行
  static void handleNotificationNavigation(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'follow':
      case 'like':
        final profileId = data['profileId'] as String?;
        if (profileId != null) {
          _navigateToProfile(context, profileId);
        }
        break;

      case 'timelineLike':
      case 'reply':
        final postId = data['postId'] as String?;
        final replyId = data['replyId'] as String?;
        if (postId != null) {
          _navigateToPost(context, postId, replyId: replyId);
        }
        break;

      case 'dm':
        final conversationId = data['conversationId'] as String?;
        if (conversationId != null) {
          _navigateToChat(context, conversationId);
        }
        break;

      default:
        debugPrint('FCMService: Unknown notification type: $type');
    }
  }

  /// プロフィール画面へ遷移
  static void _navigateToProfile(BuildContext context, String profileId) {
    // 遅延インポートを避けるため、実際の画面遷移はHomeShellで行う
    // ここでは必要な情報をNavigatorにプッシュするだけ
    Navigator.of(context).pushNamed(
      '/profile',
      arguments: {'profileId': profileId},
    );
  }

  /// 投稿詳細画面へ遷移
  static void _navigateToPost(BuildContext context, String postId,
      {String? replyId}) {
    Navigator.of(context).pushNamed(
      '/post',
      arguments: {'postId': postId, 'replyId': replyId},
    );
  }

  /// チャット画面へ遷移
  static void _navigateToChat(BuildContext context, String conversationId) {
    Navigator.of(context).pushNamed(
      '/chat',
      arguments: {'conversationId': conversationId},
    );
  }

  /// 現在のプロファイルのトークンを削除（ログアウト時）
  static Future<void> deleteCurrentToken() async {
    if (_currentProfileId == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        final tokenHash = token.hashCode.abs().toString();
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(_currentProfileId)
            .collection('fcmTokens')
            .doc(tokenHash)
            .delete();
        debugPrint('FCMService: Token deleted for logout');
      }
    } catch (e) {
      debugPrint('FCMService: Failed to delete token: $e');
    }
  }

  /// サービスの破棄
  static void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _currentProfileId = null;
    _isInitialized = false;
  }
}
