import React from 'react';
import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip } from 'recharts';
import { EmotionStat } from '../hooks/useEmotionStats';
import './EmotionChart.css';

const emotionColors: Record<string, string> = {
  happy: '#FFD54F',
  sad: '#FFB74D',
  excited: '#FFA726',
  calm: '#FF9800',
  surprised: '#FF8F00',
  tired: '#FF6F00',
};

const emotionLabels: Record<string, string> = {
  happy: 'うれしい',
  sad: 'かなしい',
  excited: 'ワクワク',
  calm: 'おだやか',
  surprised: 'びっくり',
  tired: 'つかれた',
};

interface EmotionChartProps {
  emotionStats: EmotionStat[];
  loading: boolean;
}

export const EmotionChart: React.FC<EmotionChartProps> = ({ emotionStats, loading }) => {

  if (loading) {
    return (
      <div className="emotion-chart-loading">
        <p>データを読み込み中...</p>
      </div>
    );
  }

  if (emotionStats.length === 0) {
    return (
      <div className="emotion-chart-empty">
        <p>感情データがありません</p>
      </div>
    );
  }

  const chartData = emotionStats.map((stat) => ({
    name: emotionLabels[stat.emotion] || stat.emotion,
    value: stat.count,
    percentage: stat.percentage.toFixed(1),
    color: emotionColors[stat.emotion] || '#999',
  }));

  return (
    <div className="emotion-chart">
      <ResponsiveContainer width="100%" height={220}>
        <PieChart>
          <Pie
            data={chartData}
            cx="50%"
            cy="50%"
            labelLine={false}
            label={({ name, percentage }) => `${name} ${percentage}%`}
            outerRadius={70}
            fill="#8884d8"
            dataKey="value"
          >
            {chartData.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={entry.color} />
            ))}
          </Pie>
          <Tooltip
            formatter={(value: number, name: string, props: any) => [
              `${value} (${props.payload.percentage}%)`,
              '数量',
            ]}
            contentStyle={{ fontSize: '12px' }}
          />
          <Legend 
            wrapperStyle={{ paddingTop: '6px', fontSize: '10px' }}
          />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
};
