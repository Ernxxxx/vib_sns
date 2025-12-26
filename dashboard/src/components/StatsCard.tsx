import React from 'react';
import './StatsCard.css';

interface StatsCardProps {
  title: string;
  value: number | string;
  icon: string;
  color?: string;
  loading?: boolean;
  trend?: {
    value: number;
    isPositive: boolean;
  };
  subtitle?: string;
  onClick?: () => void;
}

export const StatsCard: React.FC<StatsCardProps> = ({
  title,
  value,
  icon,
  color = '#667eea',
  loading = false,
  trend,
  subtitle,
  onClick,
}) => {
  return (
    <div 
      className={`stats-card ${onClick ? 'clickable' : ''}`} 
      style={{ '--card-color': color } as React.CSSProperties}
      onClick={onClick}
    >
      <div className="stats-card-header">
        <div className="stats-card-icon">{icon}</div>
        {trend && (
          <div className={`stats-trend ${trend.isPositive ? 'positive' : 'negative'}`}>
            {trend.isPositive ? '↑' : '↓'} {Math.abs(trend.value)}%
          </div>
        )}
      </div>
      <div className="stats-card-content">
        <div className="stats-card-value">
          {loading ? (
            <span className="loading-dots">
              <span>.</span>
              <span>.</span>
              <span>.</span>
            </span>
          ) : (
            typeof value === 'number' ? value.toLocaleString() : value
          )}
        </div>
        <div className="stats-card-title">{title}</div>
        {subtitle && <div className="stats-card-subtitle">{subtitle}</div>}
      </div>
    </div>
  );
};
