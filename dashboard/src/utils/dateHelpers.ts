import { Timestamp } from 'firebase/firestore';

/**
 * Firestoreの日付フィールドをDateオブジェクトに安全に変換
 * Timestamp、文字列、数値（ミリ秒）、またはDateオブジェクトを処理
 */
export const safeToDate = (value: any): Date | null => {
  if (!value) {
    return null;
  }

  // すでにDateオブジェクトの場合
  if (value instanceof Date) {
    return value;
  }

  // Firestore Timestampの場合
  if (value && typeof value.toDate === 'function') {
    try {
      return value.toDate();
    } catch (error) {
      console.warn('toDate()変換エラー:', error);
      return null;
    }
  }

  // 数値（ミリ秒タイムスタンプ）の場合
  if (typeof value === 'number') {
    return new Date(value);
  }

  // 文字列の場合
  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!isNaN(parsed.getTime())) {
      return parsed;
    }
  }

  // Timestampオブジェクト（secondsとnanosecondsプロパティがある場合）
  if (value && typeof value === 'object' && 'seconds' in value) {
    try {
      const timestamp = Timestamp.fromMillis(value.seconds * 1000 + (value.nanoseconds || 0) / 1000000);
      return timestamp.toDate();
    } catch (error) {
      console.warn('Timestamp変換エラー:', error);
    }
  }

  console.warn('日付変換に失敗:', value, typeof value);
  return null;
};

/**
 * 日付フィールドをDateに変換、失敗した場合は現在の日付を返す
 */
export const safeToDateOrDefault = (value: any, defaultValue: Date = new Date()): Date => {
  const date = safeToDate(value);
  return date || defaultValue;
};

