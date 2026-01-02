# Vib SNS すれちがい検出・バイブレーション完全仕様書

このドキュメントは、すれちがい検出とバイブレーションのトリガー条件のすべての細かい仕様をまとめたものです。

---

## 1. 定数一覧（完全版）

### EncounterManager の定数

```dart
// 距離閾値
static const double _closeProximityRadiusMeters = 3;      // 近距離振動範囲
static const double _farProximityRadiusMeters = 10;       // 遠距離振動範囲
static const double _bleVibrationBufferMeters = 1.5;      // BLE用バッファ

// 時間関連
static const Duration _presenceTimeout = Duration(seconds: 45);        // BLEプレゼンスのタイムアウト
static const Duration _reencounterCooldown = Duration(minutes: 15);    // 再すれちがい通知クールダウン
static const Duration _minProximityCooldown = Duration(seconds: 5);    // 最小振動クールダウン（3m以下）
static const Duration _maxProximityCooldown = Duration(seconds: 30);   // 最大振動クールダウン（10m以上）
static const Duration _hashtagMatchCooldown = Duration(minutes: 1);    // ハッシュタグマッチ振動クールダウン
static const Duration _proximityTimeout = Duration(seconds: 60);       // 近接タイムアウト

// すれちがいリスト表示期間
const Duration(hours: 24)  // 過去24時間以内のすれちがいのみ表示
```

### FirestoreStreetPassService の定数

```dart
// 位置情報ポーリング
Timer.periodic(const Duration(seconds: 5))  // 5秒ごとに位置情報をスキャン

// 位置情報設定
LocationSettings(
  accuracy: LocationAccuracy.best,  // 最高精度
  distanceFilter: 5,                 // 5m移動ごとに更新
)

// タイムアウト
Duration _presenceTimeout = Duration(minutes: 10);   // プレゼンス有効期間
double _detectionRadiusMeters = 100;                  // すれちがい検出半径（100m以内）

// キャッシュ
const Duration(seconds: 10)  // 位置情報キャッシュの有効期間
const Duration(seconds: 30)  // 同一ユーザーからのすれちがいイベントのクールダウン
```

### BleProximityScannerImpl の定数

```dart
// BLE設定
static const String _serviceUuid = '8b0c53b0-0e68-4a10-9f88-27a8fac51111';
static const int _manufacturerId = 0x1357;

// 距離推定パラメータ
const measuredPower = -59;     // 1mでの典型的なRSSI値
const pathLossExponent = 2.0;  // パスロス指数

// 距離範囲
distance.clamp(0.1, 10.0)  // 0.1m〜10mの範囲に制限
```

---

## 2. すれちがい検出の詳細フロー

### 2.1 位置情報によるすれちがい検出

```
┌─────────────────────────────────────────────────────────────────┐
│ FirestoreStreetPassService                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ start()                                                         │
│    │                                                            │
│    ├─→ _ensureDeviceId() → SharedPreferencesからデバイスIDを取得  │
│    │   └→ なければUUID v4を生成して保存                          │
│    │                                                            │
│    ├─→ _ensurePermission() → 位置情報権限チェック                 │
│    │   └→ 拒否時は StreetPassPermissionDenied をスロー           │
│    │                                                            │
│    ├─→ _subscribePresence() → streetpass_presences をリアルタイム監視 │
│    │                                                            │
│    ├─→ Timer.periodic(5秒) → _scanNearby() を定期実行            │
│    │                                                            │
│    └─→ getPositionStream() → 位置変化を監視                      │
│        └→ distanceFilter: 5m ごとに _handlePosition() 呼び出し   │
│                                                                 │
│ _handlePosition(Position)                                       │
│    │                                                            │
│    ├─→ _updatePresence() → Firestoreに自分の位置を書き込み       │
│    │   profile, lat, lng, lastUpdatedMs, active=true            │
│    │                                                            │
│    └─→ _scanNearby() → 近くのユーザーをスキャン                  │
│                                                                 │
│ _scanNearby(Position)                                           │
│    │                                                            │
│    ├─→ cutoffMs = now - 10分                                    │
│    │   lastUpdatedMs > cutoffMs のドキュメントをクエリ           │
│    │                                                            │
│    └─→ _processDocuments() で各ドキュメントを処理                │
│                                                                 │
│ _processDocuments(docs, position)                               │
│    │                                                            │
│    ├─→ 自分のデバイスIDはスキップ                                │
│    │                                                            │
│    ├─→ Geolocator.distanceBetween() で距離計算                  │
│    │                                                            │
│    ├─→ distance > 100m ならスキップ                             │
│    │                                                            │
│    ├─→ 30秒以内に同じユーザーからのイベントならスキップ           │
│    │                                                            │
│    └─→ StreetPassEncounterData を encounterStream に追加        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 BLEによるすれちがい検出

```
┌─────────────────────────────────────────────────────────────────┐
│ BleProximityScannerImpl                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ start(localBeaconId, targetBeaconIds)                           │
│    │                                                            │
│    ├─→ _ensurePermissions() → 必要な権限をリクエスト             │
│    │   - locationWhenInUse                                      │
│    │   - bluetoothScan                                          │
│    │   - bluetoothConnect                                       │
│    │   - bluetoothAdvertise                                     │
│    │                                                            │
│    ├─→ _startAdvertising(beaconId) → BLEアドバタイズ開始         │
│    │   AdvertiseData:                                           │
│    │     serviceUuid: 8b0c53b0-0e68-4a10-9f88-27a8fac51111      │
│    │     manufacturerId: 0x1357                                  │
│    │     manufacturerData: beaconId(UUID形式、16バイト)          │
│    │   AdvertiseSettings:                                       │
│    │     advertiseMode: lowLatency                              │
│    │     txPowerLevel: high                                     │
│    │                                                            │
│    └─→ _startScanning() → BLEスキャン開始                       │
│        FlutterBluePlus.startScan:                               │
│          withServices: [serviceUuid]                            │
│          continuousUpdates: true                                │
│          androidScanMode: lowLatency                            │
│          androidUsesFineLocation: true                          │
│                                                                 │
│ _processScanResults(results)                                    │
│    │                                                            │
│    ├─→ manufacturerData[0x1357] をチェック                      │
│    │   - 16バイトでない場合はスキップ                            │
│    │                                                            │
│    ├─→ beaconId を抽出（UUIDアンパース）                         │
│    │                                                            │
│    ├─→ targetBeaconIds に含まれていなければスキップ              │
│    │                                                            │
│    ├─→ _estimateDistance(rssi) で距離を推定                     │
│    │                                                            │
│    └─→ BleProximityHit を hits ストリームに追加                  │
│                                                                 │
│ _estimateDistance(rssi)                                         │
│    公式: distance = 10^((measuredPower - rssi)/(10 * n))        │
│    - measuredPower = -59 dBm（1mでの典型値）                     │
│    - n = 2.0（パスロス指数）                                     │
│    結果: 0.1m〜10.0m にクランプ                                  │
│    NaN/Infinite の場合: デフォルト10mを返す                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. EncounterManager の詳細処理フロー

### 3.1 _handleEncounter（GPSすれちがい処理）

```dart
void _handleEncounter(StreetPassEncounterData data) {
  // 1. プレゼンス情報の更新/作成
  final presence = _presenceByBeaconId.putIfAbsent(data.beaconId, () => _BeaconPresence());
  
  // 2. 既存のEncounterを更新、または新規作成
  final existing = _encountersByRemoteId[data.remoteId];
  if (existing != null) {
    // 既存のEncounterを更新
    existing.encounteredAt = data.encounteredAt;
    existing.gpsDistanceMeters = data.gpsDistanceMeters;
    existing.message = data.message ?? existing.message;
    existing.unread = true;
    // プロフィール情報の更新（followやlikeの状態は維持）
  } else {
    // 新規Encounterを作成
    _encountersByRemoteId[data.remoteId] = Encounter(...);
  }
  
  // 3. BLEスキャンのターゲットに追加
  if (_targetBeaconIds.add(data.beaconId)) {
    _bleScanner?.updateTargetBeacons(_targetBeaconIds);
  }
  
  // 4. プロフィールのリアルタイム監視を開始
  _ensureInteractionSubscription(data.remoteId);
  
  // 5. ハッシュタグをキャッシュ
  _hydrateRemoteHashtags(data.remoteId, data.profile);
  
  // 6. 通知の判定（再すれちがいクールダウン: 15分）
  final shouldNotify = !isRepeat || _shouldNotifyRepeat(...);
  if (shouldNotify) {
    _notificationManager?.registerEncounter(...);
  }
  
  // 7. 共有ハッシュタグの判定
  final hasSharedHashtag = _hasSharedHashtag(data.remoteId, data.profile);
  
  // 8. 振動のトリガー
  final triggeredProximityVibration = _maybeTriggerProximityVibration(
    beaconId: data.beaconId,
    remoteId: data.remoteId,
    remoteProfile: data.profile,
    gpsDistanceMeters: data.gpsDistanceMeters,
    hasSharedHashtag: hasSharedHashtag,
  );
  
  // 9. 振動しなかった場合、ハッシュタグマッチのフィードバック
  if (!triggeredProximityVibration) {
    _maybeTriggerHashtagMatchFeedback(remoteId: data.remoteId, hasSharedHashtag: ...);
  }
  
  // 10. 共鳴/再会の更新
  _updateResonanceAndReunion(encounter, shouldResonate, countedAsRepeat: ...);
  
  notifyListeners();
}
```

### 3.2 _handleBleEncounter（BLEすれちがい処理）

```dart
void _handleBleEncounter(BleProximityHit hit) {
  // 1. ビーコンの最終検知時刻を更新
  _markBeaconSeen(hit.beaconId);
  
  // 2. ビーコンIDからEncounterを検索
  Encounter? matched;
  for (final encounter in _encountersByRemoteId.values) {
    if (encounter.beaconId == hit.beaconId) {
      matched = encounter;
      break;
    }
  }
  if (matched == null) return;
  
  // 3. BLE距離の平滑化
  final smoothedDistance = _recordBleDistance(hit.beaconId, hit.distanceMeters);
  matched.bleDistanceMeters = smoothedDistance;
  matched.unread = true;
  
  // 4. 共有ハッシュタグの判定
  final hasSharedHashtag = _hasSharedHashtag(matched.profile.id, matched.profile);
  
  // 5. 振動のトリガー（BLE用の距離閾値）
  final triggeredProximityVibration = _maybeTriggerProximityVibration(
    beaconId: hit.beaconId,
    remoteId: matched.profile.id,
    remoteProfile: matched.profile,
    bleDistanceMeters: smoothedDistance,
    isBleHit: true,
    hasSharedHashtag: hasSharedHashtag,
  );
  
  // 6. 振動しなかった場合のハッシュタグマッチフィードバック
  if (!triggeredProximityVibration) {
    _maybeTriggerHashtagMatchFeedback(...);
  }
  
  // 7. 共鳴/再会の更新
  _updateResonanceAndReunion(matched, shouldResonate, countedAsRepeat: true);
  
  notifyListeners();
}
```

---

## 4. 振動トリガーの完全ロジック

### 4.1 _maybeTriggerProximityVibration

```dart
bool _maybeTriggerProximityVibration({
  required String beaconId,
  required String remoteId,
  required Profile remoteProfile,
  double? gpsDistanceMeters,
  double? bleDistanceMeters,
  bool isBleHit = false,
  bool? hasSharedHashtag,
}) {
  // Webでは常にfalse
  if (kIsWeb) {
    isBleHit = false;
    bleDistanceMeters = null;
  }

  // 条件1: 抑制リストチェック
  if (_suppressedRemoteIds.contains(remoteId)) {
    return false;
  }

  // 条件2: 共有ハッシュタグがあること（必須）
  final sharedHashtag = hasSharedHashtag ?? _hasSharedHashtag(remoteId, remoteProfile);
  if (!sharedHashtag) {
    return false;
  }

  // 条件3: 距離の判定
  final distance = _resolveProximityDistance(
    gpsDistanceMeters: gpsDistanceMeters,
    bleDistanceMeters: bleDistanceMeters,
  );
  
  // 最大距離の決定
  final maxDistance = isBleHit
      ? _closeProximityRadiusMeters + _bleVibrationBufferMeters  // 3 + 1.5 = 4.5m
      : _farProximityRadiusMeters;                                // 10m

  if (distance == null || distance <= 0 || distance > maxDistance) {
    return false;
  }

  // 条件4: クールダウンのチェック
  final now = DateTime.now();
  final lastVibrated = _lastVibrationAt[beaconId];
  final cooldown = _cooldownForDistance(distance);  // 5〜30秒

  if (lastVibrated != null && now.difference(lastVibrated) < cooldown) {
    return false;
  }

  // 条件をすべてクリア → 振動実行
  _lastVibrationAt[beaconId] = now;
  _proximityUserLastSeen[remoteId] = now;

  unawaited(_triggerProximityHaptics());
  unawaited(SystemSound.play(SystemSoundType.click));
  return true;
}
```

### 4.2 距離に応じたクールダウン計算

```dart
Duration _cooldownForDistance(double distance) {
  // 3m以下 → 最小クールダウン（5秒）
  if (distance <= _closeProximityRadiusMeters) {
    return _minProximityCooldown;  // 5秒
  }
  
  // 10m以上 → 最大クールダウン（30秒）
  if (distance >= _farProximityRadiusMeters) {
    return _maxProximityCooldown;  // 30秒
  }
  
  // 3m〜10mの間 → 線形補間
  final ratio = (distance - 3) / (10 - 3);
  final minMs = 5000;   // 5秒
  final maxMs = 30000;  // 30秒
  final interpolated = minMs + ((maxMs - minMs) * ratio);
  return Duration(milliseconds: interpolated.round());
}
```

**距離別クールダウン早見表**:

| 距離 | クールダウン |
|------|-------------|
| 0m | 5秒 |
| 1m | 5秒 |
| 2m | 5秒 |
| 3m | 5秒 |
| 4m | 約8.5秒 |
| 5m | 約12秒 |
| 6m | 約16秒 |
| 7m | 約19秒 |
| 8m | 約23秒 |
| 9m | 約26秒 |
| 10m+ | 30秒 |

### 4.3 振動パターン

```dart
Future<void> _triggerProximityHaptics() async {
  try {
    // カスタム振動サポートがある場合
    final supportsCustom = (await Vibration.hasCustomVibrationsSupport()) ?? false;
    if (supportsCustom) {
      await Vibration.vibrate(duration: 400, amplitude: 255);  // 400ms、最大強度
      return;
    }
    
    // 基本バイブレーターがある場合
    final hasVibrator = (await Vibration.hasVibrator()) ?? false;
    if (hasVibrator) {
      await Vibration.vibrate(duration: 350);  // 350ms
      return;
    }
  } catch (error) {
    debugPrint('Vibration plugin failed: $error');
  }
  
  // フォールバック: システムのハプティックフィードバック
  unawaited(HapticFeedback.heavyImpact());
}
```

### 4.4 ハッシュタグマッチのフィードバック

```dart
void _maybeTriggerHashtagMatchFeedback({
  required String remoteId,
  required bool hasSharedHashtag,
}) {
  // Webでは無効
  if (kIsWeb || !hasSharedHashtag) {
    return;
  }
  
  // 抑制リストチェック
  if (_suppressedRemoteIds.contains(remoteId)) {
    return;
  }

  // クールダウンチェック（1分）
  final now = DateTime.now();
  final lastTriggered = _lastHashtagMatchAt[remoteId];
  if (lastTriggered != null && now.difference(lastTriggered) < _hashtagMatchCooldown) {
    return;
  }
  
  _lastHashtagMatchAt[remoteId] = now;
  
  // 軽いハプティックフィードバック
  unawaited(HapticFeedback.selectionClick());
}
```

---

## 5. 共有ハッシュタグの判定ロジック

```dart
bool _hasSharedHashtag(String remoteId, Profile remoteProfile) {
  // 1. プロフィールのハッシュタグを取得
  final localProfileTags = _normalizedHashtagSet(_localProfile.favoriteGames);
  var remoteProfileTags = _remoteHashtagCache[remoteId];
  if (remoteProfileTags == null) {
    remoteProfileTags = _normalizedHashtagSet(remoteProfile.favoriteGames);
    _remoteHashtagCache[remoteId] = remoteProfileTags;
    // 相手のハッシュタグが空なら非同期でプリフェッチ
    if (remoteProfileTags.isEmpty) {
      unawaited(_prefetchRemoteHashtags(remoteId));
    }
  }

  // 2. 投稿のハッシュタグを取得（TimelineManagerがあれば）
  Set<String> localPostTags = {};
  Set<String> remotePostTags = {};
  if (_timelineManager != null) {
    localPostTags = _timelineManager.getPostHashtagsForUser(_localProfile.id);
    remotePostTags = _timelineManager.getPostHashtagsForUser(remoteId);
  }

  // 3. プロフィール + 投稿のハッシュタグを統合
  final allLocalTags = {...localProfileTags, ...localPostTags};
  final allRemoteTags = {...remoteProfileTags, ...remotePostTags};

  // 4. どちらかが空なら共有なし
  if (allLocalTags.isEmpty || allRemoteTags.isEmpty) {
    return false;
  }

  // 5. 共通のハッシュタグを検索
  for (final tag in allLocalTags) {
    if (allRemoteTags.contains(tag)) {
      debugPrint('[VIBE] shared hashtag found: #$tag');
      return true;
    }
  }
  return false;
}

// ハッシュタグの正規化
Set<String> _normalizedHashtagSet(List<String> tags) {
  final normalized = <String>{};
  for (final tag in tags) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) continue;
    // #を削除して小文字に変換
    final canonical = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    if (canonical.isEmpty) continue;
    normalized.add(canonical.toLowerCase());
  }
  return normalized;
}
```

---

## 6. 共鳴（Resonance）と再会（Reunion）

### 6.1 共鳴の条件

```dart
bool _shouldRecordResonance(Encounter encounter, bool shouldResonate) {
  // 条件1: 相互いいね
  final mutualLike = encounter.liked && 
      (_notificationManager?.hasLikedMe(encounter.profile.id) ?? false);
  
  // 条件2: 共有ハッシュタグ + 近接条件
  // shouldResonate = hasSharedHashtag && _inProximityRange(...)
  
  return mutualLike || shouldResonate;
}
```

### 6.2 再会の条件

```dart
bool _canRecordReunion(String remoteId, DateTime at) {
  final last = _lastReunionAt[remoteId] ?? _lastResonanceAt[remoteId];
  if (last == null) return true;
  
  // 前回の共鳴/再会から15分以上経過している
  return at.difference(last) >= _reencounterCooldown;  // 15分
}
```

---

## 7. DM送信条件

```dart
bool canSendDM(String remoteId) {
  final encounter = _encountersByRemoteId[remoteId];
  if (encounter == null) return false;
  
  // 条件1: 相互いいね
  final iLikedThem = encounter.liked;
  final theyLikedMe = _notificationManager?.hasLikedMe(remoteId) ?? false;
  if (iLikedThem && theyLikedMe) return true;
  
  // 条件2: 共鳴状態（共有ハッシュタグ + 近接）
  if (_resonanceHighlights.containsKey(remoteId)) return true;
  
  // 条件3: 相互フォロー
  final iFollowThem = encounter.profile.following;
  final theyFollowMe = _notificationManager?.hasFollowedMe(remoteId) ?? false;
  if (iFollowThem && theyFollowMe) return true;
  
  return false;
}
```

---

## 8. 距離計算の詳細

### 8.1 GPS距離計算

```dart
// Geolocatorパッケージを使用
double distance = Geolocator.distanceBetween(
  lat1, lng1,  // 自分の位置
  lat2, lng2,  // 相手の位置
);
// 返り値: メートル単位の距離
```

### 8.2 BLE距離推定

```dart
double _estimateDistance(int rssi) {
  const measuredPower = -59;    // 1mでの典型的なRSSI
  const pathLossExponent = 2.0; // 環境に応じた定数
  
  // RSSI-距離変換公式
  final ratio = (measuredPower - rssi) / (10 * pathLossExponent);
  final distance = pow(10, ratio);
  
  // 異常値チェック
  if (distance.isNaN || distance.isInfinite) {
    return 10;  // デフォルト値
  }
  
  // 0.1m〜10mにクランプ
  return distance.clamp(0.1, 10.0);
}
```

**RSSI別推定距離**:
| RSSI | 推定距離 |
|------|---------|
| -59 dBm | 1.0m |
| -69 dBm | 約3.2m |
| -79 dBm | 10m（上限） |
| -49 dBm | 約0.32m |

### 8.3 距離の優先順位

```dart
double? _resolveProximityDistance({
  double? gpsDistanceMeters,
  double? bleDistanceMeters,
}) {
  // Webでない & BLE距離がある → BLE優先
  if (!kIsWeb && bleDistanceMeters != null && bleDistanceMeters.isFinite) {
    return bleDistanceMeters;
  }
  // GPS距離がある → GPS使用
  if (gpsDistanceMeters != null && gpsDistanceMeters.isFinite) {
    return gpsDistanceMeters;
  }
  return null;
}
```

---

## 9. データの永続化

### 9.1 SharedPreferences

```dart
// デバイスID
const prefsDeviceIdKey = 'streetpass_device_id';
// UUID v4形式で保存
```

### 9.2 Firestore コレクション

**streetpass_presences/{deviceId}**:
```json
{
  "profile": {
    "id": "device-id",
    "displayName": "表示名",
    "beaconId": "beacon-id",
    "avatarColor": 4283215696,
    "avatarImageBase64": "...",
    "favoriteGames": ["#tag1", "#tag2"],
    ...
  },
  "lat": 35.6762,
  "lng": 139.6503,
  "lastUpdatedMs": 1704067200000,
  "active": true
}
```

---

## 10. エラーハンドリング

### 10.1 位置情報権限エラー

```dart
throw StreetPassPermissionDenied('位置情報へのアクセスが許可されていません。');
throw StreetPassException('位置情報サービスが無効です。デバイスの設定を確認してください。');
throw StreetPassException('位置情報が取得できませんでした。GPSを有効にして再起動してください。');
```

### 10.2 BLE権限エラー

```dart
throw StreetPassException('BLE近接を利用するために、設定画面で位置情報を有効にしてください。');
throw StreetPassException('Bluetoothのスキャンの許可が必要です。ダイアログで許可してください。');
throw StreetPassException('Bluetoothとの接続の許可が必要です。ダイアログで許可してください。');
throw StreetPassException('Bluetoothの広告の許可が必要です。ダイアログで許可してください。');
```

---

## 11. プラットフォーム固有の挙動

### 11.1 Webプラットフォーム

- BLEは使用不可（`kIsWeb`チェック）
- 振動は発生しない
- 位置情報のみで検出
- `getLastKnownPosition()`は使用不可

### 11.2 Android

- すべての機能が利用可能
- BLEスキャンモード: lowLatency
- アドバタイズモード: lowLatency, txPowerHigh

### 11.3 iOS

- BLEのバックグラウンド動作に制限あり
- 一部の振動パターンはサポートされない場合あり

---

## 12. フローチャート（振動判定）

```
すれちがい検出
    │
    ▼
┌─────────────────────┐
│ Webプラットフォーム？ │
└─────────┬───────────┘
          │
         Yes → BLE関連を無効化
          │
          ▼
┌─────────────────────┐
│ 抑制リストに含まれる？ │
└─────────┬───────────┘
          │
         Yes → 振動しない
          │
          ▼
┌─────────────────────┐
│ 共有ハッシュタグあり？ │
│ (プロフィール+投稿)   │
└─────────┬───────────┘
          │
         No → 振動しない
          │
          ▼
┌─────────────────────────┐
│ 距離が閾値内？          │
│ GPS: 10m以内           │
│ BLE: 4.5m以内          │
└─────────┬───────────────┘
          │
         No → 振動しない
          │
          ▼
┌─────────────────────────┐
│ クールダウン経過？       │
│ 3m以下: 5秒            │
│ 10m以上: 30秒          │
│ その間: 線形補間        │
└─────────┬───────────────┘
          │
         No → 振動しない
          │
          ▼
┌─────────────────────┐
│      振動実行！       │
│ 400ms, amplitude=255 │
│ + システムクリック音  │
└─────────────────────┘
```

---

このドキュメントは、Vib SNSのすれちがい検出とバイブレーション機能のすべての実装詳細を網羅しています。
