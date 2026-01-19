# Vib SNS

**すれちがい通信をスマホで楽しめるアプリ**

街を歩いてるだけで近くの人と繋がれる、そんな体験をFlutterで作ってみた。
近くにいる人のプロフィール見て、いいねしたりフォローしたり。シンプルだけど意外と楽しい。

---

## できること

### すれちがい機能
アプリ起動して歩くだけ。GPSとBluetoothで近くのユーザーを検出して出会いを記録する。
「本当に近くにいる人」を見つけるためにBLEも併用してる。

### プロフィール
- 名前、自己紹介
- 出身地
- 好きなゲーム（複数OK）
- プロフィール画像

### ソーシャル機能
- いいね送れる
- フォローできる
- タイムラインで最近の出会いを確認
- ダイレクトメッセージ（DM）で会話

### その他
- **エモーションマップ**: 出会った場所の確認と、「今の瞬間」を地図にシェア
- QRコードでプロフィール共有
- プッシュ通知で出会いや反応をお知らせ

---

## セットアップ

### 必要なもの
- Flutter 3.x
- Firebaseプロジェクト
- 実機（BLE使う場合）

### 手順

```bash
flutter pub get
```

#### Firebase設定

1. Firebaseコンソールでプロジェクト作成
2. Cloud FirestoreとAuthentication（匿名認証）を有効に
3. FlutterFireで設定生成：

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

4. ネイティブ設定ファイルを配置
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

#### Firestoreのコレクション

**profiles/{deviceId}**
```json
{
  "id": "device-id",
  "displayName": "名前",
  "bio": "自己紹介",
  "homeTown": "東京",
  "favoriteGames": ["スプラトゥーン3", "マリオカート8 DX"],
  "photoUrl": "https://...",
  "followedBy": ["フォロワーID"],
  "receivedLikes": 3
}
```

**streetpass_presences/{deviceId}**
```json
{
  "profile": { ... },
  "lat": 35.6762,
  "lng": 139.6503,
  "lastUpdatedMs": 1690000000000,
  "active": true
}
```

開発用のFirestoreルール（本番では変更必須）：
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write;
    }
  }
}
```

#### 権限設定

**Android** (`AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
```

**iOS** (`Info.plist`)
- `NSLocationWhenInUseUsageDescription`
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`
- `NSPhotoLibraryUsageDescription`

#### 起動

```bash
flutter run
```

初回は位置情報の権限求められる。許可しないと動かない。

---

## 技術スタック

| 項目 | 使ってるもの |
|------|-------------|
| UI | Flutter + Material 3 |
| 状態管理 | Provider |
| 認証 | Firebase Auth |
| DB | Cloud Firestore |
| 位置情報 | Geolocator |
| Bluetooth | flutter_blue_plus, flutter_ble_peripheral |
| 地図 | flutter_map, latlong2 |
| 画像 | image_picker |

### すれちがい検出の仕組み

```
自分のスマホ                      Firestore                      相手のスマホ
    │                              │                              │
    │── 位置を送信 ─────────────────▶│                              │
    │                              │◀───────── 相手も送信 ─────────│
    │                              │                              │
    │◀── 近くのユーザー取得 ────────│                              │
    │                              │                              │
    ▼                              │                              │
 GPS距離計算                       │                              │
    +                              │                              │
 BLE確認 ───────────────────────────────────────────────────────▶ ビーコン発信中
    │                              │                              │
    ▼                              │                              │
 出会い記録                        │                              │
```

### モックモード

Firebaseに繋がらない時は自動でモックモードになる。ダミーデータでUI確認できるから開発時は便利。

---

## プロジェクト構成

```
lib/
├── main.dart                    # エントリーポイント
├── models/                      # データモデル
│   ├── profile.dart
│   ├── encounter.dart
│   └── timeline_event.dart
├── screens/                     # 画面
│   ├── home_shell.dart
│   ├── encounters_screen.dart
│   ├── timeline_screen.dart
│   └── map_screen.dart
├── services/                    # バックエンド通信
│   ├── streetpass_service.dart
│   ├── ble_proximity_scanner.dart
│   └── ...
└── state/                       # 状態管理
    ├── encounter_manager.dart
    ├── profile_controller.dart
    └── ...
```

---

## TODO

- バッテリー最適化
- プライバシー機能（透明モード、ブロック）強化

---

## ライセンス

教育・プロトタイプ目的
