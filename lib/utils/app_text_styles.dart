import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Web版での日本語レンダリング問題を解決するTextStyleユーティリティ
///
/// Flutter WebのCanvasKitでは日本語フォントが正しく読み込まれず、
/// 特定の漢字（例：「間」）の線が欠けることがあります。
/// Noto Sans JPを明示的に使用することで解決します。
class AppTextStyles {
  AppTextStyles._();

  /// 共有ボタン用のタイトルスタイル（ホーム画面）
  static TextStyle get shareButtonTitle {
    if (kIsWeb) {
      return GoogleFonts.notoSansJp(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      );
    }
    return const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
  }

  /// マップ版共有ボタン用
  static TextStyle get mapShareButtonTitle {
    if (kIsWeb) {
      return GoogleFonts.notoSansJp(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      );
    }
    return const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    );
  }
}
