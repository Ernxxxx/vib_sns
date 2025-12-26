import React, { useState, useEffect, useMemo } from 'react';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  Line,
} from 'recharts';
import {
  collection,
  query,
  where,
  orderBy,
  limit,
  getDocs,
} from 'firebase/firestore';
import { db } from '../services/firebase';
import { safeToDate } from '../utils/dateHelpers';
import './ActivityChart.css';

interface ChartDataPoint {
  time: string;
  投稿: number;
  感情投稿: number;
  新規ユーザー: number;
  オンライン: number;
}

export type ActivityRange = '24h' | '7d' | '30d';

interface ActivityChartProps {
  refreshKey: number;
  range: ActivityRange;
}

const MS_IN_HOUR = 60 * 60 * 1000;
const MS_IN_DAY = 24 * MS_IN_HOUR;

const createInitialSeries = (range: ActivityRange): ChartDataPoint[] => {
  const now = new Date();
  const points = range === '24h' ? 24 : range === '7d' ? 7 : 30;
  const bucketMs = range === '24h' ? MS_IN_HOUR : MS_IN_DAY;

  return Array.from({ length: points }, (_, index) => {
    const offset = points - 1 - index;
    const bucketTime = new Date(now.getTime() - offset * bucketMs);
    const label =
      range === '24h'
        ? `${bucketTime.getHours().toString().padStart(2, '0')}:00`
        : bucketTime.toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric' });

    return {
      time: label,
      投稿: 0,
      感情投稿: 0,
      新規ユーザー: 0,
      オンライン: 0,
    };
  });
};

export const ActivityChart: React.FC<ActivityChartProps> = ({ refreshKey, range }) => {
  const [chartData, setChartData] = useState<ChartDataPoint[]>([]);
  const [loading, setLoading] = useState(true);
  const yMax = useMemo(() => {
    if (!chartData.length) {
      return 0;
    }
    return chartData.reduce((max, point) => {
      const maxValue = Math.max(point.投稿, point.感情投稿, point.オンライン);
      return Math.max(max, maxValue);
    }, 0);
  }, [chartData]);
  const yDomain = useMemo(() => {
    const upper = Math.max(1, Math.ceil(yMax * 1.1));
    return [0, upper];
  }, [yMax]);

  useEffect(() => {
    const initialSeries = createInitialSeries(range);
    setChartData(initialSeries);
    setLoading(true);

    let isActive = true;

    const now = new Date();
    const durationMs = range === '24h' ? MS_IN_DAY : range === '7d' ? 7 * MS_IN_DAY : 30 * MS_IN_DAY;
    const bucketMs = range === '24h' ? MS_IN_HOUR : MS_IN_DAY;
    const points = initialSeries.length;
    const lowerBound = new Date(now.getTime() - durationMs);

    const getIndexForDate = (date: Date) => {
      const diffMs = now.getTime() - date.getTime();
      const bucketOffset = Math.floor(diffMs / bucketMs);
      if (bucketOffset < 0 || bucketOffset >= points) {
        return null;
      }
      return points - 1 - bucketOffset;
    };

    const loadData = async () => {
      try {
        const snapshotLimit = range === '24h' ? 500 : 1500;
        const [postsSnapshot, emotionSnapshot, presenceSnapshot] = await Promise.all([
          getDocs(
            query(
              collection(db, 'timelinePosts'),
              where('createdAt', '>=', lowerBound),
              orderBy('createdAt', 'desc'),
              limit(snapshotLimit)
            )
          ),
          getDocs(
            query(
              collection(db, 'emotion_map_posts'),
              where('createdAt', '>=', lowerBound),
              orderBy('createdAt', 'desc'),
              limit(snapshotLimit)
            )
          ),
          getDocs(
            query(
              collection(db, 'streetpass_presences'),
              where('lastUpdatedMs', '>=', lowerBound.getTime())
            )
          ),
        ]);

        const postCounts = new Array(points).fill(0);
        postsSnapshot.forEach((doc) => {
          const createdAt = safeToDate(doc.data().createdAt);
          if (createdAt) {
            const index = getIndexForDate(createdAt);
            if (index !== null) {
              postCounts[index]++;
            }
          }
        });

        const emotionCounts = new Array(points).fill(0);
        emotionSnapshot.forEach((doc) => {
          const createdAt = safeToDate(doc.data().createdAt);
          if (createdAt) {
            const index = getIndexForDate(createdAt);
            if (index !== null) {
              emotionCounts[index]++;
            }
          }
        });

        const onlineCounts = new Array(points).fill(0);
        presenceSnapshot.forEach((doc) => {
          const data = doc.data();
          const lastUpdatedMs =
            typeof data.lastUpdatedMs === 'number' ? data.lastUpdatedMs : null;
          if (lastUpdatedMs) {
            const updatedAt = new Date(lastUpdatedMs);
            const index = getIndexForDate(updatedAt);
            if (index !== null) {
              onlineCounts[index]++;
            }
          }
        });

        if (!isActive) {
          return;
        }

        setChartData((prev) =>
          prev.map((point, index) => ({
            ...point,
            投稿: postCounts[index],
            感情投稿: emotionCounts[index],
            オンライン: onlineCounts[index],
          }))
        );
      } catch (error) {
        console.error('活動データの取得に失敗:', error);
      } finally {
        if (isActive) {
          setLoading(false);
        }
      }
    };

    loadData();

    return () => {
      isActive = false;
    };
  }, [refreshKey, range]);

  if (loading && chartData.every((d) => d.投稿 === 0 && d.感情投稿 === 0 && d.オンライン === 0)) {
    return (
      <div className="chart-loading">
        <p>データを読み込み中...</p>
      </div>
    );
  }

  return (
    <div className="activity-chart">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={chartData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id="colorPosts" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#FFB74D" stopOpacity={0.8}/>
              <stop offset="95%" stopColor="#FFB74D" stopOpacity={0}/>
            </linearGradient>
            <linearGradient id="colorEmotionPosts" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#FF9800" stopOpacity={0.8}/>
              <stop offset="95%" stopColor="#FF9800" stopOpacity={0}/>
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis
            dataKey="time"
            stroke="#999"
            tick={{ fill: '#666', fontSize: 12 }}
          />
          <YAxis
            stroke="#999"
            domain={yDomain}
            tick={{ fill: '#666', fontSize: 12 }}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: 'white',
              border: '1px solid #e0e0e0',
              borderRadius: '8px',
              boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
            }}
          />
          <Legend
            wrapperStyle={{ paddingTop: '20px' }}
          />
          <Area
            type="monotone"
            dataKey="投稿"
            stroke="#FFB74D"
            strokeWidth={2}
            fillOpacity={1}
            fill="url(#colorPosts)"
          />
          <Area
            type="monotone"
            dataKey="感情投稿"
            stroke="#FF9800"
            strokeWidth={2}
            fillOpacity={1}
            fill="url(#colorEmotionPosts)"
          />
          <Line
            type="monotone"
            dataKey="オンライン"
            stroke="#6A1B9A"
            strokeWidth={2}
            dot={{ r: 3 }}
            activeDot={{ r: 5 }}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
};
