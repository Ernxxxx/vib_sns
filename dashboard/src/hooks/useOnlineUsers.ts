import { useState, useEffect } from 'react';
import { collection, query, where, orderBy, limit, getDocs } from 'firebase/firestore';
import { db, auth } from '../services/firebase';

// オンライン状態のタイムアウト時間（5分）
const PRESENCE_TIMEOUT_MS = 5 * 60 * 1000;

export interface OnlineUser {
  id: string;
  displayName: string;
  lastUpdated: Date;
  location?: {
    lat: number;
    lng: number;
  };
  avatarImageBase64?: string;
  avatarColorValue?: number;
}

export const useOnlineUsers = (refreshKey: number) => {
  const [onlineUsers, setOnlineUsers] = useState<OnlineUser[]>([]);
  const [onlineCount, setOnlineCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    setLoading(true);

    const fetchUsers = async () => {
      const currentUser = auth.currentUser;
      if (!currentUser) {
        setError('認証が必要です');
        setLoading(false);
        return;
      }

      try {
        const cutoffMs = Date.now() - PRESENCE_TIMEOUT_MS;
        const presenceSnapshot = await getDocs(
          query(
            collection(db, 'streetpass_presences'),
            where('lastUpdatedMs', '>=', cutoffMs),
            orderBy('lastUpdatedMs', 'desc'),
            limit(60)
          )
        );

        if (!active) {
          return;
        }

        const users: OnlineUser[] = [];

        presenceSnapshot.forEach((doc) => {
          const data = doc.data();
          const lastUpdatedMs = typeof data.lastUpdatedMs === 'number' ? data.lastUpdatedMs : Date.now();
          const isActive = data.active === true;
          if (!isActive) {
            return;
          }
          const profile = data.profile || {};
          users.push({
            id: doc.id,
            displayName: profile.displayName || '不明なユーザー',
            lastUpdated: new Date(lastUpdatedMs),
            location: data.lat && data.lng 
              ? { lat: data.lat, lng: data.lng }
              : undefined,
            avatarImageBase64: profile.avatarImageBase64,
            avatarColorValue: typeof profile.avatarColor === 'number'
              ? profile.avatarColor
              : typeof profile.avatarColor === 'string'
                ? Number(profile.avatarColor) || undefined
                : undefined,
          });
        });

        users.sort((a, b) => b.lastUpdated.getTime() - a.lastUpdated.getTime());

        setOnlineUsers(users);
        setOnlineCount(users.length);
        setError(null);
      } catch (error: any) {
        console.error('オンラインユーザーの取得に失敗:', error);
        setError(error?.message ? `エラー: ${error.message}` : 'オンラインユーザーの取得に失敗しました');
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };

    fetchUsers();

    return () => {
      active = false;
    };
  }, [refreshKey]);

  return { onlineUsers, onlineCount, loading, error };
};
