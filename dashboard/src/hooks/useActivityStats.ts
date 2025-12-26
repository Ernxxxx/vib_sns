import { useState, useEffect } from 'react';
import {
  collection,
  getDocs,
} from 'firebase/firestore';
import { db } from '../services/firebase';
import { safeToDate } from '../utils/dateHelpers';

export interface ActivityStats {
  encountersToday: number;
  postsToday: number;
  emotionPostsToday: number;
  totalUsers: number;
  newUsersToday: number;
  totalPosts: number;
  totalEmotionPosts: number;
  totalLikes: number;
  totalFollowers: number;
}

export const useActivityStats = (refreshKey: number) => {
  const [stats, setStats] = useState<ActivityStats>({
    encountersToday: 0,
    postsToday: 0,
    emotionPostsToday: 0,
    totalUsers: 0,
    newUsersToday: 0,
    totalPosts: 0,
    totalEmotionPosts: 0,
    totalLikes: 0,
    totalFollowers: 0,
  });
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date>(new Date());

  useEffect(() => {
    let active = true;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayEnd = new Date(today);
    todayEnd.setHours(23, 59, 59, 999);

    const loadStats = async () => {
      setLoading(true);
      try {
        const [timelineSnap, emotionSnap, profilesSnap, presenceSnap] = await Promise.all([
          getDocs(collection(db, 'timelinePosts')),
          getDocs(collection(db, 'emotion_map_posts')),
          getDocs(collection(db, 'profiles')),
          getDocs(collection(db, 'streetpass_presences')),
        ]);

        if (!active) {
          return;
        }

        let postsToday = 0;
        timelineSnap.forEach((doc) => {
          const createdAt = safeToDate(doc.data().createdAt);
          if (createdAt && createdAt >= today && createdAt <= todayEnd) {
            postsToday++;
          }
        });

        let emotionPostsToday = 0;
        emotionSnap.forEach((doc) => {
          const createdAt = safeToDate(doc.data().createdAt);
          if (createdAt && createdAt >= today && createdAt <= todayEnd) {
            emotionPostsToday++;
          }
        });

        let totalLikes = 0;
        let totalFollowers = 0;
        let newUsersToday = 0;
        profilesSnap.forEach((doc) => {
          const data = doc.data();
          if (data.receivedLikes) {
            totalLikes += data.receivedLikes || 0;
          }
          if (data.followersCount) {
            totalFollowers += data.followersCount || 0;
          }
          if (data.createdAt) {
            const createdAt = safeToDate(data.createdAt);
            if (createdAt && createdAt >= today && createdAt <= todayEnd) {
              newUsersToday++;
            }
          }
        });

        let encountersToday = 0;
        const todayPresenceIds = new Set<string>();
        presenceSnap.forEach((doc) => {
          const data = doc.data();
          const lastUpdatedMs = typeof data.lastUpdatedMs === 'number' ? data.lastUpdatedMs : null;
          if (lastUpdatedMs) {
            const updatedAt = new Date(lastUpdatedMs);
            if (updatedAt >= today && updatedAt <= todayEnd) {
              todayPresenceIds.add(doc.id);
            }
          }
        });
        encountersToday = todayPresenceIds.size;

        setStats({
          encountersToday,
          postsToday,
          emotionPostsToday,
          totalUsers: profilesSnap.size,
          newUsersToday,
          totalPosts: timelineSnap.size,
          totalEmotionPosts: emotionSnap.size,
          totalLikes,
          totalFollowers,
        });
        setLastUpdated(new Date());
      } catch (error) {
        console.error('統計データの取得に失敗:', error);
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };

    loadStats();

    return () => {
      active = false;
    };
  }, [refreshKey]);

  return { stats, loading, lastUpdated };
};
