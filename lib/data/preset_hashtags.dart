/// ハッシュタグカテゴリを表すクラス
class HashtagCategory {
  const HashtagCategory({
    required this.icon,
    required this.tags,
  });

  final String icon;
  final List<String> tags;
}

/// カテゴリ別ハッシュタグ
const Map<String, HashtagCategory> hashtagCategories = {
  'エンタメ': HashtagCategory(
    icon: '🎵',
    tags: [
      '#音楽',
      '#映画',
      '#アニメ',
      '#ゲーム',
      '#漫画',
      '#ボードゲーム',
      '#カードゲーム',
      '#レトロゲーム',
      '#VR',
      '#メタバース',
      '#配信',
      '#ゲーム配信',
      '#ライブ',
      '#フェス',
      '#コスプレ',
    ],
  ),
  'ライフスタイル': HashtagCategory(
    icon: '☕',
    tags: [
      '#カフェ',
      '#料理',
      '#スイーツ',
      '#コーヒー',
      '#紅茶',
      '#グルメ',
      '#ラーメン',
      '#寿司',
      '#焼肉',
      '#中華',
      '#カレー',
      '#パン',
      '#スープ',
      '#モーニング',
      '#自炊',
      '#レシピ',
      '#ファッション',
      '#コスメ',
      '#インテリア',
    ],
  ),
  'アクティビティ': HashtagCategory(
    icon: '🏃',
    tags: [
      '#スポーツ',
      '#筋トレ',
      '#ランニング',
      '#自転車',
      '#ハイキング',
      '#旅',
      '#温泉',
      '#サウナ',
      '#散歩',
      '#ドライブ',
      '#キャンプ',
      '#海',
      '#山',
    ],
  ),
  'テクノロジー': HashtagCategory(
    icon: '💻',
    tags: [
      '#テック',
      '#プログラミング',
      '#ガジェット',
      '#AI',
      '#デザイン',
      '#動画編集',
      '#リモートワーク',
    ],
  ),
  'クリエイティブ': HashtagCategory(
    icon: '🎨',
    tags: [
      '#アート',
      '#写真',
      '#写真撮影',
      '#イラスト',
      '#DIY',
      '#クラフト',
      '#手芸',
      '#アクセサリー',
    ],
  ),
  '自然・ウェルネス': HashtagCategory(
    icon: '🌿',
    tags: [
      '#自然',
      '#花',
      '#フラワー',
      '#観葉植物',
      '#ガーデニング',
      '#星空',
      '#夜景',
      '#ペット',
      '#猫',
      '#犬',
      '#ヨガ',
      '#瞑想',
      '#マインドフルネス',
      '#朝活',
      '#夜活',
    ],
  ),
  'コミュニティ': HashtagCategory(
    icon: '👥',
    tags: [
      '#共鳴',
      '#仕事',
      '#勉強',
      '#語学',
      '#英語',
      '#読書',
      '#スタートアップ',
      '#マーケティング',
      '#コーチング',
      '#子育て',
      '#家族',
      '#恋愛',
      '#友達',
      '#コミュニティ',
      '#福祉',
      '#ボランティア',
      '#エコ',
      '#サステナブル',
      '#副業',
      '#投資',
      '#節約',
      '#占い',
    ],
  ),
};

/// 全カテゴリの順序を定義
const List<String> categoryOrder = [
  'エンタメ',
  'ライフスタイル',
  'アクティビティ',
  'テクノロジー',
  'クリエイティブ',
  '自然・ウェルネス',
  'コミュニティ',
];

/// 後方互換性のためのフラットリスト
List<String> get presetHashtags {
  final tags = <String>[];
  for (final categoryName in categoryOrder) {
    final category = hashtagCategories[categoryName];
    if (category != null) {
      tags.addAll(category.tags);
    }
  }
  return tags;
}
