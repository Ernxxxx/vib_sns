# 🎮 Vib SNS

**あの「すれちがい通信」の感動を、スマホで。**

ニンテンドー3DSの「すれちがい通信」を覚えていますか？街を歩いているだけで見知らぬ誰かと繋がれる、あのワクワク感。Vib SNSは、そんな体験を現代のスマートフォンで再現するFlutterアプリです。

近くを通りかかった人のプロフィールを見て、「お、同じゲーム好きなんだ！」と思ったらいいねを送る。気になったらフォローする。そんなシンプルだけど楽しい出会いを大切にしています。

---

## ✨ こんなことができます

### 🚶 すれちがい通信
アプリを起動して歩くだけ！近くにいる他のユーザーを自動で検出して、出会いを記録します。GPSとBluetoothを組み合わせて、「本当に近くにいる人」を見つけ出します。

### 👤 自分だけのプロフィール
- 表示名と自己紹介
- 出身地
- 好きなゲーム（タグ形式で複数登録OK）
- プロフィール写真

あなたのことを知ってもらいましょう！

### 💬 ソーシャル機能
- **いいね** - 気になる人にワンタップでアピール
- **フォロー** - 気になる人を追いかけよう
- **タイムライン** - 最近の出会いやアクティビティをチェック

### 🗺️ マップビュー
出会った人たちをマップ上で確認できます。「こんなところで会ったんだ」という発見も楽しい。

### 📱 QRコードでプロフィール共有
その場で友達にプロフィールを見せたいとき、QRコードでサクッと共有できます。

---

## 🚀 セットアップガイド

### 必要なもの
- Flutter環境（3.x推奨）
- Firebaseプロジェクト
- Android/iOSの実機（BLEを使う場合）

### 1️⃣ 最初にやること

```bash
# 依存関係をインストール
flutter pub get
```

### 2️⃣ Firebaseの設定

1. **Firebaseコンソール**でプロジェクトを作成
2. **Cloud Firestore**と**Authentication（匿名認証）**を有効化
3. **FlutterFireで設定ファイルを生成**：

```bash
# FlutterFireをインストール（初回のみ）
dart pub global activate flutterfire_cli

# プロジェクトを設定
flutterfire configure
```

4. **ネイティブ設定ファイルを配置**：
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

### 3️⃣ Firestoreのデータ構造

アプリは主に2つのコレクションを使います：

**📁 profiles/{deviceId}** - ユーザープロフィール
```json
{
  "id": "device-id",
  "displayName": "あなたの名前",
  "bio": "自己紹介文",
  "homeTown": "東京",
  "favoriteGames": ["スプラトゥーン3", "マリオカート8 DX"],
  "photoUrl": "https://...",
  "followedBy": ["フォロワーのID"],
  "receivedLikes": 3
}
```

**📁 streetpass_presences/{deviceId}** - 位置情報（すれちがい用）
```json
{
  "profile": { /* プロフィール情報 */ },
  "lat": 35.6762,
  "lng": 139.6503,
  "lastUpdatedMs": 1690000000000,
  "active": true
}
```

> ⚠️ **開発用のFirestoreルール**（本番では適切なセキュリティルールを設定してください）：
> ```
> rules_version = '2';
> service cloud.firestore {
>   match /databases/{database}/documents {
>     match /{document=**} {
>       allow read, write;
>     }
>   }
> }
> ```

### 4️⃣ 権限の設定

**Android** (`android/app/src/main/AndroidManifest.xml`)：
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
```

**iOS** (`ios/Runner/Info.plist`)：
- `NSLocationWhenInUseUsageDescription`
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`
- `NSPhotoLibraryUsageDescription`

### 5️⃣ 起動！

```bash
flutter run
```

初回起動時に位置情報の権限を求められます。すれちがい検出に必要なので、許可してくださいね。

---

## 🔧 技術的な仕組み

興味がある人向けに、裏側でどう動いているかを説明します。

### すれちがい検出の流れ

```
あなたのスマホ                    Firestore                    相手のスマホ
    │                              │                              │
    │── 自分の位置を送信 ──────────▶│                              │
    │                              │◀────── 相手も位置を送信 ──────│
    │                              │                              │
    │◀─── 近くのユーザーを取得 ─────│                              │
    │                              │                              │
    ▼                              │                              │
 GPS距離を計算                     │                              │
    +                              │                              │
 BLEで近接確認 ─────────────────────────────────────────────────▶ BLEビーコン発信中
    │                              │                              │
    ▼                              │                              │
 出会いとして記録！                │                              │
```

### 使っている技術

| 機能 | 技術 |
|------|------|
| UI | Flutter + Material 3 |
| 状態管理 | Provider |
| 認証 | Firebase Auth（匿名） |
| データベース | Cloud Firestore |
| 位置情報 | Geolocator |
| Bluetooth | flutter_blue_plus, flutter_ble_peripheral |
| 地図 | flutter_map |
| 画像選択 | image_picker |

### モックモード 🧪

「Firebaseの設定めんどくさい」「Bluetooth使えない環境でテストしたい」という場合も大丈夫！

Firebaseに接続できないときは自動でモックモードに切り替わり、ダミーデータでUIを試せます。開発時に便利ですよ。

---

## 📁 プロジェクト構成

```
lib/
├── main.dart                    # アプリのスタート地点
├── models/                      # データの形を定義
│   ├── profile.dart            # プロフィール
│   ├── encounter.dart          # 出会い
│   └── timeline_event.dart     # タイムラインのイベント
├── screens/                     # 画面たち
│   ├── home_shell.dart         # ナビゲーション
│   ├── encounters_screen.dart  # 出会った人リスト
│   ├── timeline_screen.dart    # タイムライン
│   └── map_screen.dart         # マップ
├── services/                    # バックエンドとの通信
│   ├── streetpass_service.dart # すれちがい通信
│   ├── ble_proximity_scanner.dart # Bluetooth
│   └── ...
└── state/                       # アプリの状態管理
    ├── encounter_manager.dart
    ├── profile_controller.dart
    └── ...
```

---

## 🛤️ 今後やりたいこと

- [ ] 💬 メッセージ機能
- [ ] 🔔 プッシュ通知（新しい出会いをお知らせ）
- [ ] 🔋 バッテリー消費の最適化
- [ ] 🛡️ プライバシー機能（透明モード、ブロック）
- [ ] 📊 分析・エラーレポート

---

## 📝 ライセンス

このプロジェクトは教育・プロトタイプ目的で作成されています。

---

**Happy StreetPassing! 🚶‍♂️🚶‍♀️**
