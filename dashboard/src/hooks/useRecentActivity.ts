import { useState, useEffect } from 'react';
import { collection, query, orderBy, limit, getDocs } from 'firebase/firestore';
import { db } from '../services/firebase';
import { safeToDateOrDefault } from '../utils/dateHelpers';

export interface RecentActivity {
  id: string;
  type: 'post' | 'emotion' | 'user';
  title: string;
  description: string;
  timestamp: Date;
  userId?: string;
  userName?: string;
}

export const useRecentActivity = (refreshKey: number) => {
  const [activities, setActivities] = useState<RecentActivity[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    setLoading(true);

    const fetchActivities = async () => {
      try {
        const [postsSnapshot, emotionSnapshot] = await Promise.all([
          getDocs(
            query(
              collection(db, 'timelinePosts'),
              orderBy('createdAt', 'desc'),
              limit(10)
            )
          ),
          getDocs(
            query(
              collection(db, 'emotion_map_posts'),
              orderBy('createdAt', 'desc'),
              limit(10)
            )
          ),
        ]);

        if (!active) {
          return;
        }

        const allActivities: RecentActivity[] = [];

        postsSnapshot.forEach((doc) => {
          const data = doc.data();
          const createdAt = safeToDateOrDefault(data.createdAt);

          allActivities.push({
            id: doc.id,
            type: 'post',
            title: '新しい投稿',
            description: data.caption || 'タイトルなし',
            timestamp: createdAt,
            userId: data.authorId,
            userName: data.authorName || '不明なユーザー',
          });
        });

        const emotionLabels: Record<string, string> = {
          happy: '😊 うれしい',
          sad: '😢 かなしい',
          excited: '🤩 ワクワク',
          calm: '😌 おだやか',
          surprised: '😮 びっくり',
          tired: '😴 つかれた',
        };

        emotionSnapshot.forEach((doc) => {
          const data = doc.data();
          const createdAt = safeToDateOrDefault(data.createdAt);
          const emotion = data.emotion || 'unknown';

          allActivities.push({
            id: doc.id,
            type: 'emotion',
            title: emotionLabels[emotion] || '感情投稿',
            description: data.message || emotionLabels[emotion] || '感情表現',
            timestamp: createdAt,
            userId: data.profileId,
          });
        });

        const sorted = allActivities
          .sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime())
          .slice(0, 20);

        setActivities(sorted);
      } catch (error) {
        console.error('活動の取得に失敗:', error);
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };

    fetchActivities();

    return () => {
      active = false;
    };
  }, [refreshKey]);

  return { activities, loading };
};
