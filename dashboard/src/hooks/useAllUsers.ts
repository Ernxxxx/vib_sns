import { useState, useEffect, useMemo } from 'react';
import { collection, getDocs } from 'firebase/firestore';
import { db, auth } from '../services/firebase';
import { OnlineUser } from './useOnlineUsers';

// オンライン状態のタイムアウト時間（5分）
const PRESENCE_TIMEOUT_MS = 5 * 60 * 1000;

export interface AllUser {
  id: string;
  displayName: string;
  isOnline: boolean;
  lastUpdated?: Date;
  location?: {
    lat: number;
    lng: number;
  };
  avatarImageBase64?: string;
  avatarColorValue?: number;
}

export const useAllUsers = (refreshKey: number, onlineUsers: OnlineUser[]) => {
  const [allUsers, setAllUsers] = useState<AllUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // 创建在线用户的 Map，以便快速查找
  const onlineUsersMap = useMemo(() => {
    const map = new Map<string, OnlineUser>();
    onlineUsers.forEach(user => {
      map.set(user.id, user);
    });
    return map;
  }, [onlineUsers]);

  useEffect(() => {
    let active = true;
    setLoading(true);

    const fetchAllUsers = async () => {
      const currentUser = auth.currentUser;
      if (!currentUser) {
        setError('認証が必要です');
        setLoading(false);
        return;
      }

      try {
        const profilesSnapshot = await getDocs(collection(db, 'profiles'));

        if (!active) {
          return;
        }

        const users: AllUser[] = [];

        profilesSnapshot.forEach((doc) => {
          const data = doc.data();
          const profileId = doc.id;
          const onlineUser = onlineUsersMap.get(profileId);

          // 如果用户在在线用户列表中，使用在线用户的数据
          if (onlineUser) {
            users.push({
              id: profileId,
              displayName: onlineUser.displayName,
              isOnline: true,
              lastUpdated: onlineUser.lastUpdated,
              location: onlineUser.location,
              avatarImageBase64: onlineUser.avatarImageBase64,
              avatarColorValue: onlineUser.avatarColorValue,
            });
          } else {
            // 如果用户不在线，使用 profile 的数据
            const avatarColor = data.avatarColor;
            users.push({
              id: profileId,
              displayName: data.displayName || '不明なユーザー',
              isOnline: false,
              avatarImageBase64: data.avatarImageBase64,
              avatarColorValue: typeof avatarColor === 'number'
                ? avatarColor
                : typeof avatarColor === 'string'
                  ? Number(avatarColor) || undefined
                  : undefined,
            });
          }
        });

        // 排序：在线用户在前（按最后更新时间），然后离线用户（按 displayName）
        users.sort((a, b) => {
          if (a.isOnline !== b.isOnline) {
            return a.isOnline ? -1 : 1; // 在线用户在前
          }
          if (a.isOnline && b.isOnline && a.lastUpdated && b.lastUpdated) {
            return b.lastUpdated.getTime() - a.lastUpdated.getTime(); // 在线用户按时间降序
          }
          return a.displayName.localeCompare(b.displayName, 'ja'); // 离线用户按名称排序
        });

        setAllUsers(users);
        setError(null);
      } catch (error: any) {
        console.error('全ユーザーの取得に失敗:', error);
        setError(error?.message ? `エラー: ${error.message}` : '全ユーザーの取得に失敗しました');
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };

    fetchAllUsers();

    return () => {
      active = false;
    };
  }, [refreshKey, onlineUsersMap]);

  return { allUsers, loading, error };
};

