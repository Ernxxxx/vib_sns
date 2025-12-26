import React from 'react';
import { useRecentActivity } from '../hooks/useRecentActivity';
import './RecentActivity.css';

interface RecentActivityProps {
  refreshKey: number;
}

export const RecentActivity: React.FC<RecentActivityProps> = ({ refreshKey }) => {
  const { activities, loading } = useRecentActivity(refreshKey);

  const formatTime = (date: Date) => {
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    
    if (diffMins < 1) return 'たった今';
    if (diffMins < 60) return `${diffMins}分前`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}時間前`;
    const diffDays = Math.floor(diffHours / 24);
    if (diffDays < 7) return `${diffDays}日前`;
    return date.toLocaleDateString('ja-JP');
  };

  const getActivityIcon = (type: string) => {
    switch (type) {
      case 'post':
        return '📝';
      case 'emotion':
        return '😊';
      case 'user':
        return '👤';
      default:
        return '📌';
    }
  };

  if (loading) {
    return (
      <div className="recent-activity-loading">
        <p>読み込み中...</p>
      </div>
    );
  }

  if (activities.length === 0) {
    return (
      <div className="recent-activity-empty">
        <p>活動はありません</p>
      </div>
    );
  }

  return (
    <div className="recent-activity">
      <div className="activity-list">
        {activities.slice(0, 10).map((activity) => (
          <div key={activity.id} className="activity-item">
            <div className="activity-icon">{getActivityIcon(activity.type)}</div>
            <div className="activity-content">
              <div className="activity-title">{activity.title}</div>
              <div className="activity-description">{activity.description}</div>
              {activity.userName && (
                <div className="activity-user">@{activity.userName}</div>
              )}
            </div>
            <div className="activity-time">{formatTime(activity.timestamp)}</div>
          </div>
        ))}
      </div>
    </div>
  );
};

