# Vib SNS API & サービス技術リファレンス

このドキュメントは、Vib SNSで使用しているAPIとサービスの技術的な詳細をまとめたリファレンスです。

---

## 1. Firebase サービス

### 1.1 Firebase Authentication

**認証方式**:
- 匿名認証（Anonymous Authentication）
- Google Sign-In

**使用例**:
```dart
// 匿名認証
await FirebaseAuth.instance.signInAnonymously();

// Google認証
final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
final credential = GoogleAuthProvider.credential(
  accessToken: googleAuth?.accessToken,
  idToken: googleAuth?.idToken,
);
await FirebaseAuth.instance.signInWithCredential(credential);
```

**認証状態の監視**:
```dart
FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user != null) {
    // ログイン済み
  } else {
    // 未ログイン
  }
});
```

---

### 1.2 Cloud Firestore

**Firestoreインスタンスの取得**:
```dart
final db = FirebaseFirestore.instance;
```

**コレクション操作**:

```dart
// ドキュメントの作成/更新
await db.collection('profiles').doc(profileId).set(profile.toMap());

// ドキュメントの取得
final snapshot = await db.collection('profiles').doc(profileId).get();
final profile = Profile.fromMap(snapshot.data());

// リアルタイムリスナー
db.collection('profiles').doc(profileId).snapshots().listen((snapshot) {
  final profile = Profile.fromMap(snapshot.data());
});

// クエリ
final query = db.collection('streetpass_presences')
    .where('active', isEqualTo: true)
    .where('lastUpdatedMs', isGreaterThan: thresholdMs);
final results = await query.get();
```

---

### 1.3 Firebase Storage

**画像のアップロード**:
```dart
final storage = FirebaseStorage.instance;
final ref = storage.ref().child('posts/$postId/image.jpg');
await ref.putData(imageBytes);
final imageUrl = await ref.getDownloadURL();
```

---

### 1.4 Cloud Functions

**Callable関数の呼び出し**:
```dart
final functions = FirebaseFunctions.instance;
final callable = functions.httpsCallable('deleteUserProfile');
final result = await callable.call({
  'profileId': profileId,
  'beaconId': beaconId,
});
```

---

## 2. 位置情報API

### 2.1 Geolocator

**パッケージ**: `geolocator: ^11.0.0`

**位置情報の取得**:
```dart
import 'package:geolocator/geolocator.dart';

// 権限チェック
LocationPermission permission = await Geolocator.checkPermission();
if (permission == LocationPermission.denied) {
  permission = await Geolocator.requestPermission();
}

// 現在位置の取得
Position position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);
print('緯度: ${position.latitude}, 経度: ${position.longitude}');

// 位置情報のストリーム監視
Geolocator.getPositionStream().listen((Position position) {
  // 位置更新時の処理
});
```

**距離計算**:
```dart
double distance = Geolocator.distanceBetween(
  lat1, lng1,
  lat2, lng2,
);
print('距離: $distance メートル');
```

**Web版の注意点**:
Web版では位置情報取得にタイムアウトを設定することを推奨:
```dart
Position position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.medium, // Webでは精度を下げる
  timeLimit: const Duration(seconds: 10),
);
```

---

## 3. Bluetooth Low Energy (BLE) API

### 3.1 flutter_blue_plus（スキャン側）

**パッケージ**: `flutter_blue_plus: ^1.16.8`

**BLEスキャンの開始**:
```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// スキャン開始
FlutterBluePlus.startScan(
  timeout: const Duration(seconds: 4),
  withServices: [serviceUuid], // 特定のサービスUUIDをフィルタ
);

// スキャン結果の購読
FlutterBluePlus.scanResults.listen((results) {
  for (ScanResult result in results) {
    final deviceId = result.device.remoteId.str;
    final rssi = result.rssi;
    
    // RSSIから距離を推定（参考値）
    final distance = pow(10, (txPower - rssi) / (10 * n));
  }
});

// スキャン停止
FlutterBluePlus.stopScan();
```

---

### 3.2 flutter_ble_peripheral（アドバタイズ側）

**パッケージ**: `flutter_ble_peripheral: ^1.2.6`

**BLEアドバタイズの開始**:
```dart
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

final peripheral = FlutterBlePeripheral();

// アドバタイズデータの設定
final advertiseData = AdvertiseData(
  serviceUuid: serviceUuid,
  localName: beaconId, // ビーコンIDをローカル名として設定
);

// アドバタイズ開始
await peripheral.start(advertiseData: advertiseData);

// アドバタイズ停止
await peripheral.stop();
```

---

## 4. 地図API

### 4.1 flutter_map

**パッケージ**: `flutter_map: ^6.1.0`, `latlong2: ^0.9.0`

**基本的な地図表示**:
```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

FlutterMap(
  options: MapOptions(
    center: LatLng(35.6762, 139.6503), // 東京
    zoom: 15.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.vib_sns',
    ),
    MarkerLayer(
      markers: [
        Marker(
          point: LatLng(35.6762, 139.6503),
          child: const Icon(Icons.location_on, color: Colors.red),
        ),
      ],
    ),
  ],
);
```

---

## 5. 画像処理API

### 5.1 image_picker

**パッケージ**: `image_picker: ^1.0.7`

**画像の選択**:
```dart
import 'package:image_picker/image_picker.dart';

final picker = ImagePicker();

// ギャラリーから選択
final XFile? image = await picker.pickImage(source: ImageSource.gallery);

// カメラで撮影
final XFile? photo = await picker.pickImage(source: ImageSource.camera);

if (image != null) {
  final bytes = await image.readAsBytes();
  // Base64エンコード
  final base64 = base64Encode(bytes);
}
```

---

### 5.2 image（画像リサイズ）

**パッケージ**: `image: ^4.5.4`

**画像のリサイズ**:
```dart
import 'package:image/image.dart' as img;

// 画像のデコード
final original = img.decodeImage(imageBytes);

// リサイズ
final resized = img.copyResize(original!, width: 800);

// JPEG形式でエンコード（品質80%）
final compressed = img.encodeJpg(resized, quality: 80);
```

---

## 6. その他のAPI

### 6.1 QRコード生成

**パッケージ**: `qr_flutter: ^4.1.0`

```dart
import 'package:qr_flutter/qr_flutter.dart';

QrImageView(
  data: 'https://vib-sns.example.com/profile/$profileId',
  version: QrVersions.auto,
  size: 200.0,
);
```

---

### 6.2 バイブレーション

**パッケージ**: `vibration: ^1.8.4`

```dart
import 'package:vibration/vibration.dart';

// 単純なバイブレーション
Vibration.vibrate(duration: 500);

// パターンバイブレーション
Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 300]);

// ハプティックフィードバック
Vibration.hasCustomVibrationsSupport().then((hasSupport) {
  if (hasSupport == true) {
    Vibration.vibrate(amplitude: 128);
  }
});
```

---

### 6.3 ローカルストレージ

**パッケージ**: `shared_preferences: ^2.2.2`

```dart
import 'package:shared_preferences/shared_preferences.dart';

final prefs = await SharedPreferences.getInstance();

// 保存
await prefs.setString('profileId', profileId);
await prefs.setBool('firstLaunch', false);

// 読み込み
final storedId = prefs.getString('profileId');
final isFirstLaunch = prefs.getBool('firstLaunch') ?? true;

// 削除
await prefs.remove('profileId');
```

---

### 6.4 権限管理

**パッケージ**: `permission_handler: ^11.3.0`

```dart
import 'package:permission_handler/permission_handler.dart';

// 権限の確認
final status = await Permission.location.status;

if (status.isDenied) {
  // 権限のリクエスト
  await Permission.location.request();
}

// 複数の権限を同時にリクエスト
await [
  Permission.location,
  Permission.bluetooth,
  Permission.bluetoothScan,
  Permission.bluetoothConnect,
].request();
```

---

### 6.5 Google Fonts

**パッケージ**: `google_fonts: ^6.1.0`

```dart
import 'package:google_fonts/google_fonts.dart';

Text(
  'Vib SNS',
  style: GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  ),
);
```

---

## 7. 状態管理（Provider）

**パッケージ**: `provider: ^6.0.5`

### プロバイダーの定義と使用

```dart
// プロバイダーの登録（main.dart）
MultiProvider(
  providers: [
    ChangeNotifierProvider<ProfileController>(
      create: (_) => ProfileController(),
    ),
    ChangeNotifierProvider<EncounterManager>(
      create: (_) => EncounterManager(...),
    ),
    ChangeNotifierProvider<TimelineManager>(
      create: (_) => TimelineManager(...),
    ),
  ],
  child: const VibSnsApp(),
);

// プロバイダーの使用
final profile = context.watch<ProfileController>().localProfile;
final encounters = context.watch<EncounterManager>().encounters;

// プロバイダーへのアクセス（リビルドなし）
final manager = context.read<TimelineManager>();
await manager.addPost(caption: 'Hello!');
```

---

## 8. Firestoreクエリパターン

### 8.1 基本的なクエリ

```dart
// 全ドキュメント取得
final allProfiles = await db.collection('profiles').get();

// 条件付きクエリ
final activeUsers = await db.collection('streetpass_presences')
    .where('active', isEqualTo: true)
    .get();

// 複合クエリ
final nearbyUsers = await db.collection('streetpass_presences')
    .where('active', isEqualTo: true)
    .where('lastUpdatedMs', isGreaterThan: cutoffMs)
    .orderBy('lastUpdatedMs', descending: true)
    .limit(50)
    .get();
```

### 8.2 リアルタイム購読

```dart
// 単一ドキュメント
db.collection('profiles').doc(profileId).snapshots().listen((snapshot) {
  if (snapshot.exists) {
    final profile = Profile.fromMap(snapshot.data()!);
  }
});

// コレクション
db.collection('timelinePosts')
    .orderBy('createdAt', descending: true)
    .limit(50)
    .snapshots()
    .listen((snapshot) {
      final posts = snapshot.docs
          .map((doc) => TimelinePost.fromMap(doc.data()))
          .whereType<TimelinePost>()
          .toList();
    });
```

### 8.3 バッチ操作

```dart
final batch = db.batch();

batch.set(db.collection('profiles').doc(profileId), profile.toMap());
batch.update(db.collection('usernames').doc(username), {'profileId': profileId});
batch.delete(db.collection('oldData').doc(oldId));

await batch.commit();
```

### 8.4 トランザクション

```dart
await db.runTransaction((transaction) async {
  final profileRef = db.collection('profiles').doc(profileId);
  final snapshot = await transaction.get(profileRef);
  
  final currentLikes = (snapshot.data()?['receivedLikes'] as num?)?.toInt() ?? 0;
  
  transaction.update(profileRef, {
    'receivedLikes': currentLikes + 1,
  });
});
```

---

## 9. エラーハンドリング

### 9.1 Firebase例外

```dart
try {
  await FirebaseAuth.instance.signInAnonymously();
} on FirebaseAuthException catch (e) {
  switch (e.code) {
    case 'operation-not-allowed':
      // 匿名認証が無効
      break;
    case 'network-request-failed':
      // ネットワークエラー
      break;
    default:
      // その他のエラー
      break;
  }
}
```

### 9.2 Firestore例外

```dart
try {
  await db.collection('profiles').doc(id).get();
} on FirebaseException catch (e) {
  if (e.code == 'permission-denied') {
    // 権限エラー
  } else if (e.code == 'unavailable') {
    // オフライン
  }
}
```

### 9.3 カスタム例外

```dart
class StreetPassException implements Exception {
  StreetPassException(this.message);
  final String message;
  
  @override
  String toString() => 'StreetPassException: $message';
}

class StreetPassPermissionDenied extends StreetPassException {
  StreetPassPermissionDenied(super.message);
}
```

---

## 10. デバッグ・ロギング

### 10.1 デバッグプリント

```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('Debug info: $data');
}

// または
debugPrint('Detailed log message');
```

### 10.2 Firebase Crashlytics（推奨）

```dart
// エラーの記録
FirebaseCrashlytics.instance.recordError(
  error,
  stackTrace,
  reason: 'non-fatal error',
);

// カスタムログ
FirebaseCrashlytics.instance.log('User action: $action');
```

---

このリファレンスドキュメントは、Vib SNSの開発において使用されている主要なAPIとサービスの技術的な詳細を網羅しています。
