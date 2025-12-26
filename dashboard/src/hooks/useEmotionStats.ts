import { useState, useEffect } from 'react';
import { collection, getDocs } from 'firebase/firestore';
import { db } from '../services/firebase';

export interface EmotionStat {
  emotion: string;
  count: number;
  percentage: number;
}

export const useEmotionStats = (refreshKey: number) => {
  const [emotionStats, setEmotionStats] = useState<EmotionStat[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    setLoading(true);

    const fetchData = async () => {
      try {
        const snapshot = await getDocs(collection(db, 'emotion_map_posts'));
        if (!active) {
          return;
        }

        const emotionCounts: Record<string, number> = {};
        let total = 0;

        snapshot.forEach((doc) => {
          const data = doc.data();
          const emotion = data.emotion || 'unknown';
          emotionCounts[emotion] = (emotionCounts[emotion] || 0) + 1;
          total++;
        });

        const stats: EmotionStat[] = Object.entries(emotionCounts)
          .map(([emotion, count]) => ({
            emotion,
            count,
            percentage: total > 0 ? (count / total) * 100 : 0,
          }))
          .sort((a, b) => b.count - a.count);

        setEmotionStats(stats);
      } catch (error) {
        console.error('感情統計の取得に失敗:', error);
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };

    fetchData();

    return () => {
      active = false;
    };
  }, [refreshKey]);

  return { emotionStats, loading };
};

