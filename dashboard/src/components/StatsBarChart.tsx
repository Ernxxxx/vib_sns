import React from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from 'recharts';
import { ActivityStats } from '../hooks/useActivityStats';
import './StatsBarChart.css';

interface StatsBarChartProps {
  stats: ActivityStats;
  loading: boolean;
  onlineCount: number;
  totalUsers: number;
}

export const StatsBarChart: React.FC<StatsBarChartProps> = ({ stats, loading, onlineCount, totalUsers }) => {

  if (loading) {
    return (
      <div className="stats-bar-loading">
        <p>データを読み込み中...</p>
      </div>
    );
  }

  const chartData = [
    {
      name: 'オンライン',
      value: onlineCount,
      color: '#FFD54F',
    },
    {
      name: '総ユーザー',
      value: totalUsers,
      color: '#FFB74D',
    },
    {
      name: '新規',
      value: stats.newUsersToday,
      color: '#FFA726',
    },
    {
      name: '投稿',
      value: stats.postsToday,
      color: '#FF9800',
    },
    {
      name: '感情',
      value: stats.emotionPostsToday,
      color: '#FF8F00',
    },
    {
      name: 'いいね',
      value: stats.totalLikes,
      color: '#FF6F00',
    },
    {
      name: 'フォロー',
      value: stats.totalFollowers,
      color: '#F57C00',
    },
  ];

  return (
    <div className="stats-bar-chart">
      <ResponsiveContainer width="100%" height={220}>
        <BarChart data={chartData} margin={{ top: 8, right: 15, left: 8, bottom: 35 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis 
            dataKey="name" 
            stroke="#666"
            tick={{ fill: '#666', fontSize: 11 }}
            angle={-30}
            textAnchor="end"
            height={60}
          />
          <YAxis 
            stroke="#666"
            tick={{ fill: '#666', fontSize: 11 }}
            width={50}
          />
          <Tooltip 
            contentStyle={{ 
              backgroundColor: 'white', 
              border: '1px solid #e0e0e0',
              borderRadius: '8px',
              boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
              fontSize: '12px'
            }}
            formatter={(value: number) => [value.toLocaleString(), '数量']}
          />
          <Bar dataKey="value" radius={[6, 6, 0, 0]}>
            {chartData.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={entry.color} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
};
