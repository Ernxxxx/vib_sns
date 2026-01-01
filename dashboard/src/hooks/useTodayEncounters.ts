import { useState, useEffect } from 'react';
import { collection, getDocs } from 'firebase/firestore';
import { db } from '../services/firebase';

export interface UserPresence {
  id: string;
  profileId: string;
  displayName: string;
  avatarImageBase64?: string;
  colorValue?: number;
  latitude?: number;
  longitude?: number;
  lastUpdatedAt: Date;
  message?: string;
  active: boolean;
}

export interface EncounterPair {
  id: string;
  userA: UserPresence;
  userB: UserPresence;
  encounteredAt: Date;
  distance?: number; // 米
  location?: {
    latitude: number;
    longitude: number;
  };
}

// 计算两点之间的距离（米）
const calculateDistance = (
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number => {
  const R = 6371000; // 地球半径（米）
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
};

export const useTodayEncounters = (refreshKey: number = 0) => {
  const [encounterPairs, setEncounterPairs] = useState<EncounterPair[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    setLoading(true);

    const fetchEncounters = async () => {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const todayEnd = new Date(today);
      todayEnd.setHours(23, 59, 59, 999);

      try {
        const snapshot = await getDocs(collection(db, 'streetpass_presences'));

        if (!active) {
          return;
        }

        const todayPresences: UserPresence[] = [];
        snapshot.forEach((doc) => {
          const data = doc.data();
          const lastUpdatedMs = typeof data.lastUpdatedMs === 'number' ? data.lastUpdatedMs : null;
          
          if (lastUpdatedMs) {
            const updatedAt = new Date(lastUpdatedMs);
            if (updatedAt >= today && updatedAt <= todayEnd) {
              const profile = data.profile || {};
              const profileId = doc.id;
              
              todayPresences.push({
                id: doc.id,
                profileId: profileId,
                displayName: profile.displayName || profile.name || '不明なユーザー',
                avatarImageBase64: profile.avatarImageBase64,
                colorValue: profile.colorValue,
                latitude: typeof data.lat === 'number' ? data.lat : undefined,
                longitude: typeof data.lng === 'number' ? data.lng : undefined,
                lastUpdatedAt: updatedAt,
                message: data.message || profile.message,
                active: data.active !== false,
              });
            }
          }
        });

        // 配对逻辑：找出在同一时间段（5分钟内）且位置相近（100米内）的用户
        const pairs: EncounterPair[] = [];
        const TIME_WINDOW_MS = 5 * 60 * 1000; // 5分钟
        const DISTANCE_THRESHOLD_M = 100; // 100米
        const processedPairs = new Set<string>();

        for (let i = 0; i < todayPresences.length; i++) {
          for (let j = i + 1; j < todayPresences.length; j++) {
            const userA = todayPresences[i];
            const userB = todayPresences[j];

            // 创建唯一的配对ID（排序后确保唯一）
            const pairId = [userA.id, userB.id].sort().join('_');
            if (processedPairs.has(pairId)) {
              continue;
            }

            // 检查时间差
            const timeDiff = Math.abs(
              userA.lastUpdatedAt.getTime() - userB.lastUpdatedAt.getTime()
            );
            if (timeDiff > TIME_WINDOW_MS) {
              continue;
            }

            // 检查位置（如果两个用户都有位置信息）
            let distance: number | undefined;
            let location: { latitude: number; longitude: number } | undefined;

            if (
              userA.latitude !== undefined &&
              userA.longitude !== undefined &&
              userB.latitude !== undefined &&
              userB.longitude !== undefined
            ) {
              distance = calculateDistance(
                userA.latitude,
                userA.longitude,
                userB.latitude,
                userB.longitude
              );

              // 如果距离太远，跳过
              if (distance > DISTANCE_THRESHOLD_M) {
                continue;
              }

              // 使用两个用户位置的中点作为 encounter 位置
              location = {
                latitude: (userA.latitude + userB.latitude) / 2,
                longitude: (userA.longitude + userB.longitude) / 2,
              };
            }

            // 创建配对
            const encounteredAt = new Date(
              Math.max(
                userA.lastUpdatedAt.getTime(),
                userB.lastUpdatedAt.getTime()
              )
            );

            pairs.push({
              id: pairId,
              userA,
              userB,
              encounteredAt,
              distance,
              location,
            });

            processedPairs.add(pairId);
          }
        }

        // 按时间排序，最新的在前
        pairs.sort((a, b) => b.encounteredAt.getTime() - a.encounteredAt.getTime());
        setEncounterPairs(pairs);
      } catch (error) {
        console.error('今日のすれ違い取得に失敗:', error);
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };

    fetchEncounters();

    return () => {
      active = false;
    };
  }, [refreshKey]);

  return { encounterPairs, loading };
};

