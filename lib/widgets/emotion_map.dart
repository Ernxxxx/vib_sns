import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/emotion_post.dart';
import '../state/emotion_map_manager.dart';
import '../state/profile_controller.dart';
import '../utils/color_extensions.dart';

class EmotionMap extends StatefulWidget {
  const EmotionMap({super.key});

  @override
  State<EmotionMap> createState() => _EmotionMapState();
}

const LatLng _defaultCenter = LatLng(35.681236, 139.767125);

const Map<String, List<String>> _botMemosByEmotion = {
  'happy': [
    '散歩中に犬に会えた！',
    'カフェのケーキが最高だった',
    '久しぶりに友達と会えた',
    '良い天気で気分いい',
    '素敵な場所を見つけた',
    '今日はいい日だ',
  ],
  'sad': [
    '雨降ってきちゃった',
    '電車乗り過ごした...',
    '財布忘れて取りに戻った',
    'なんだか寂しい気分',
    '疲れたなぁ',
    '気分が沈む',
  ],
};

const double _memoMinInnerWidth = 40;
const double _memoMaxInnerWidth = 360;
const double _memoWidthStep = 18;

const List<_BotStaticSpot> _botStaticSpots = [
  _BotStaticSpot(
    id: 'tokyo_dome',
    center: LatLng(35.705639, 139.751891),
    radiusMeters: 350,
    count: 30,
    happyProbability: 0.95,
    happyMemoPool: [
      'ライブの余韻で胸いっぱい！',
      'アンコールで泣いた…最高すぎる',
      '推しのペンライト振りまくった',
      '東京ドームの熱気がまだ残ってる',
      '次のドーム公演も絶対来る！',
    ],
    sadMemoPool: [
      'ライブロスで心がぽっかり…',
      'チケット落選の通知つらい',
      '終電逃して帰れないかも',
      '次のドームまで長い…寂しい',
    ],
  ),
  _BotStaticSpot(
    id: 'tokyo_big_sight',
    center: LatLng(35.6298, 139.7976),
    radiusMeters: 350,
    count: 30,
    happyProbability: 0.95,
    happyMemoPool: [
      'コミケ戦利品がリュックから溢れそう',
      'ビッグサイトの展示おもしろすぎ',
      '企業ブースの限定グッズに並んだ！',
      '国際展示場、今日も人が多い',
      '次のイベントもビッグサイトかな',
    ],
    sadMemoPool: [
      'お目当て完売してて涙…',
      '入場待機列の暑さにやられた',
      'ビッグサイト遠くて体力ギリギリ',
      'サークル落ちちゃって凹んでる',
    ],
  ),
  _BotStaticSpot(
      id: 'chiyoda',
      center: LatLng(35.694, 139.753),
      radiusMeters: 800,
      count: 9,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'chuo',
      center: LatLng(35.6704, 139.772),
      radiusMeters: 800,
      count: 9,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'minato',
      center: LatLng(35.6581, 139.7516),
      radiusMeters: 900,
      count: 9,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'shinjuku',
      center: LatLng(35.6938, 139.7034),
      radiusMeters: 900,
      count: 9,
      happyProbability: 0.88),
  _BotStaticSpot(
      id: 'bunkyo',
      center: LatLng(35.7175, 139.7517),
      radiusMeters: 650,
      count: 8,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'taito',
      center: LatLng(35.7121, 139.7807),
      radiusMeters: 750,
      count: 8,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'sumida',
      center: LatLng(35.7100, 139.8016),
      radiusMeters: 750,
      count: 8,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'koto',
      center: LatLng(35.6730, 139.8174),
      radiusMeters: 1000,
      count: 9,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'shinagawa',
      center: LatLng(35.6093, 139.7300),
      radiusMeters: 900,
      count: 8,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'meguro',
      center: LatLng(35.6412, 139.6980),
      radiusMeters: 700,
      count: 8,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'ota',
      center: LatLng(35.5614, 139.7160),
      radiusMeters: 1200,
      count: 9,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'setagaya',
      center: LatLng(35.6467, 139.6530),
      radiusMeters: 1200,
      count: 9,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'shibuya',
      center: LatLng(35.6617, 139.7041),
      radiusMeters: 700,
      count: 8,
      happyProbability: 0.88),
  _BotStaticSpot(
      id: 'nakano',
      center: LatLng(35.7074, 139.6636),
      radiusMeters: 750,
      count: 6,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'suginami',
      center: LatLng(35.6995, 139.6360),
      radiusMeters: 1000,
      count: 8,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'toshima',
      center: LatLng(35.7289, 139.7101),
      radiusMeters: 750,
      count: 6,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'kita',
      center: LatLng(35.7528, 139.7330),
      radiusMeters: 950,
      count: 6,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'arakawa',
      center: LatLng(35.7365, 139.7830),
      radiusMeters: 800,
      count: 6,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'itabashi',
      center: LatLng(35.7512, 139.7101),
      radiusMeters: 1000,
      count: 6,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'nerima',
      center: LatLng(35.7356, 139.6522),
      radiusMeters: 1200,
      count: 8,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'adachi',
      center: LatLng(35.7743, 139.8040),
      radiusMeters: 1200,
      count: 8,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'katsushika',
      center: LatLng(35.7433, 139.8470),
      radiusMeters: 1200,
      count: 8,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'edogawa',
      center: LatLng(35.7061, 139.8683),
      radiusMeters: 1300,
      count: 8,
      happyProbability: 0.85),
  // 神奈川
  _BotStaticSpot(
      id: 'yokohama',
      center: LatLng(35.465, 139.622),
      radiusMeters: 1300,
      count: 30,
      happyProbability: 0.9),
  _BotStaticSpot(
      id: 'kawasaki',
      center: LatLng(35.530, 139.703),
      radiusMeters: 1100,
      count: 21,
      happyProbability: 0.88),
  _BotStaticSpot(
      id: 'yokosuka',
      center: LatLng(35.281, 139.672),
      radiusMeters: 950,
      count: 12,
      happyProbability: 0.82),
  _BotStaticSpot(
      id: 'kamakura',
      center: LatLng(35.319, 139.546),
      radiusMeters: 850,
      count: 11,
      happyProbability: 0.86),
  _BotStaticSpot(
      id: 'hiratsuka',
      center: LatLng(35.327, 139.349),
      radiusMeters: 900,
      count: 12,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'hakone',
      center: LatLng(35.232, 139.105),
      radiusMeters: 800,
      count: 9,
      happyProbability: 0.78),
  // 埼玉
  _BotStaticSpot(
      id: 'saitama',
      center: LatLng(35.8617, 139.6455),
      radiusMeters: 1100,
      count: 21,
      happyProbability: 0.88),
  _BotStaticSpot(
      id: 'omiya',
      center: LatLng(35.9061, 139.6237),
      radiusMeters: 850,
      count: 18,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'kawagoe',
      center: LatLng(35.9251, 139.4850),
      radiusMeters: 800,
      count: 11,
      happyProbability: 0.82),
  // 千葉
  _BotStaticSpot(
      id: 'chiba',
      center: LatLng(35.6073, 140.1063),
      radiusMeters: 1200,
      count: 21,
      happyProbability: 0.87),
  _BotStaticSpot(
      id: 'funabashi',
      center: LatLng(35.6940, 139.9820),
      radiusMeters: 900,
      count: 15,
      happyProbability: 0.86),
  _BotStaticSpot(
      id: 'kashiwa',
      center: LatLng(35.8629, 139.9726),
      radiusMeters: 850,
      count: 14,
      happyProbability: 0.84),
  _BotStaticSpot(
      id: 'matsudo',
      center: LatLng(35.7799, 139.9030),
      radiusMeters: 850,
      count: 14,
      happyProbability: 0.84),
  // 茨城
  _BotStaticSpot(
      id: 'tsukuba',
      center: LatLng(36.0820, 140.1100),
      radiusMeters: 950,
      count: 14,
      happyProbability: 0.83),
  _BotStaticSpot(
      id: 'mito',
      center: LatLng(36.3659, 140.4716),
      radiusMeters: 1000,
      count: 14,
      happyProbability: 0.82),
  // 栃木
  _BotStaticSpot(
      id: 'utsunomiya',
      center: LatLng(36.5551, 139.8828),
      radiusMeters: 950,
      count: 14,
      happyProbability: 0.83),
  _BotStaticSpot(
      id: 'nikko',
      center: LatLng(36.7199, 139.6982),
      radiusMeters: 850,
      count: 9,
      happyProbability: 0.8),
  // 群馬
  _BotStaticSpot(
      id: 'maebashi',
      center: LatLng(36.3890, 139.0630),
      radiusMeters: 950,
      count: 12,
      happyProbability: 0.82),
  _BotStaticSpot(
      id: 'takasaki',
      center: LatLng(36.3220, 139.0120),
      radiusMeters: 900,
      count: 12,
      happyProbability: 0.82),
  // 追加スポット（関東広域）
  _BotStaticSpot(
      id: 'sagamihara',
      center: LatLng(35.5710, 139.3730),
      radiusMeters: 1050,
      count: 18,
      happyProbability: 0.86),
  _BotStaticSpot(
      id: 'fujisawa',
      center: LatLng(35.3380, 139.4870),
      radiusMeters: 900,
      count: 15,
      happyProbability: 0.86),
  _BotStaticSpot(
      id: 'chigasaki',
      center: LatLng(35.3364, 139.4080),
      radiusMeters: 850,
      count: 12,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'odawara',
      center: LatLng(35.2550, 139.1590),
      radiusMeters: 900,
      count: 12,
      happyProbability: 0.82),
  _BotStaticSpot(
      id: 'atsugi',
      center: LatLng(35.4425, 139.3690),
      radiusMeters: 850,
      count: 11,
      happyProbability: 0.84),
  _BotStaticSpot(
      id: 'tokorozawa',
      center: LatLng(35.7990, 139.4690),
      radiusMeters: 900,
      count: 14,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'kawaguchi',
      center: LatLng(35.8070, 139.7240),
      radiusMeters: 850,
      count: 15,
      happyProbability: 0.86),
  _BotStaticSpot(
      id: 'koshigaya',
      center: LatLng(35.8910, 139.7900),
      radiusMeters: 850,
      count: 12,
      happyProbability: 0.84),
  _BotStaticSpot(
      id: 'soka',
      center: LatLng(35.8250, 139.8050),
      radiusMeters: 820,
      count: 11,
      happyProbability: 0.83),
  _BotStaticSpot(
      id: 'narita',
      center: LatLng(35.7760, 140.3180),
      radiusMeters: 950,
      count: 12,
      happyProbability: 0.84),
  _BotStaticSpot(
      id: 'kisarazu',
      center: LatLng(35.3730, 139.9160),
      radiusMeters: 900,
      count: 12,
      happyProbability: 0.85),
  _BotStaticSpot(
      id: 'choshi',
      center: LatLng(35.7340, 140.8260),
      radiusMeters: 850,
      count: 9,
      happyProbability: 0.8),
  _BotStaticSpot(
      id: 'hitachi',
      center: LatLng(36.5960, 140.6510),
      radiusMeters: 900,
      count: 11,
      happyProbability: 0.8),
  _BotStaticSpot(
      id: 'kashima',
      center: LatLng(35.9650, 140.6390),
      radiusMeters: 900,
      count: 11,
      happyProbability: 0.8),
  _BotStaticSpot(
      id: 'oyama',
      center: LatLng(36.3130, 139.8000),
      radiusMeters: 900,
      count: 11,
      happyProbability: 0.82),
  _BotStaticSpot(
      id: 'ashikaga',
      center: LatLng(36.3140, 139.4550),
      radiusMeters: 850,
      count: 9,
      happyProbability: 0.82),
  _BotStaticSpot(
      id: 'kiryu',
      center: LatLng(36.4050, 139.3300),
      radiusMeters: 850,
      count: 9,
      happyProbability: 0.82),
  _BotStaticSpot(
      id: 'isesaki',
      center: LatLng(36.3220, 139.1930),
      radiusMeters: 850,
      count: 9,
      happyProbability: 0.82),
  // 追加の悲しいスポット（集中度高め）
  _BotStaticSpot(
      id: 'yokohama_sad',
      center: LatLng(35.465, 139.622),
      radiusMeters: 900,
      count: 39, // 25+狙い
      happyProbability: 0.55,
      sadMemoPool: ['ライブ終わりでロス…', '海風が冷たい', '乗り換えミスで遅刻しそう']),
  _BotStaticSpot(
      id: 'shibuya_sad',
      center: LatLng(35.6617, 139.7041),
      radiusMeters: 750,
      count: 45, // 25+狙い
      happyProbability: 0.5,
      sadMemoPool: ['人混みでぐったり', '終電逃した…', '雨でびしょ濡れ']),
  _BotStaticSpot(
      id: 'ikebukuro_sad',
      center: LatLng(35.7289, 139.7101),
      radiusMeters: 800,
      count: 38, // 25+狙い
      happyProbability: 0.5,
      sadMemoPool: ['イベント落選した…', '荷物が重すぎて肩が痛い', '並び疲れた']),
  _BotStaticSpot(
      id: 'takasaki_sad',
      center: LatLng(36.3220, 139.0120),
      radiusMeters: 850,
      count: 38,
      happyProbability: 0.55,
      sadMemoPool: ['寒くてつらい', '道に迷った', '予定がキャンセルに…']),
  _BotStaticSpot(
      id: 'mito_sad',
      center: LatLng(36.3659, 140.4716),
      radiusMeters: 900,
      count: 38,
      happyProbability: 0.55,
      sadMemoPool: ['雨で観光断念', '帰りの特急が遅延', 'お目当ての店が閉まってた']),
  _BotStaticSpot(
      id: 'kisarazu_sad',
      center: LatLng(35.3730, 139.9160),
      radiusMeters: 850,
      count: 27,
      happyProbability: 0.5,
      sadMemoPool: ['フェリー欠航で足止め', '渋滞で海岸まで行けなかった', '潮風で寒い…']),
  _BotStaticSpot(
      id: 'narita_sad',
      center: LatLng(35.7760, 140.3180),
      radiusMeters: 900,
      count: 27,
      happyProbability: 0.5,
      sadMemoPool: ['フライト遅延', '免税店がお休みだった', '空港までの道が大渋滞']),
  _BotStaticSpot(
      id: 'tsukuba_sad',
      center: LatLng(36.0820, 140.1100),
      radiusMeters: 900,
      count: 27,
      happyProbability: 0.55,
      sadMemoPool: ['実験が失敗…', '会議が長引いた', 'バスに乗り遅れた']),
  _BotStaticSpot(
      id: 'umi_hita_sad',
      center: LatLng(35.7340, 140.8260),
      radiusMeters: 900,
      count: 11,
      happyProbability: 0.6,
      sadMemoPool: ['強風で撮影断念', '電車が止まった', '海が荒れてる']),
  // 大規模悲しいクラスタ（例: 千葉の事故渋滞）
  _BotStaticSpot(
      id: 'chiba_accident_sad',
      center: LatLng(35.6073, 140.1063),
      radiusMeters: 1200,
      count: 90,
      happyProbability: 0.4,
      sadMemoPool: [
        '事故で大渋滞…',
        '電車が遅延してる',
        '通行止めで足止め',
        '予定に間に合わない',
        '信号待ちが長すぎる'
      ]),
  _BotStaticSpot(
      id: 'funabashi_sad',
      center: LatLng(35.6940, 139.9820),
      radiusMeters: 900,
      count: 39,
      happyProbability: 0.5,
      sadMemoPool: ['踏切が開かない', '総武線が遅延', '渋滞で帰れない']),
  _BotStaticSpot(
      id: 'choshi_sad_cluster',
      center: LatLng(35.7340, 140.8260),
      radiusMeters: 950,
      count: 39,
      happyProbability: 0.5,
      sadMemoPool: ['強風で電車が止まった', '海が荒れて漁ができない', '観光船が欠航']),
  _BotStaticSpot(
      id: 'kawasaki_sad',
      center: LatLng(35.530, 139.703),
      radiusMeters: 950,
      count: 39,
      happyProbability: 0.5,
      sadMemoPool: ['工場夜景が見られなかった', 'バス遅延で遅刻', '雨でイベント中止']),
  _BotStaticSpot(
      id: 'saitama_sad',
      center: LatLng(35.8617, 139.6455),
      radiusMeters: 1000,
      count: 39,
      happyProbability: 0.5,
      sadMemoPool: ['大宮までの電車が遅延', '試合が中止になった', '渋滞で帰宅できない']),
];

const double _clusterZoomThreshold = 14.0;
const int _clusterMinDenseCount = 5; // 小さい固まりもまとめて重なりを減らす
const double _clusterMinCellSizeDegrees = 0.004;
const double _clusterMaxCellSizeDegrees = 0.08; // さらに広く集約してズームアウト時に進化しやすく
const double _clusterJitterFraction = 0.0; // ジッターなしで海側へのズレを抑える

const List<_ClusterStamp> _happyClusterStamps = [
  _ClusterStamp(
    minCount: 100, // Evolution Threshold raised to 100
    label: '花が満開',
    emoji: '🌸',
    color: Color(0xFFE91E63),
    sizeFactor: 1.25, // Slightly larger
    isSad: false,
  ),
  _ClusterStamp(
    minCount: 25,
    label: '一輪の花',
    emoji: '🌼',
    color: Color(0xFFF7B801),
    sizeFactor: 1.05,
    isSad: false,
  ),
  _ClusterStamp(
    minCount: 25,
    label: '一輪の花',
    emoji: '🌼',
    color: Color(0xFFF7B801),
    sizeFactor: 1.05,
    isSad: false,
  ),
  _ClusterStamp(
    minCount: 10,
    label: '花の芽',
    emoji: '🌱',
    color: Color(0xFF4CAF50),
    sizeFactor: 0.95,
    isSad: false,
  ),
];

const List<_ClusterStamp> _sadClusterStamps = [
  _ClusterStamp(
    minCount: 100, // Evolution Threshold raised to 100
    label: 'ラフレシア',
    emoji: '🌺',
    color: Color(0xFF5A0F6A),
    sizeFactor: 1.25,
    isSad: true,
  ),
  _ClusterStamp(
    minCount: 25,
    label: '枯れた花',
    emoji: '🥀',
    color: Color(0xFF8D6E63),
    sizeFactor: 1.05,
    isSad: true,
  ),
  _ClusterStamp(
    minCount: 25,
    label: '枯れた花',
    emoji: '🥀',
    color: Color(0xFF8D6E63),
    sizeFactor: 1.05,
    isSad: true,
  ),
  _ClusterStamp(
    minCount: 10,
    label: '花びらが散った花',
    emoji: '🍂',
    color: Color(0xFF9E9E9E),
    sizeFactor: 0.95,
    isSad: true,
  ),
];

class _EmotionMapState extends State<EmotionMap> {
  final MapController _mapController = MapController();
  final Random _random = Random(1337);
  bool _mapReady = false;
  bool _isLocating = false;
  bool _isPosting = false;
  bool _centeredOnUserOnce = false;
  bool _isMapMoving = false;
  bool _hasAutoFitted = false;
  LatLng? _userLocation;
  String _lastPostSignature = '';
  String _lastClusterSignature = '';
  _ClusterResult _cachedClusterResult = _ClusterResult.empty();
  StreamSubscription<MapEvent>? _mapEventSub;
  double _currentZoom = 14;
  List<EmotionMapPost> _botPosts = const [];
  Timer? _botMemoTimer;
  Set<String> _visibleBotMemoIds = <String>{};
  Timer? _memoUpdateDebounce;

  @override
  void initState() {
    super.initState();
    _mapEventSub = _mapController.mapEventStream.listen((event) {
      final zoom = event.camera.zoom;
      if (zoom.isNaN) return;

      // マップの移動開始を検知
      if (event is MapEventMoveStart ||
          event is MapEventDoubleTapZoomStart ||
          event is MapEventFlingAnimationStart) {
        if (!_isMapMoving) {
          if (mounted) {
            setState(() {
              _isMapMoving = true;
            });
          } else {
            _isMapMoving = true;
          }
        }
        _memoUpdateDebounce?.cancel();
      }

      // ズーム値の更新
      if (mounted) {
        setState(() {
          _currentZoom = zoom;
        });
      } else {
        _currentZoom = zoom;
      }

      // マップの移動終了を検知してからコメント表示を更新
      if (event is MapEventMoveEnd ||
          event is MapEventFlingAnimationEnd ||
          event is MapEventDoubleTapZoomEnd) {
        // 少し遅延させてから更新（連続したイベントをまとめる）
        _memoUpdateDebounce?.cancel();
        _memoUpdateDebounce = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isMapMoving = false;
            });
            _rotateBotMemoVisibility();
          } else {
            _isMapMoving = false;
          }
        });
      }
    });
    _botMemoTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        // マップが静止している時だけ更新
        if (!_isMapMoving) {
          _rotateBotMemoVisibility();
        }
      },
    );
  }

  @override
  void dispose() {
    _mapEventSub?.cancel();
    _botMemoTimer?.cancel();
    _memoUpdateDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<EmotionMapManager>();
    final posts = manager.posts;
    final userLocation = _userLocation;
    final myProfileId = context.watch<ProfileController>().profile.id;

    final baseMarkers = <Marker>[];
    final overlayMarkers = <Marker>[];
    final clusterMarkers = <Marker>[];
    final showClusters = !_isMapMoving && _currentZoom <= _clusterZoomThreshold;

    void addPostMarkers(List<EmotionMapPost> source, bool isBot) {
      for (final post in source) {
        final showMemo = _shouldShowMemo(post, isBot);
        final marker = _buildEmotionMarker(
          context,
          post,
          isBot: isBot,
          showMemo: showMemo,
          canDelete: !isBot && post.profileId == myProfileId,
        );
        (showMemo ? overlayMarkers : baseMarkers).add(marker);
      }
    }

    if (showClusters) {
      final clusterResult = _ensureClusterCache(posts, _botPosts);
      // Sort buckets: 1) by minCount (low to high), 2) sad before happy (so happy renders on top)
      final sortedBuckets = clusterResult.denseBuckets.toList()
        ..sort((a, b) {
          final stampA = _resolveClusterStamp(a);
          final stampB = _resolveClusterStamp(b);
          // First sort by minCount
          final countCompare = stampA.minCount.compareTo(stampB.minCount);
          if (countCompare != 0) return countCompare;
          // Then sad (isSad=true=1) before happy (isSad=false=0), so happy ends up LAST (on top)
          return (stampA.isSad ? 0 : 1).compareTo(stampB.isSad ? 0 : 1);
        });

      for (final cluster in sortedBuckets) {
        clusterMarkers.add(_buildClusterMarker(cluster));
      }
      final remainderUserPosts = <EmotionMapPost>[];
      final remainderBotPosts = <EmotionMapPost>[];
      for (final entry in clusterResult.remainder) {
        if (entry.isBot) {
          remainderBotPosts.add(entry.post);
        } else {
          remainderUserPosts.add(entry.post);
        }
      }
      addPostMarkers(remainderUserPosts, false);
      addPostMarkers(remainderBotPosts, true);
    } else {
      addPostMarkers(posts, false);
      addPostMarkers(_botPosts, true);
    }
    if (userLocation != null) {
      baseMarkers.add(_buildUserMarker(userLocation));
    }
    final markers = [...baseMarkers, ...overlayMarkers, ...clusterMarkers];
    final showMarkers = markers.isNotEmpty;

    if (_mapReady) {
      final signature = _signatureForPosts(posts);
      if (signature != _lastPostSignature) {
        _lastPostSignature = signature;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mapReady) {
            if (!_hasAutoFitted && _fitToContent(posts)) {
              _hasAutoFitted = true;
            }
          }
        });
      }
    } else {
      _lastPostSignature = _signatureForPosts(posts);
    }

    final initialCenter = userLocation ??
        (posts.isNotEmpty
            ? LatLng(posts.first.latitude, posts.first.longitude)
            : _defaultCenter);
    final initialZoom = userLocation != null
        ? 16.0
        : posts.isNotEmpty
            ? 14.5
            : 12.0;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            onMapReady: () {
              _mapReady = true;
              if (_fitToContent(posts)) {
                _hasAutoFitted = true;
              }
              _locateUser(initial: true);
              // 初期表示時にコメントを表示
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) {
                  setState(() {
                    _isMapMoving = false;
                  });
                  _rotateBotMemoVisibility();
                }
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.vib_sns',
            ),
            if (showMarkers) MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'emotionMap_locate',
                onPressed:
                    _isLocating ? null : () => _locateUser(initial: false),
                child: _isLocating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
              const SizedBox(height: 12),
              // Glassmorphism Button for "Share Moment"
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF2B705).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.7),
                            Colors.white.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isPosting ? null : _openAddEmotionSheet,
                          borderRadius: BorderRadius.circular(32),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isPosting)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.black87),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.black87,
                                    size: 20,
                                  ),
                                const SizedBox(width: 10),
                                const Text(
                                  '今の瞬間をシェア',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldShowMemo(EmotionMapPost post, bool isBot) {
    // マップ移動中は一切コメントを表示しない
    if (_isMapMoving) return false;
    return !isBot || _visibleBotMemoIds.contains(post.id);
  }

  Marker _buildEmotionMarker(
    BuildContext context,
    EmotionMapPost post, {
    required bool isBot,
    required bool showMemo,
    required bool canDelete,
  }) {
    final emotion = post.emotion;
    const baseWidth = 40.0;
    final scale = _markerScaleForZoom(_currentZoom);
    final visualScale = scale.clamp(0.75, 1.0);
    final circlePadding = 11.0;
    const emojiSize = 18.0;
    final circleHeight = (circlePadding * 2 + emojiSize) * scale;

    // メモ非表示のときはシンプルな円だけを中心揃えで描画し、ズレを最小化する
    if (!showMemo) {
      final size = circleHeight;
      return Marker(
        point: LatLng(post.latitude, post.longitude),
        width: size,
        height: size,
        alignment: Alignment.center,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showPostDetails(post, canDelete: canDelete),
          child: Container(
            decoration: BoxDecoration(
              color: emotion.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8 * scale,
                  offset: Offset(0, 3 * scale),
                ),
              ],
            ),
            padding: EdgeInsets.all(circlePadding * scale),
            child: Text(
              emotion.emoji,
              style: TextStyle(fontSize: emojiSize * scale),
            ),
          ),
        ),
      );
    }

    final labelStyle = TextStyle(
      fontSize: 11 * visualScale,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    const memoSpacing = 3.0;
    const memoPaddingV = 4.0;
    const memoPaddingH = 10.0;
    final memoLayout = _resolveMemoBubbleLayout(
      text: post.displayMessage,
      style: labelStyle,
      spacing: memoSpacing * scale,
      paddingVertical: memoPaddingV * scale,
      paddingHorizontal: memoPaddingH * scale,
      minInnerWidth: (_memoMinInnerWidth * scale).clamp(30, 180),
      maxInnerWidth: _memoMaxInnerWidth * scale,
      widthStep: _memoWidthStep * scale,
    );
    final bubbleOffset = circleHeight + memoSpacing * scale;
    final width = max(baseWidth * scale, memoLayout.outerWidth);
    final height = memoLayout.height + bubbleOffset + 2 * scale;

    return Marker(
      point: LatLng(post.latitude, post.longitude),
      width: width,
      height: height,
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () => _showPostDetails(post, canDelete: canDelete),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: emotion.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10 * scale,
                      offset: Offset(0, 4 * scale),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(circlePadding * scale),
                child: Text(
                  emotion.emoji,
                  style: TextStyle(fontSize: emojiSize * scale),
                ),
              ),
            ),
            Positioned(
              bottom: bubbleOffset,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: showMemo ? 1.0 : 0.0,
                curve: Curves.easeInOut,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: showMemo ? 1.0 : 0.85,
                  curve: Curves.easeOut,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: memoPaddingV * scale,
                      horizontal: memoPaddingH * scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12 * scale),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6 * scale,
                          offset: Offset(0, 2 * scale),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: memoLayout.innerWidth,
                      child: Text(
                        post.displayMessage,
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.fade,
                        style: labelStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildUserMarker(LatLng position) {
    const baseSize = 40.0;
    final scale = _markerScaleForZoom(_currentZoom);
    final size = baseSize * scale;
    final borderWidth = 2 * scale.clamp(0.7, 1.0);
    return Marker(
      point: position,
      width: size,
      height: size,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E88E5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.35),
              blurRadius: 16 * scale,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: borderWidth,
          ),
        ),
        child: Icon(
          Icons.person_pin_circle,
          color: Colors.white,
          size: 20 * scale.clamp(0.7, 1.0),
        ),
      ),
    );
  }

  Future<void> _openAddEmotionSheet() async {
    if (_isPosting) return;
    final location = await _locateUser(
      initial: false,
      moveCamera: false,
      showPromptOnError: true,
    );
    if (!mounted) return;
    if (location == null) {
      _showSnack('現在地を取得してから投稿してください。');
      return;
    }
    final result = await showModalBottomSheet<_EmotionFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Transparent for Glassmorphism
      builder: (_) => const _EmotionPostSheet(),
    );
    if (!mounted) return;
    if (result == null) {
      return;
    }
    setState(() => _isPosting = true);
    final emotionManager = context.read<EmotionMapManager>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await emotionManager.addPost(
        emotion: result.emotion,
        latitude: location.latitude,
        longitude: location.longitude,
        message: result.message,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('気持ちを投稿しました。')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('投稿に失敗しました。もう一度お試しください。')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<LatLng?> _locateUser({
    required bool initial,
    bool moveCamera = true,
    bool showPromptOnError = false,
  }) async {
    if (!_mapReady) return _userLocation;
    if (_isLocating) {
      return _userLocation;
    }
    if (initial && _centeredOnUserOnce) {
      return _userLocation;
    }
    if (mounted) {
      setState(() {
        _isLocating = true;
      });
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (showPromptOnError || !initial) {
          _showSnack('位置情報へのアクセスを許可してください。');
        }
        return null;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showPromptOnError || !initial) {
          _showSnack('位置サービスを有効にしてください。');
        }
        return null;
      }
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _userLocation = latLng;
        });
      }
      _generateBotPostsAround(latLng);
      if (moveCamera) {
        final currentZoom = _mapController.camera.zoom;
        final targetZoom =
            currentZoom.isNaN || currentZoom < 15 ? 16.0 : currentZoom;
        _mapController.move(latLng, targetZoom);
      }
      if (initial) {
        _centeredOnUserOnce = true;
      }
      return latLng;
    } catch (_) {
      if (showPromptOnError || !initial) {
        _showSnack('現在地を取得できませんでした。');
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  bool _fitToContent(List<EmotionMapPost> posts) {
    if (!_mapReady) return false;
    final points = <LatLng>[
      if (_userLocation != null) _userLocation!,
      ...posts.map((post) => LatLng(post.latitude, post.longitude)),
    ];
    if (points.isNotEmpty) {
      _generateBotPostsAround(points.first);
    }
    if (points.isEmpty) {
      _mapController.move(_defaultCenter, 12);
      return true;
    }
    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return true;
    }
    if (_pointsCollapsed(points)) {
      _mapController.move(points.first, 16);
      return true;
    }
    final bounds = LatLngBounds.fromPoints(points);
    final cameraFit = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(80),
    );
    _mapController.fitCamera(cameraFit);
    return true;
  }

  bool _pointsCollapsed(List<LatLng> points) {
    if (points.isEmpty) return true;
    final first = points.first;
    for (final point in points.skip(1)) {
      if ((point.latitude - first.latitude).abs() > 1e-5 ||
          (point.longitude - first.longitude).abs() > 1e-5) {
        return false;
      }
    }
    return true;
  }

  Future<void> _showPostDetails(EmotionMapPost post,
      {required bool canDelete}) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent, // Transparent for Glassmorphism
      builder: (context) {
        return _EmotionPostDetailSheet(
          post: post,
          canDelete: canDelete,
          onDelete: canDelete
              ? () {
                  context.read<EmotionMapManager>().removePost(post.id);
                  Navigator.of(context).pop();
                  _showSnack('投稿を削除しました。');
                }
              : null,
        );
      },
    );
  }

  Future<void> _showClusterDetails(_ClusterBucket cluster) async {
    final myProfileId = context.read<ProfileController>().profile.id;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Transparent for Glassmorphism
      builder: (context) {
        return _ClusterDetailSheet(
          cluster: cluster,
          myProfileId: myProfileId,
          onZoomIn: () {
            Navigator.of(context).pop();
            _zoomIntoCluster(cluster.center);
          },
          onPostTap: (post, isBot) {
            Navigator.of(context).pop();
            _showPostDetails(
              post,
              canDelete: !isBot && post.profileId == myProfileId,
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _signatureForPosts(List<EmotionMapPost> posts) {
    if (posts.isEmpty) {
      return '';
    }
    return posts.map((post) => post.id).join('|');
  }

  _ClusterResult _ensureClusterCache(
    List<EmotionMapPost> userPosts,
    List<EmotionMapPost> botPosts,
  ) {
    // Include zoom in signature so clusters are re-calculated when zoom changes
    final zoomBucket =
        _currentZoom.floor(); // Round to avoid too frequent recalculations
    final signature =
        '$zoomBucket|${_signatureForPosts(userPosts)}|${_signatureForPosts(botPosts)}';
    if (signature != _lastClusterSignature) {
      _cachedClusterResult = _clusterPosts(userPosts, botPosts);
      _lastClusterSignature = signature;
    }
    return _cachedClusterResult;
  }

  String _randomBotMemo(EmotionType emotion) {
    final memos = _botMemosByEmotion[emotion.id];
    if (memos == null || memos.isEmpty) {
      return '${emotion.label}な気分';
    }
    return memos[_random.nextInt(memos.length)];
  }

  void _rotateBotMemoVisibility() {
    // マップが移動中は更新しない
    if (_isMapMoving || _botPosts.isEmpty || !_mapReady) {
      return;
    }

    // 画面内に表示されているマーカーのみを取得
    final visiblePosts = _getVisiblePosts(_botPosts);
    if (visiblePosts.isEmpty) {
      _updateVisibleMemoIds(<String>{});
      return;
    }

    // 画面内のマーカーから最大5個をランダムに選択
    const maxVisible = 5;
    final shuffled = List<EmotionMapPost>.from(visiblePosts)..shuffle(_random);
    final targetCount = min(maxVisible, shuffled.length);
    final nextIds = shuffled.take(targetCount).map((post) => post.id).toSet();
    _updateVisibleMemoIds(nextIds);
  }

  List<EmotionMapPost> _getVisiblePosts(List<EmotionMapPost> posts) {
    if (!_mapReady) return [];

    final bounds = _mapController.camera.visibleBounds;
    return posts.where((post) {
      final lat = post.latitude;
      final lng = post.longitude;
      return lat >= bounds.south &&
          lat <= bounds.north &&
          lng >= bounds.west &&
          lng <= bounds.east;
    }).toList();
  }

  void _updateVisibleMemoIds(Set<String> nextIds) {
    if (setEquals(nextIds, _visibleBotMemoIds)) {
      return;
    }
    if (mounted) {
      setState(() {
        _visibleBotMemoIds = nextIds;
      });
    } else {
      _visibleBotMemoIds = nextIds;
    }
  }

  _ClusterResult _clusterPosts(
    List<EmotionMapPost> posts,
    List<EmotionMapPost> botPosts,
  ) {
    if (posts.isEmpty && botPosts.isEmpty) {
      return _ClusterResult.empty();
    }
    final allEntries = <_ClusterEntry>[
      ...posts.map((post) => _ClusterEntry(post: post, isBot: false)),
      ...botPosts.map((post) => _ClusterEntry(post: post, isBot: true)),
    ];
    final bucketSize = max(_clusterCellSizeForZoom(_currentZoom), 1e-6);
    final buckets = <String, _ClusterBucket>{};
    for (final entry in allEntries) {
      final latBucket = (entry.post.latitude / bucketSize).floor();
      final lngBucket = (entry.post.longitude / bucketSize).floor();
      final key = '$latBucket:$lngBucket';
      final bucket = buckets.putIfAbsent(key, () => _ClusterBucket(key: key));
      bucket.add(entry);
    }
    final denseBuckets = <_ClusterBucket>[];
    final remainder = <_ClusterEntry>[];
    for (final bucket in buckets.values) {
      if (bucket.count >= _clusterMinDenseCount) {
        denseBuckets.add(bucket);
      } else {
        remainder.addAll(bucket.entries);
      }
    }
    return _ClusterResult(denseBuckets: denseBuckets, remainder: remainder);
  }

  double _clusterCellSizeForZoom(double zoom) {
    // Aggressive scaling to encourage clustering + larger min size to reduce overlap
    // Base 0.15 at zoom 10 (~15km), min 0.02 (~2km) for good separation
    final size = 0.15 * pow(2, 10 - zoom);
    return size.clamp(0.02, 5.0);
  }

  Marker _buildClusterMarker(_ClusterBucket cluster) {
    final center = _clusterMarkerPosition(cluster);
    final stamp = _resolveClusterStamp(cluster);
    final scale =
        (_markerScaleForZoom(_currentZoom) * stamp.sizeFactor).clamp(0.65, 1.2);
    final bool isTopHappy = !stamp.isSad && stamp.minCount >= 100;
    final bool isTopSad = stamp.isSad && stamp.minCount >= 100;

    // Normal Stamp Logic (Visible Glass Bubble)
    if (!isTopHappy && !isTopSad) {
      final stampSize = 90.0 * scale;
      final haloSize = stampSize * 1.05;
      final baseColor = stamp.color;

      return Marker(
        point: center,
        width: haloSize,
        height: haloSize,
        alignment: Alignment.center,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showClusterDetails(cluster),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: stampSize,
                height: stampSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Solid visibility
                  color: baseColor.withValues(alpha: 0.85),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.9),
                      baseColor.withValues(alpha: 0.8),
                      baseColor.withValues(alpha: 0.6),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                  border: Border.all(
                    color: Colors.white,
                    width: 3 * scale,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.3),
                      blurRadius: 10 * scale,
                      offset: Offset(0, 4 * scale),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    stamp.emoji,
                    style: TextStyle(fontSize: 32 * scale, shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      )
                    ]),
                  ),
                ),
              ),
              // Gloss Highlight
              Positioned(
                top: stampSize * 0.1,
                left: stampSize * 0.2,
                child: Container(
                  width: stampSize * 0.35,
                  height: stampSize * 0.18,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                          Radius.elliptical(stampSize, stampSize * 0.5)),
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.8),
                            Colors.white.withValues(alpha: 0.1),
                          ])),
                ),
              )
            ],
          ),
        ),
      );
    }

    // Sad 50+ Design ("Dark Mood")
    if (isTopSad) {
      final stampSize =
          110.0 * scale; // Larger than normal, smaller than happy 50+
      final haloSize = stampSize * 1.25;

      final darkColor = const Color(0xFF455A64); // Blue Grey
      final tearColor = const Color(0xFF2196F3); // Blue for accent

      return Marker(
        point: center,
        width: haloSize,
        height: haloSize,
        alignment: Alignment.center,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showClusterDetails(cluster),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Melancholy Halo
              Container(
                width: haloSize,
                height: haloSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      darkColor.withValues(alpha: 0.5),
                      tearColor.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
              ),

              // Dark Glass Container
              Container(
                width: stampSize,
                height: stampSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: darkColor.withValues(alpha: 0.85),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF607D8B), // Lighter Blue Grey
                      Color(0xFF263238), // Dark Blue Grey
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 3 * scale,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 15 * scale,
                      offset: Offset(0, 8 * scale),
                    ),
                    BoxShadow(
                      color: tearColor.withValues(alpha: 0.3),
                      blurRadius: 20 * scale,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    stamp.emoji,
                    style: TextStyle(
                        fontSize: 40 * scale, // Prominent
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]),
                  ),
                ),
              ),

              // Raindrop/Tear Highlight
              Positioned(
                top: stampSize * 0.15,
                right: stampSize * 0.2,
                child: Icon(Icons.water_drop,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 16 * scale),
              ),
            ],
          ),
        ),
      );
    }

    // Gemini流: Happy 50+デザイン "Cosmic Bloom"
    // Statefulな専用ウィジェットを使用してアニメーションを実現
    return Marker(
      point: center,
      width: 160 * scale, // 広めのエリア確保
      height: 160 * scale,
      alignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showClusterDetails(cluster),
        child: _GeminiStyleMarker(
          scale: scale,
          emoji: stamp.emoji,
        ),
      ),
    );
  }

  void _zoomIntoCluster(LatLng target) {
    final currentZoom = _mapController.camera.zoom;
    final safeZoom = currentZoom.isNaN ? _clusterZoomThreshold : currentZoom;
    final targetZoom =
        (safeZoom + 1.8).clamp(_clusterZoomThreshold + 0.8, 17.0);
    _mapController.move(target, targetZoom);
  }

  _ClusterStamp _resolveClusterStamp(_ClusterBucket bucket) {
    // 合計人数でティアを決定し、優勢な感情でスタンプセットを選択。
    // Happyを前面に出すため、Sadが2倍以上の場合のみSadを表示
    final total = bucket.count;
    final sad = bucket.sadCount;
    final happy = bucket.happyCount;
    final isSadDominant = sad >= happy;

    List<_ClusterStamp> stamps =
        isSadDominant ? _sadClusterStamps : _happyClusterStamps;
    // 50/25/10 の閾値に総数でマッピング
    for (final stamp in stamps) {
      if (total >= stamp.minCount) return stamp;
    }
    return stamps.last;
  }

  LatLng _clusterMarkerPosition(_ClusterBucket cluster) {
    // クラスタの重心に最も近いポストの位置を使う（海に落ちにくくする）
    final base = cluster.center;
    _ClusterEntry? closest;
    double best = double.infinity;
    for (final entry in cluster.entries) {
      final dx = entry.post.latitude - base.latitude;
      final dy = entry.post.longitude - base.longitude;
      final dist2 = dx * dx + dy * dy;
      if (dist2 < best) {
        best = dist2;
        closest = entry;
      }
    }
    if (closest != null) {
      return LatLng(closest.post.latitude, closest.post.longitude);
    }
    return base;
  }

  double _markerScaleForZoom(double zoom) {
    const minZoom = 10.0;
    const maxZoom = 18.0;
    const minScale = 0.55;
    const maxScale = 1.0;
    final clampedZoom = zoom.clamp(minZoom, maxZoom);
    final t = (clampedZoom - minZoom) / (maxZoom - minZoom);
    return minScale + (maxScale - minScale) * t;
  }

  _MemoBubbleLayout _resolveMemoBubbleLayout({
    required String text,
    required TextStyle style,
    required double spacing,
    required double paddingVertical,
    required double paddingHorizontal,
    required double minInnerWidth,
    required double maxInnerWidth,
    required double widthStep,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    );
    var innerWidth = minInnerWidth;
    final maxWidth = maxInnerWidth;
    final minStep = max(widthStep, 12);
    while (true) {
      painter.layout(maxWidth: innerWidth);
      if (!painter.didExceedMaxLines || innerWidth >= maxWidth) {
        final outerWidth = innerWidth + paddingHorizontal * 2;
        final height = spacing + paddingVertical * 2 + painter.height;
        return _MemoBubbleLayout(
          outerWidth: outerWidth,
          innerWidth: innerWidth,
          height: height,
        );
      }
      innerWidth =
          min(innerWidth + minStep + _random.nextDouble() * minStep, maxWidth);
    }
  }

  void _generateBotPostsAround(LatLng origin, {bool force = false}) {
    // Bot投稿は一度生成したら固定（再生成しない）
    if (!force && _botPosts.isNotEmpty) {
      return;
    }
    const botCount = 15;
    const radiusMeters = 2000.0;
    const minSeparationMeters = 120.0;
    final bots = <EmotionMapPost>[];
    final now = DateTime.now();
    var attempts = 0;
    while (bots.length < botCount && attempts < botCount * 20) {
      attempts++;
      final distance = sqrt(_random.nextDouble()) * radiusMeters;
      final bearing = _random.nextDouble() * 2 * pi;
      final position = _offsetBy(origin, distance, bearing);
      final hasNearbyBot = bots.any(
        (existing) =>
            _distanceMeters(
              LatLng(existing.latitude, existing.longitude),
              position,
            ) <
            minSeparationMeters,
      );
      if (hasNearbyBot) {
        continue;
      }
      // 利用可能な感情は「うれしい」と「かなしい」の2種類のみ
      const availableEmotions = [EmotionType.happy, EmotionType.sad];
      final emotion =
          availableEmotions[_random.nextInt(availableEmotions.length)];
      final ageMinutes = _random.nextInt(6 * 60); // within last 6 hours
      final post = EmotionMapPost(
        id: 'bot_${now.microsecondsSinceEpoch}_${bots.length}_${_random.nextInt(1 << 16)}',
        emotion: emotion,
        latitude: position.latitude,
        longitude: position.longitude,
        createdAt: now.subtract(Duration(minutes: ageMinutes)),
        message: _randomBotMemo(emotion),
        profileId: 'bot_random',
      );
      bots.add(post);
    }
    for (final spot in _botStaticSpots) {
      _populateStaticSpotBots(
        bots: bots,
        spot: spot,
        now: now,
      );
    }
    if (mounted) {
      setState(() {
        _botPosts = bots;
      });
    } else {
      _botPosts = bots;
    }
    _rotateBotMemoVisibility();
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6378137.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final h =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return earthRadius * c;
  }

  LatLng _offsetBy(LatLng origin, double distanceMeters, double bearing) {
    const earthRadius = 6378137.0;
    final latRad = _degToRad(origin.latitude);
    final lonRad = _degToRad(origin.longitude);
    final angular = distanceMeters / earthRadius;
    final nextLat = asin(
        sin(latRad) * cos(angular) + cos(latRad) * sin(angular) * cos(bearing));
    final nextLon = lonRad +
        atan2(sin(bearing) * sin(angular) * cos(latRad),
            cos(angular) - sin(latRad) * sin(nextLat));
    return LatLng(_radToDeg(nextLat), _radToDeg(nextLon));
  }

  double _degToRad(double value) => value * pi / 180;
  double _radToDeg(double value) => value * 180 / pi;

  void _populateStaticSpotBots({
    required List<EmotionMapPost> bots,
    required _BotStaticSpot spot,
    required DateTime now,
  }) {
    var generated = 0;
    var attempts = 0;
    while (generated < spot.count && attempts < spot.count * 60) {
      attempts++;
      final baseDistance = sqrt(_random.nextDouble()) * spot.radiusMeters;
      final distanceJitter =
          (_random.nextDouble() - 0.5) * 0.45 * spot.radiusMeters;
      final distance = max(10.0, baseDistance + distanceJitter);
      final angleJitter = (_random.nextDouble() - 0.5) * 0.8;
      final bearing = _random.nextDouble() * 2 * pi;
      final position = _offsetBy(
        spot.center,
        distance,
        bearing + angleJitter,
      );
      final hasNearby = bots.any(
        (existing) =>
            _distanceMeters(
              LatLng(existing.latitude, existing.longitude),
              position,
            ) <
            20,
      );
      if (hasNearby) continue;
      final emotion = _random.nextDouble() < spot.happyProbability
          ? EmotionType.happy
          : EmotionType.sad;
      final ageMinutes = _random.nextInt(6 * 60);
      String? spotMemo;
      if (emotion == EmotionType.happy && spot.happyMemoPool != null) {
        final pool = spot.happyMemoPool!;
        if (pool.isNotEmpty) {
          spotMemo = pool[_random.nextInt(pool.length)];
        }
      } else if (emotion == EmotionType.sad && spot.sadMemoPool != null) {
        final pool = spot.sadMemoPool!;
        if (pool.isNotEmpty) {
          spotMemo = pool[_random.nextInt(pool.length)];
        }
      }
      bots.add(
        EmotionMapPost(
          id: 'bot_static_${spot.id}_${generated}_${now.microsecondsSinceEpoch}_${_random.nextInt(1 << 16)}',
          emotion: emotion,
          latitude: position.latitude,
          longitude: position.longitude,
          createdAt: now.subtract(Duration(minutes: ageMinutes)),
          message: spotMemo ?? _randomBotMemo(emotion),
          profileId: 'bot_${spot.id}',
        ),
      );
      generated++;
    }
  }
}

class _MemoBubbleLayout {
  const _MemoBubbleLayout({
    required this.outerWidth,
    required this.innerWidth,
    required this.height,
  });

  final double outerWidth;
  final double innerWidth;
  final double height;
}

class _ClusterStamp {
  const _ClusterStamp({
    required this.minCount,
    required this.label,
    required this.emoji,
    required this.color,
    required this.sizeFactor,
    required this.isSad,
  });

  final int minCount;
  final String label;
  final String emoji;
  final Color color;
  final double sizeFactor;
  final bool isSad;
}

class _ClusterEntry {
  _ClusterEntry({required this.post, required this.isBot});

  final EmotionMapPost post;
  final bool isBot;
}

class _ClusterBucket {
  _ClusterBucket({required this.key});

  final String key;
  final List<_ClusterEntry> entries = [];
  double _latSum = 0;
  double _lngSum = 0;
  int _happyCount = 0;
  int _sadCount = 0;

  void add(_ClusterEntry entry) {
    entries.add(entry);
    _latSum += entry.post.latitude;
    _lngSum += entry.post.longitude;
    final emotion = entry.post.emotion;
    if (_isHappyEmotion(emotion)) {
      _happyCount++;
    } else if (_isSadEmotion(emotion)) {
      _sadCount++;
    }
  }

  int get count => entries.length;
  int get happyCount => _happyCount;
  int get sadCount => _sadCount;

  LatLng get center {
    if (entries.isEmpty) {
      return _defaultCenter;
    }
    return LatLng(_latSum / count, _lngSum / count);
  }

  int get colorKey => key.hashCode & 0x7fffffff;
}

class _ClusterResult {
  const _ClusterResult({
    required this.denseBuckets,
    required this.remainder,
  });

  factory _ClusterResult.empty() =>
      const _ClusterResult(denseBuckets: [], remainder: []);

  final List<_ClusterBucket> denseBuckets;
  final List<_ClusterEntry> remainder;
}

bool _isHappyEmotion(EmotionType emotion) {
  return emotion == EmotionType.happy ||
      emotion == EmotionType.excited ||
      emotion == EmotionType.calm ||
      emotion == EmotionType.surprised;
}

bool _isSadEmotion(EmotionType emotion) {
  return emotion == EmotionType.sad || emotion == EmotionType.tired;
}

class _BotStaticSpot {
  const _BotStaticSpot({
    required this.id,
    required this.center,
    required this.radiusMeters,
    required this.count,
    required this.happyProbability,
    this.happyMemoPool,
    this.sadMemoPool,
  });

  final String id;
  final LatLng center;
  final double radiusMeters;
  final int count;
  final double happyProbability;
  final List<String>? happyMemoPool;
  final List<String>? sadMemoPool;
}

class _EmotionFormResult {
  _EmotionFormResult({required this.emotion, this.message});

  final EmotionType emotion;
  final String? message;
}

class _EmotionPostSheet extends StatefulWidget {
  const _EmotionPostSheet();

  @override
  State<_EmotionPostSheet> createState() => _EmotionPostSheetState();
}

class _EmotionPostSheetState extends State<_EmotionPostSheet> {
  final TextEditingController _controller = TextEditingController();
  EmotionType? _selectedEmotion = EmotionType.happy;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .scaffoldBackgroundColor
                .withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.5), width: 1),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: EdgeInsets.only(bottom: viewInsets),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight == double.infinity
                            ? 0
                            : constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '今の気持ちは？',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: const [
                                EmotionType.happy,
                                EmotionType.sad
                              ].map((emotion) {
                                final selected = _selectedEmotion == emotion;
                                return ChoiceChip(
                                  label: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 8),
                                    child: Text(
                                      '${emotion.emoji} ${emotion.label}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  selected: selected,
                                  selectedColor:
                                      emotion.color.withValues(alpha: 0.3),
                                  backgroundColor:
                                      Colors.grey.withValues(alpha: 0.1),
                                  side: BorderSide.none,
                                  onSelected: (_) {
                                    setState(() => _selectedEmotion = emotion);
                                  },
                                );
                              }).toList(growable: false),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _controller,
                            maxLength: 60,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'ひとことメモ（任意）',
                              alignLabelWithHint: true,
                              filled: true,
                              fillColor: Colors.grey.withValues(alpha: 0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _selectedEmotion == null
                                ? null
                                : () {
                                    final trimmed = _controller.text.trim();
                                    final message =
                                        trimmed.isEmpty ? null : trimmed;
                                    Navigator.of(context).pop(
                                      _EmotionFormResult(
                                        emotion: _selectedEmotion!,
                                        message: message,
                                      ),
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('投稿する',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmotionPostDetailSheet extends StatelessWidget {
  const _EmotionPostDetailSheet({
    required this.post,
    required this.canDelete,
    this.onDelete,
  });

  final EmotionMapPost post;
  final bool canDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emotion = post.emotion;
    final formattedTime = _formatTimestamp(post.createdAt);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.5), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: emotion.color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          emotion.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emotion.label,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedTime,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (canDelete)
                        IconButton.filledTonal(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: '削除',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            foregroundColor: Colors.red,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      post.displayMessage,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final local = time.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final date =
        '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)}';
    final clock =
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
    return '$date $clock';
  }
}

class _ClusterDetailSheet extends StatelessWidget {
  const _ClusterDetailSheet({
    required this.cluster,
    required this.myProfileId,
    required this.onZoomIn,
    required this.onPostTap,
  });

  final _ClusterBucket cluster;
  final String myProfileId;
  final VoidCallback onZoomIn;
  final void Function(EmotionMapPost post, bool isBot) onPostTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final posts = cluster.entries.map((e) => e.post).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final happyCount = cluster.entries
        .where((e) => e.post.emotion == EmotionType.happy)
        .length;
    final sadCount =
        cluster.entries.where((e) => e.post.emotion == EmotionType.sad).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.5), width: 1),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Column(
                      children: [
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.groups_2_rounded,
                                size: 28, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              'この地域の気持ち',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildEmotionSummary(
                                context, EmotionType.happy, happyCount),
                            const SizedBox(width: 16),
                            _buildEmotionSummary(
                                context, EmotionType.sad, sadCount),
                            const Spacer(),
                            Text(
                              '合計 ${cluster.count}人',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onZoomIn,
                            icon: const Icon(Icons.zoom_in),
                            label: const Text('ズームインして個別に見る'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: posts.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final isBot = cluster.entries
                            .firstWhere((e) => e.post.id == post.id)
                            .isBot;
                        final emotion = post.emotion;
                        final formattedTime =
                            _formatRelativeTime(post.createdAt);

                        return ListTile(
                          onTap: () => onPostTap(post, isBot),
                          leading: Container(
                            decoration: BoxDecoration(
                              color: emotion.color,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              emotion.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          title: Text(
                            post.displayMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(formattedTime),
                          trailing: const Icon(Icons.chevron_right),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmotionSummary(
      BuildContext context, EmotionType emotion, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emotion.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 4),
        Text(
          '$count人',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'たった今';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}時間前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      final local = time.toLocal();
      return '${local.month}/${local.day}';
    }
  }
}

class _GeminiStyleMarker extends StatefulWidget {
  const _GeminiStyleMarker({
    required this.scale,
    required this.emoji,
  });

  final double scale;
  final String emoji;

  @override
  State<_GeminiStyleMarker> createState() => _GeminiStyleMarkerState();
}

class _GeminiStyleMarkerState extends State<_GeminiStyleMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_GeminiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000), // 少しゆっくりに
    )..repeat();

    // Initial stars configuration
    const particleColors = [
      Color(0xFFD946EF), // Fuchsia
      Color(0xFF8B5CF6), // Violet
      Color(0xFF0EA5E9), // Sky Blue
      Color(0xFFFFD700), // Gold
      Colors.white,
    ];

    for (int i = 0; i < 12; i++) {
      _particles.add(_GeminiParticle(
        angle: _random.nextDouble() * 2 * pi,
        distance: 0.5 + _random.nextDouble() * 0.25, // radius multiplier
        speed:
            (0.2 + _random.nextDouble() * 0.4) * (_random.nextBool() ? 1 : -1),
        size: 3 + _random.nextDouble() * 5,
        color: particleColors[_random.nextInt(particleColors.length)],
        initialOpacity: 0.3 + _random.nextDouble() * 0.7,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Gemini Color Palette: Aurora Effect
    const auroraColors = [
      Color(0xFFD946EF), // Fuchsia
      Color(0xFF8B5CF6), // Violet
      Color(0xFF0EA5E9), // Sky Blue
      Color(0xFFEC4899), // Pink
    ];

    final size = 130 * widget.scale;
    final outerSize = size * 1.5; // パーティクルエリア用に少し拡大

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Pulse mapping: 0.0->0.5 (expand), 0.5->1.0 (shrink) handled by manual sin wave
        final t = _controller.value;
        final pulseVal = 0.95 + 0.1 * sin(t * 2 * pi).abs();

        return SizedBox(
          width: outerSize,
          height: outerSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Outer Glow (Pulsing)
              Transform.scale(
                scale: pulseVal,
                child: Container(
                  width: size * 1.35,
                  height: size * 1.35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        auroraColors[1].withValues(alpha: 0.4),
                        auroraColors[2].withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      stops: const [0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // Orbiting Particles
              ..._particles.map((p) {
                final currentAngle = p.angle + t * 2 * pi * p.speed;
                final r = size * p.distance * 1.2; // 距離調整
                final dx = r * cos(currentAngle);
                final dy = r * sin(currentAngle);
                // Twinkle effect
                final flicker = (sin(t * 20 * p.speed + p.angle) + 1) / 2;
                final opacity =
                    (p.initialOpacity * 0.5 + flicker * 0.5).clamp(0.0, 1.0);

                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Opacity(
                    opacity: opacity,
                    child: Icon(Icons.star,
                        color: p.color, size: p.size * widget.scale),
                  ),
                );
              }),

              // Middle Magic Ring
              Container(
                width: size * 1.15,
                height: size * 1.15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: auroraColors,
                  ),
                ),
              ),

              // Glassy Content
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: auroraColors[0].withValues(alpha: 0.3),
                      blurRadius: 15 * widget.scale,
                      offset: Offset(0, 4 * widget.scale),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Inner sparkle
                    Positioned(
                      top: size * 0.15,
                      right: size * 0.15,
                      child: Opacity(
                        opacity: 0.8,
                        child: Icon(Icons.auto_awesome,
                            color: auroraColors[2], size: 24 * widget.scale),
                      ),
                    ),
                    // Main Emoji
                    Text(
                      widget.emoji,
                      style: TextStyle(
                        fontSize: 48 * widget.scale,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    // Label Pill removed
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GeminiParticle {
  final double angle;
  final double distance;
  final double speed;
  final double size;
  final Color color;
  final double initialOpacity;

  _GeminiParticle({
    required this.angle,
    required this.distance,
    required this.speed,
    required this.size,
    required this.color,
    required this.initialOpacity,
  });
}
