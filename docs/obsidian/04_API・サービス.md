# API・サービス

## StreetPassService（抽象API）
- 目的: すれちがい検出の中核APIを統一
- 入力: `start(Profile localProfile)` でローカルプロフィール
- 出力: `encounterStream` で `StreetPassEncounterData` を配信
- 例外: `StreetPassException`, `StreetPassPermissionDenied`

### StreetPassEncounterData
- remoteId: 相手ユーザーID
- profile: 相手プロフィール
- beaconId: BLEビーコンID
- encounteredAt: 検出時刻
- gpsDistanceMeters: GPS距離
- message/latitude/longitude: 任意情報

## FirestoreStreetPassService（本番実装）
- 目的: Firestore上のpresenceを更新/監視して近距離ユーザーを検出
- 使用コレクション: `streetpass_presences`
- 主要フロー:
  - `start` 時に位置権限確認 + 端末ID生成（SharedPreferences）
  - 位置更新ごとにpresenceを更新
  - 5秒間隔で周辺presenceをスキャン
  - presence変更のリアルタイム監視で再評価
- 判定ルール:
  - `lastUpdatedMs` が一定時間以内（デフォルト10分）
  - GPS距離が一定以内（デフォルト100m）
  - 同一相手の連続検出は30秒クールダウン
- 例外:
  - 位置権限なし/位置サービス無効で `StreetPassPermissionDenied`

## MockStreetPassService（モック実装）
- 目的: Firebaseが使えない環境でダミーのすれちがいを生成
- 動作:
  - 5秒間隔でサンプルプロフィールを順次発行
  - 6件分のサンプルが終わると停止

## BleProximityScanner（BLE近接判定）
- 目的: BLEビーコンで近接をさらに厳密化
- 実装: `BleProximityScannerImpl`
- 挙動:
  - 自端末のビーコンを広告
  - 対象ビーコンIDのみスキャン
  - RSSIから距離推定し `BleProximityHit` を配信

## 参照
- [[03_データモデル]]
- [[05_画面仕様]]
- [[07_条件・ルール]]
