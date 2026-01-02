# Vib SNS 完全ドキュメント

このドキュメントは、Vib SNSアプリのすべての情報を包括的にまとめたものです。
NotebookLMなどのAIツールに読み込ませることで、アプリについての質問に回答できるナレッジベースとして使用できます。

---

## 1. アプリ概要

### アプリ名
**Vib SNS（ビブ エスエヌエス）**

### コンセプト
ニンテンドー3DSの「すれちがい通信」に着想を得た、現代のスマートフォン向けソーシャルアプリです。
街を歩いているだけで近くにいる人と繋がれる体験を提供します。

### 主な特徴
- GPSとBluetooth Low Energy（BLE）を使用した近接検出
- すれちがった人のプロフィール表示
- いいね・フォロー機能
- タイムライン（投稿・返信機能）
- ダイレクトメッセージ（DM）
- エモーションマップ（感情を地図上に投稿）
- 通知システム
- QRコードでのプロフィール共有

### プラットフォーム
- Android
- iOS
- Web

---

## 2. 技術スタック

### フロントエンド
| 技術 | 用途 |
|------|------|
| Flutter 3.x | クロスプラットフォームUI開発 |
| Material 3 | デザインシステム |
| Provider | 状態管理パターン |
| Google Fonts | カスタムフォント（Inter, Roboto, Outfit） |

### バックエンド（Firebase）
| 技術 | 用途 |
|------|------|
| Firebase Auth | 認証（匿名認証、Google認証） |
| Cloud Firestore | データベース |
| Firebase Storage | 画像ストレージ |
| Cloud Functions | サーバーサイドロジック |
| Firebase Hosting | Webアプリホスティング |

### その他のパッケージ
| パッケージ | 用途 |
|------------|------|
| geolocator | GPS位置情報取得 |
| flutter_blue_plus | BLEスキャン |
| flutter_ble_peripheral | BLEアドバタイズ |
| flutter_map | 地図表示 |
| latlong2 | 緯度経度計算 |
| image_picker | 画像選択 |
| qr_flutter | QRコード生成 |
| vibration | バイブレーション制御 |
| shared_preferences | ローカルストレージ |
| permission_handler | 権限管理 |

---

## 3. プロジェクト構造

```
vib_sns/
├── lib/                          # Dartソースコード
│   ├── main.dart                 # エントリーポイント
│   ├── firebase_options.dart     # Firebase設定
│   ├── data/                     # データレイヤー
│   ├── models/                   # データモデル (7ファイル)
│   │   ├── profile.dart          # ユーザープロフィール
│   │   ├── encounter.dart        # すれちがい記録
│   │   ├── timeline_post.dart    # タイムライン投稿
│   │   ├── conversation.dart     # DM会話
│   │   ├── direct_message.dart   # DMメッセージ
│   │   ├── app_notification.dart # 通知
│   │   └── emotion_post.dart     # エモーションマップ投稿
│   ├── screens/                  # 画面 (18ファイル)
│   │   ├── home_shell.dart       # メイン画面（タブナビゲーション）
│   │   ├── encounter_list_screen.dart    # すれちがい一覧
│   │   ├── encounter_detail_screen.dart  # すれちがい詳細
│   │   ├── profile_view_screen.dart      # プロフィール詳細
│   │   ├── profile_edit_screen.dart      # プロフィール編集
│   │   ├── chat_screen.dart              # チャット画面
│   │   ├── conversation_list_screen.dart # 会話一覧
│   │   ├── notifications_screen.dart     # 通知一覧
│   │   ├── post_detail_screen.dart       # 投稿詳細
│   │   ├── settings_screen.dart          # 設定
│   │   ├── welcome_screen.dart           # ウェルカム画面
│   │   ├── register_account_screen.dart  # アカウント登録
│   │   └── ...
│   ├── services/                 # バックエンド通信 (10ファイル)
│   │   ├── streetpass_service.dart       # すれちがい抽象クラス
│   │   ├── firestore_streetpass_service.dart  # Firestore実装
│   │   ├── mock_streetpass_service.dart       # モック実装
│   │   ├── profile_interaction_service.dart   # プロフィール操作抽象クラス
│   │   ├── firestore_profile_interaction_service.dart # Firestore実装
│   │   ├── mock_profile_interaction_service.dart      # モック実装
│   │   ├── ble_proximity_scanner.dart          # BLE抽象クラス
│   │   ├── ble_proximity_scanner_impl.dart     # BLE実装
│   │   ├── mock_ble_proximity_scanner.dart     # モック実装
│   │   └── firestore_dm_service.dart           # DM Firestore実装
│   ├── state/                    # 状態管理 (7ファイル)
│   │   ├── encounter_manager.dart      # すれちがい状態管理
│   │   ├── timeline_manager.dart       # タイムライン状態管理
│   │   ├── notification_manager.dart   # 通知状態管理
│   │   ├── emotion_map_manager.dart    # エモーションマップ管理
│   │   ├── profile_controller.dart     # プロフィール制御
│   │   ├── local_profile_loader.dart   # ローカルプロフィール読み込み
│   │   └── runtime_config.dart         # 実行時設定
│   ├── utils/                    # ユーティリティ (5ファイル)
│   └── widgets/                  # 再利用可能ウィジェット (10ファイル)
│       ├── emotion_map.dart      # エモーションマップウィジェット
│       ├── like_button.dart      # いいねボタン
│       ├── profile_avatar.dart   # アバター表示
│       └── ...
├── functions/                    # Cloud Functions (Node.js)
│   ├── index.js                  # 関数定義
│   └── package.json              # 依存関係
├── firestore.rules               # Firestoreセキュリティルール
├── storage.rules                 # Storageセキュリティルール
├── firebase.json                 # Firebase設定
├── pubspec.yaml                  # Flutter依存関係
├── android/                      # Android固有設定
├── web/                          # Web固有設定
├── dashboard/                    # 管理ダッシュボード
└── assets/                       # 静的アセット
```

---

## 4. データモデル

### 4.1 Profile（ユーザープロフィール）

ユーザーの基本情報を管理するモデルです。

```dart
class Profile {
  final String id;              // デバイスID（プロフィールの一意識別子）
  final String beaconId;        // BLEビーコンID
  final String? username;       // ユーザーID（@で始まる、3-20文字、英数字とアンダースコア）
  final String displayName;     // 表示名
  final String bio;             // 自己紹介
  final String homeTown;        // 出身地
  final List<String> favoriteGames;  // お気に入りハッシュタグ（最大10個、32文字以内）
  final Color avatarColor;      // アバター背景色
  final String? avatarImageBase64;  // アバター画像（Base64エンコード）
  bool following;               // フォロー中かどうか
  int receivedLikes;            // 受け取ったいいね数
  int followersCount;           // フォロワー数
  int followingCount;           // フォロー中の数
}
```

**Firestoreコレクション**: `profiles/{profileId}`

**主な機能**:
- `toggleFollow()`: フォロー状態を切り替え
- `like()`: いいねを追加
- `copyWith()`: プロフィールのコピーを作成
- `toMap()` / `fromMap()`: Firestore変換
- `validateUsername()`: ユーザー名のバリデーション
- `normalizeUsername()`: ユーザー名の正規化
- `sanitizeHashtags()`: ハッシュタグのサニタイズ

**サブコレクション**:
- `profiles/{profileId}/followers/{followerId}`: フォロワー一覧
- `profiles/{profileId}/following/{targetId}`: フォロー中一覧
- `profiles/{profileId}/likes/{likerId}`: いいねした人一覧
- `profiles/{profileId}/notifications/{notificationId}`: 通知

---

### 4.2 Encounter（すれちがい記録）

すれちがいイベントを記録するモデルです。

```dart
class Encounter {
  final String id;              // 一意識別子
  Profile profile;              // すれちがった相手のプロフィール
  final String beaconId;        // 相手のビーコンID
  DateTime encounteredAt;       // すれちがった日時
  String? message;              // 一言メッセージ
  double? gpsDistanceMeters;    // GPS距離（メートル）
  double? bleDistanceMeters;    // BLE距離（メートル）
  double? latitude;             // 緯度
  double? longitude;            // 経度
  bool unread;                  // 未読フラグ
  bool liked;                   // いいね済みフラグ
}
```

**計算プロパティ**:
- `displayDistance`: BLE距離があればそれを、なければGPS距離を返す
- `proximityVerified`: BLE距離が記録されている場合はtrue

**主な機能**:
- `markRead()`: 既読にする
- `toggleLiked()`: いいね状態を切り替え

---

### 4.3 TimelinePost（タイムライン投稿）

タイムラインの投稿を管理するモデルです。

```dart
class TimelinePost {
  final String id;              // 投稿ID
  final String authorId;        // 投稿者のプロフィールID
  final String authorName;      // 投稿者の表示名
  final String? authorUsername; // 投稿者のユーザー名
  final int authorColorValue;   // 投稿者のアバター色
  final String caption;         // 投稿本文
  final DateTime createdAt;     // 作成日時
  final String? imageBase64;    // 画像（Base64エンコード）
  final String? imageUrl;       // 画像URL（Firebase Storage）
  final String? authorAvatarImageBase64;  // 投稿者アバター
  int likeCount;                // いいね数
  bool isLiked;                 // 閲覧者がいいね済みか
  int replyCount;               // 返信数
  final String? parentPostId;   // 親投稿ID（リプライの場合）
  final String? replyToId;      // 返信先投稿ID
  final String? replyToAuthorName;  // 返信先の投稿者名
  final List<String> hashtags;  // ハッシュタグ
  final List<String> likedBy;   // いいねした人のIDリスト
}
```

**Firestoreコレクション**: `timelinePosts/{postId}`

**サブコレクション**: `timelinePosts/{postId}/replies/{replyId}`

**主な機能**:
- `decodeImage()`: Base64画像をデコード
- `resolveAvatarImage()`: アバター画像を取得
- `formattedAuthorUsername`: @付きユーザー名を取得

---

### 4.4 Conversation（会話）

DMの会話を管理するモデルです。

```dart
class Conversation {
  final String id;                    // 会話ID
  final List<String> participantIds;  // 参加者のプロフィールIDリスト
  String? lastMessage;                // 最新メッセージ
  DateTime? lastMessageAt;            // 最新メッセージ日時
  Map<String, int> unreadCounts;      // ユーザーごとの未読数
  Map<String, bool> pinnedBy;         // ピン留め状態
  Map<String, bool> mutedBy;          // ミュート状態
}
```

**Firestoreコレクション**: `conversations/{conversationId}`

**サブコレクション**: `conversations/{conversationId}/messages/{messageId}`

**主な機能**:
- `getOtherParticipantId()`: 相手の参加者IDを取得
- `getUnreadCount()`: 未読数を取得
- `isPinnedFor()`: ピン留め状態を確認
- `isMutedFor()`: ミュート状態を確認

---

### 4.5 DirectMessage（ダイレクトメッセージ）

個別のDMメッセージを管理するモデルです。

```dart
class DirectMessage {
  final String id;              // メッセージID
  final String senderId;        // 送信者のプロフィールID
  final String content;         // メッセージ内容
  final DateTime createdAt;     // 送信日時
  final String? imageBase64;    // 添付画像（Base64）
}
```

---

### 4.6 AppNotification（通知）

アプリ内通知を管理するモデルです。

```dart
enum AppNotificationType {
  encounter,      // すれちがい通知
  like,           // プロフィールへのいいね
  follow,         // フォロー
  timelineLike,   // 投稿へのいいね
  reply,          // 返信
}

class AppNotification {
  final String id;                  // 通知ID
  final AppNotificationType type;   // 通知タイプ
  final String title;               // タイトル
  final String message;             // メッセージ
  final DateTime createdAt;         // 作成日時
  final Profile? profile;           // 関連するプロフィール
  final String? encounterId;        // 関連するすれちがいID
  final String? postId;             // 関連する投稿ID
  final String? replyId;            // 関連するリプライID
  bool read;                        // 既読フラグ
}
```

---

### 4.7 EmotionMapPost（エモーションマップ投稿）

感情を地図上に投稿する機能のモデルです。

```dart
enum EmotionType {
  happy,      // うれしい 😊
  sad,        // かなしい 😢
  excited,    // ワクワク 🤩
  calm,       // おだやか 😌
  surprised,  // びっくり 😮
  tired,      // つかれた 😴
}

class EmotionMapPost {
  final String id;              // 投稿ID
  final EmotionType emotion;    // 感情タイプ
  final double latitude;        // 緯度
  final double longitude;       // 経度
  final DateTime createdAt;     // 作成日時
  final String? message;        // 一言メッセージ
  final String? profileId;      // 投稿者のプロフィールID
}
```

**Firestoreコレクション**: `emotion_map_posts/{postId}`

---

## 5. サービスレイヤー

### 5.1 StreetPassService（すれちがいサービス）

近くのユーザーを検出するサービスの抽象クラスです。

```dart
abstract class StreetPassService {
  Stream<StreetPassEncounterData> get encounterStream;
  Future<void> start(Profile localProfile);
  Future<void> stop();
  Future<void> dispose();
}
```

**実装クラス**:
- `FirestoreStreetPassService`: Firestoreを使用した本番実装
- `MockStreetPassService`: テスト用モック実装

**StreetPassEncounterData**:
```dart
class StreetPassEncounterData {
  final String remoteId;        // 相手のプロフィールID
  final Profile profile;        // 相手のプロフィール
  final String beaconId;        // ビーコンID
  final DateTime encounteredAt; // すれちがい日時
  final double gpsDistanceMeters;  // GPS距離
  final String? message;        // メッセージ
  final double? latitude;       // 緯度
  final double? longitude;      // 経度
}
```

---

### 5.2 ProfileInteractionService（プロフィール操作サービス）

プロフィール関連の操作を行うサービスの抽象クラスです。

```dart
abstract class ProfileInteractionService {
  Future<void> bootstrapProfile(Profile profile);
  Stream<ProfileInteractionSnapshot> watchProfile({required String targetId, required String viewerId});
  Stream<List<ProfileFollowSnapshot>> watchFollowers({required String targetId, required String viewerId});
  Stream<List<ProfileFollowSnapshot>> watchFollowing({required String targetId, required String viewerId});
  Stream<List<ProfileLikeSnapshot>> watchLikes({required String targetId, required String viewerId});
  Future<void> setLike({required String targetId, required Profile viewerProfile, required bool like});
  Future<void> setFollow({required String targetId, required String viewerId, required bool follow});
  Future<List<ProfileFollowSnapshot>> loadFollowersOnce({required String targetId, required String viewerId});
  Future<List<ProfileFollowSnapshot>> loadFollowingOnce({required String targetId, required String viewerId});
  Future<Profile?> loadProfile(String profileId);
  Future<bool> isUsernameTaken(String username, {String? excludeProfileId});
  Future<void> dispose();
}
```

**実装クラス**:
- `FirestoreProfileInteractionService`: Firestore実装
- `MockProfileInteractionService`: モック実装

---

### 5.3 BleProximityScanner（BLE近接スキャナー）

Bluetooth Low Energyを使用した近接検出サービスです。

**BleProximityHit**:
```dart
class BleProximityHit {
  final String beaconId;        // ビーコンID
  final double? estimatedDistance;  // 推定距離
  final int? rssi;              // 信号強度
}
```

**実装クラス**:
- `BleProximityScannerImpl`: 本番実装（flutter_blue_plus使用）
- `MockBleProximityScanner`: モック実装

---

### 5.4 FirestoreDMService（DMサービス）

ダイレクトメッセージを管理するサービスです。

**主な機能**:
- 会話の作成・取得
- メッセージの送受信
- 未読カウントの管理
- ピン留め・ミュート機能

---

## 6. 状態管理（State Management）

### 6.1 EncounterManager

すれちがいの状態を管理するProviderです。

**主な機能**:
- すれちがい検出の開始・停止
- 近接バイブレーション（すれちがい時に振動）
- ハッシュタグマッチング（共通のハッシュタグがある場合の通知）
- すれちがいリストの管理
- いいね・フォローの操作

**状態**:
```dart
List<Encounter> encounters       // すれちがいリスト
Encounter? latest               // 最新のすれちがい
Map<String, int> resonanceCount // 共鳴カウント（ハッシュタグマッチ回数）
Map<String, int> reunionCount   // 再会カウント
```

---

### 6.2 TimelineManager

タイムラインの状態を管理するProviderです。

**主な機能**:
- 投稿の作成・削除
- リプライの追加・削除
- いいねの切り替え
- 画像のアップロード（Firebase Storage）
- リアルタイム更新（Firestoreスナップショット）

**状態**:
```dart
List<TimelinePost> posts        // 投稿リスト
bool loading                    // ローディング状態
```

---

### 6.3 NotificationManager

通知の状態を管理するProviderです。

**主な機能**:
- 通知の取得・更新
- 未読カウントの管理
- 通知のリアルタイム更新

**状態**:
```dart
List<AppNotification> notifications  // 通知リスト
int unreadCount                      // 未読数
```

---

### 6.4 EmotionMapManager

エモーションマップの状態を管理するProviderです。

**主な機能**:
- 感情投稿の作成
- 近くの感情投稿の取得
- 地図上での表示

---

### 6.5 ProfileController

ローカルユーザーのプロフィールを管理するProviderです。

**主な機能**:
- プロフィールの読み込み
- プロフィールの更新
- 認証状態の管理

---

## 7. Cloud Functions

### deleteUserProfile

ユーザープロフィールとその関連データを削除するCallable関数です。

```javascript
exports.deleteUserProfile = functions.https.onCall(async (data, context) => {
  // 認証チェック
  // プロフィール所有権の検証
  // 関連データの削除:
  //   - フォロワー/フォロー中の参照
  //   - いいねの参照
  //   - streetpass_presences
  //   - notifications
  //   - usernamesコレクションの予約
  //   - プロフィールドキュメント本体
  //   - Firebase Authenticationのユーザー
});
```

**削除されるデータ**:
1. 他のプロフィールの`followers`と`likes`サブコレクションから、このプロフィールIDの参照
2. プロフィールの`followers`、`following`、`likes`サブコレクション
3. `streetpass_presences`内の関連ドキュメント
4. `notifications`内の関連ドキュメント
5. `usernames`コレクション内のユーザー名予約
6. プロフィールドキュメント
7. Firebase Authenticationのユーザーアカウント

---

## 8. Firestoreコレクション構造

### profiles（プロフィール）
```
profiles/{profileId}
├── followers/{followerId}     # フォロワー
├── following/{targetId}       # フォロー中
├── likes/{likerId}            # いいねした人
└── notifications/{notificationId}  # 通知
```

**フィールド**:
```json
{
  "id": "device-id",
  "authUid": "firebase-auth-uid",
  "username": "username123",
  "displayName": "表示名",
  "bio": "自己紹介",
  "homeTown": "出身地",
  "favoriteGames": ["#ハッシュタグ1", "#ハッシュタグ2"],
  "avatarColor": 4283215696,
  "avatarImageBase64": "base64...",
  "beaconId": "ble-beacon-id",
  "receivedLikes": 5,
  "followersCount": 10,
  "followingCount": 8
}
```

---

### usernames（ユーザー名予約）
ユーザー名の一意性を保証するためのコレクションです。

```
usernames/{username}  // usernameは小文字に正規化
```

**フィールド**:
```json
{
  "profileId": "関連するプロフィールID"
}
```

---

### timelinePosts（タイムライン投稿）
```
timelinePosts/{postId}
└── replies/{replyId}  # 返信
```

**フィールド**:
```json
{
  "id": "post-id",
  "authorId": "profile-id",
  "authorName": "投稿者名",
  "authorUsername": "username",
  "authorColorValue": 4283215696,
  "caption": "投稿内容",
  "createdAt": "2025-01-01T12:00:00.000Z",
  "imageBase64": "base64...",
  "imageUrl": "https://...",
  "authorAvatarImageBase64": "base64...",
  "likeCount": 5,
  "replyCount": 3,
  "likedBy": ["user-id-1", "user-id-2"],
  "hashtags": ["#タグ1", "#タグ2"],
  "parentPostId": null,
  "replyToId": null,
  "replyToAuthorName": null
}
```

---

### streetpass_presences（すれちがいプレゼンス）
現在アクティブなユーザーの位置情報を保持します。

```
streetpass_presences/{deviceId}
```

**フィールド**:
```json
{
  "profile": { /* Profileオブジェクト */ },
  "lat": 35.6762,
  "lng": 139.6503,
  "lastUpdatedMs": 1690000000000,
  "active": true,
  "deviceId": "device-id",
  "beaconId": "ble-beacon-id"
}
```

---

### emotion_map_posts（エモーションマップ投稿）
```
emotion_map_posts/{postId}
```

**フィールド**:
```json
{
  "id": "post-id",
  "emotion": "happy",
  "latitude": 35.6762,
  "longitude": 139.6503,
  "createdAt": "2025-01-01T12:00:00.000Z",
  "message": "今日はいい天気！",
  "profileId": "profile-id"
}
```

---

### conversations（会話）
```
conversations/{conversationId}
└── messages/{messageId}  # メッセージ
```

**Conversationフィールド**:
```json
{
  "participantIds": ["user-id-1", "user-id-2"],
  "lastMessage": "最新メッセージ",
  "lastMessageAt": "2025-01-01T12:00:00.000Z",
  "unreadCounts": {"user-id-1": 0, "user-id-2": 2},
  "pinnedBy": {"user-id-1": true},
  "mutedBy": {}
}
```

**Messageフィールド**:
```json
{
  "id": "message-id",
  "senderId": "sender-profile-id",
  "content": "メッセージ内容",
  "createdAt": "2025-01-01T12:00:00.000Z",
  "imageBase64": null
}
```

---

## 9. Firestoreセキュリティルール

### 認証ヘルパー関数
```
signedIn()        // ログイン済みか
authUid()         // 認証UID取得
ownsProfile(id)   // プロフィールの所有者か
```

### ルールの概要
- **profiles**: ログインユーザーは読み取り可能、作成時はauthUidが一致必須、更新は所有者またはカウンターのみ変更
- **usernames**: ログインユーザーは読み取り可能、作成/削除は所有者のみ
- **timelinePosts**: ログインユーザーは読み取り可能、作成/削除は投稿者のみ
- **streetpass_presences**: プロフィール所有者のみ書き込み可能
- **conversations/messages**: ログインユーザーは読み書き可能（アプリレベルでセキュリティ制御）

---

## 10. 画面構成

### 10.1 メイン画面（HomeShell）
タブベースのメインナビゲーションです。

**タブ**:
1. **すれちがい**: すれちがったユーザーの一覧
2. **タイムライン**: 投稿フィード
3. **マップ**: エモーションマップ

**追加機能**:
- ユーザーアイコンからプロフィール画面へ
- 通知ベル（未読バッジ付き）
- メッセージアイコン（DM）

---

### 10.2 すれちがい関連画面

**EncounterListScreen**: すれちがい一覧
- ユーザーカード表示
- いいねボタン
- 詳細画面への遷移

**EncounterDetailScreen**: すれちがい詳細
- プロフィール情報
- 距離情報
- いいね/フォローボタン

---

### 10.3 プロフィール関連画面

**ProfileViewScreen**: プロフィール詳細表示
- アバター、表示名、ユーザー名
- 自己紹介、出身地
- ハッシュタグ
- フォロワー/フォロー中/いいね数
- いいね/フォローボタン
- DM送信ボタン

**ProfileEditScreen**: プロフィール編集
- 表示名、ユーザー名、自己紹介編集
- アバター画像変更
- ハッシュタグ編集

---

### 10.4 タイムライン関連画面

**PostDetailScreen**: 投稿詳細
- 投稿内容表示
- いいねボタン
- 返信一覧
- 返信投稿機能

---

### 10.5 DM関連画面

**ConversationListScreen**: 会話一覧
- 会話リスト
- 未読バッジ
- ピン留め表示

**ChatScreen**: チャット画面
- メッセージ一覧
- メッセージ送信
- 画像送信

---

### 10.6 その他の画面

**NotificationsScreen**: 通知一覧
**SettingsScreen**: 設定（ログアウト、アカウント削除）
**WelcomeScreen**: ウェルカム画面
**RegisterAccountScreen**: アカウント登録

---

## 11. 認証フロー

### 11.1 匿名認証
初回起動時は匿名認証でアカウントを作成します。

### 11.2 Google認証
Google Sign-Inによる認証が可能です。
匿名アカウントからの移行にも対応しています。

### 11.3 プロフィール設定
- **表示名**: 必須
- **ユーザー名（@username）**: 必須、一意である必要あり
- **自己紹介**: 任意
- **出身地**: 任意
- **ハッシュタグ**: 任意（最大10個）
- **アバター**: 色選択または画像アップロード

---

## 12. すれちがい検出の仕組み

### プロセス
1. アプリ起動時にGPS位置情報を取得
2. 自分の位置を`streetpass_presences`コレクションに書き込み
3. 定期的に近くの`streetpass_presences`をクエリ
4. GPS距離が閾値内のユーザーを検出
5. BLEビーコンによる近接確認（オプション）
6. ハッシュタグマッチングをチェック
7. バイブレーション通知（近接時）
8. すれちがいリストに追加

### 距離計算
- **GPS**: Geolocatorパッケージによる測地距離計算
- **BLE**: RSSIから推定距離を計算

### ハッシュタグマッチング
- 両者のお気に入りハッシュタグを比較
- 共通のハッシュタグがあれば「共鳴」として記録
- 特別なバイブレーションパターンで通知

---

## 13. モックモード

Firebaseに接続できない環境や開発時のために、モックモードを用意しています。

**モック実装**:
- `MockStreetPassService`: ダミーのすれちがいデータを生成
- `MockProfileInteractionService`: メモリ内でプロフィール操作を模擬
- `MockBleProximityScanner`: ダミーのBLEヒットを生成

**使用ケース**:
- Firebase接続エラー時の自動切り替え
- UIの開発・テスト
- デモ環境

---

## 14. 必要な権限

### Android
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
```

### iOS
- `NSLocationWhenInUseUsageDescription`: 位置情報使用許可
- `NSBluetoothAlwaysUsageDescription`: Bluetooth使用許可
- `NSBluetoothPeripheralUsageDescription`: Bluetoothペリフェラル使用許可
- `NSPhotoLibraryUsageDescription`: 写真ライブラリアクセス許可

---

## 15. セットアップ手順

### 開発環境
1. Flutter 3.x をインストール
2. リポジトリをクローン
3. `flutter pub get` で依存関係をインストール
4. Firebaseプロジェクトを作成
5. FlutterFireで設定を生成: `flutterfire configure`
6. `flutter run` で起動

### Firebase設定
1. Cloud Firestore を有効化
2. Firebase Authentication を有効化（匿名認証、Google認証）
3. Firebase Storage を有効化
4. Cloud Functions をデプロイ

---

## 16. 今後の予定（TODO）

- メッセージ機能の拡充
- プッシュ通知
- バッテリー最適化
- プライバシー機能（透明モード、ブロック）

---

## 17. ライセンス

教育・プロトタイプ目的

---

## 付録A: よくある質問（FAQ）

### Q: すれちがい検出の精度はどのくらいですか？
A: GPSのみの場合は数十メートルの誤差があります。BLEを併用すると数メートル程度の精度になります。

### Q: オフラインでも使えますか？
A: オフライン時はモックモードで動作しますが、他のユーザーとの実際のすれちがいは記録されません。

### Q: ユーザー名は変更できますか？
A: プロフィール編集画面から変更可能です。ただし、他のユーザーが使用していない一意の名前である必要があります。

### Q: アカウントを削除するとどうなりますか？
A: 設定画面からアカウント削除が可能です。プロフィール、投稿、フォロー関係などすべてのデータがFirestoreから削除されます。

### Q: 位置情報はどのように使われますか？
A: 位置情報はすれちがい検出のみに使用されます。`streetpass_presences`コレクションに一時的に保存され、他のアクティブユーザーとの距離計算に使用されます。

---

## 付録B: 用語集

| 用語 | 説明 |
|------|------|
| すれちがい | 近くにいるユーザーを検出するイベント |
| ビーコンID | BLEで自分を識別するためのID |
| プロフィールID | デバイスIDをベースにしたユーザー識別子 |
| ハッシュタグ | お気に入りのゲームや趣味を表すタグ |
| 共鳴 | 共通のハッシュタグを持つユーザーとのすれちがい |
| 再会 | 以前すれちがったユーザーとの再度のすれちがい |
| エモーションマップ | 感情を地図上に投稿する機能 |
| タイムライン | 投稿フィード |
| DM | ダイレクトメッセージ |

---

このドキュメントはVib SNSアプリのバージョン 0.1.0 に基づいています。
最終更新: 2026年1月1日
