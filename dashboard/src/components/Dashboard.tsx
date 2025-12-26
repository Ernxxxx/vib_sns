import React, { useState, useEffect, ChangeEvent, useRef, useCallback } from 'react';
import { useOnlineUsers } from '../hooks/useOnlineUsers';
import { useActivityStats } from '../hooks/useActivityStats';
import { useTodayPosts } from '../hooks/useTodayPosts';
import { useEmotionStats } from '../hooks/useEmotionStats';
import { useDashboardRefresh, RefreshFrequency } from '../hooks/useDashboardRefresh';
import { StatsCard } from './StatsCard';
import { ActivityChart, ActivityRange } from './ActivityChart';
import { EmotionChart } from './EmotionChart';
import { StatsBarChart } from './StatsBarChart';
import { OnlineUsersList } from './OnlineUsersList';
import { PostsModal } from './PostsModal';
import { logout } from '../services/auth';
import './Dashboard.css';
import vibLogo from '../vib_white.png';

interface DashboardProps {
  onLogout: () => void;
}

export const Dashboard: React.FC<DashboardProps> = ({ onLogout }) => {
  const {
    refreshKey,
    frequency,
    setFrequency,
    triggerRefresh,
    nextRefreshInSeconds,
  } = useDashboardRefresh();
  const { onlineCount, onlineUsers, loading: usersLoading, error: usersError } = useOnlineUsers(refreshKey);
  const { stats, loading: statsLoading, lastUpdated } = useActivityStats(refreshKey);
  const { emotionStats, loading: emotionLoading } = useEmotionStats(refreshKey);
  const { posts: todayPosts, loading: postsLoading } = useTodayPosts(50, refreshKey);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [showPostsModal, setShowPostsModal] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [activityRange, setActivityRange] = useState<ActivityRange>('24h');
  const [systemStatus, setSystemStatus] = useState<'active' | 'collecting' | 'future'>('active');
  const [isOffline, setIsOffline] = useState(() =>
    typeof window !== 'undefined' ? !window.navigator.onLine : false
  );
  const collectingTimeoutRef = useRef<number | null>(null);
  const activityRangeOptions: { key: ActivityRange; label: string }[] = [
    { key: '24h', label: '今日' },
    { key: '7d', label: '7日' },
    { key: '30d', label: '30日' },
  ];
  const [currentTime, setCurrentTime] = useState(() => new Date());
  const handleLogout = () => {
    logout();
    onLogout();
  };

  const showCollectingTransient = useCallback(() => {
    if (isOffline) return;
    setSystemStatus('collecting');
    if (collectingTimeoutRef.current) {
      window.clearTimeout(collectingTimeoutRef.current);
    }
    collectingTimeoutRef.current = window.setTimeout(() => {
      setSystemStatus('active');
      collectingTimeoutRef.current = null;
    }, 3000);
  }, [isOffline]);

  const handleRefresh = () => {
    showCollectingTransient();
    triggerRefresh();
    setIsRefreshing(true);
    setTimeout(() => {
      setIsRefreshing(false);
    }, 1000);
  };

  const autoEnabled = frequency > 0;
  const handleIntervalChange = (event: ChangeEvent<HTMLSelectElement>) => {
    const nextValue = Number(event.target.value) as RefreshFrequency;
    setFrequency(nextValue);
  };

  const formatLastUpdated = (date: Date) => {
    const diffMs = currentTime.getTime() - date.getTime();
    const diffSecs = Math.max(0, Math.floor(diffMs / 1000));

    if (diffSecs < 10) return 'たった今';
    if (diffSecs < 60) return `${diffSecs}秒前`;
    const diffMins = Math.floor(diffSecs / 60);
    if (diffMins < 60) return `${diffMins}分前`;
    return date.toLocaleTimeString('ja-JP');
  };

  const formatCountdownLabel = (seconds: number) => {
    if (seconds <= 0) {
      return 'まもなく';
    }
    if (seconds >= 60) {
      const mins = Math.floor(seconds / 60);
      const secs = seconds % 60;
      return secs ? `${mins}分${secs}秒` : `${mins}分`;
    }
    return `${seconds}秒`;
  };

  const autoStatusText = autoEnabled
    ? nextRefreshInSeconds === null
      ? '時刻計算中…'
      : `次 ${formatCountdownLabel(nextRefreshInSeconds)}`
    : '自動モード待機中';

  const formatDateTime = (date: Date) => {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    return `${year}/${month}/${day} ${hours}:${minutes}:${seconds}`;
  };

  useEffect(() => {
    return () => {
      if (collectingTimeoutRef.current) {
        window.clearTimeout(collectingTimeoutRef.current);
      }
    };
  }, []);

  useEffect(() => {
    const handleOnline = () => {
      setIsOffline(false);
      setSystemStatus('active');
    };
    const handleOffline = () => {
      setIsOffline(true);
      setSystemStatus('future');
      if (collectingTimeoutRef.current) {
        window.clearTimeout(collectingTimeoutRef.current);
        collectingTimeoutRef.current = null;
      }
    };
    if (typeof window !== 'undefined') {
      window.addEventListener('online', handleOnline);
      window.addEventListener('offline', handleOffline);
    }
    return () => {
      if (typeof window !== 'undefined') {
        window.removeEventListener('online', handleOnline);
        window.removeEventListener('offline', handleOffline);
      }
    };
  }, []);

  useEffect(() => {
    if (isOffline) return;
    showCollectingTransient();
  }, [refreshKey, isOffline, showCollectingTransient]);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 4);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  useEffect(() => {
    const timer = window.setInterval(() => {
      setCurrentTime(new Date());
    }, 1000);
    return () => {
      window.clearInterval(timer);
    };
  }, []);

  return (
    <div className="dashboard">
      <nav className={`dashboard-nav ${scrolled ? 'scrolled' : ''}`}>
        <div className="nav-container">
          {/* 左侧：Logo和标题 */}
          <div className="nav-brand">
            <div className="nav-logo">
              <img src={vibLogo} alt="VIB logo" className="logo-img" />
              <div className="logo-pulse"></div>
            </div>
            <div className="nav-title-group">
              <h1 className="nav-title">VIB SNS Dashboard</h1>
              <p className="nav-subtitle">
                <span className="subtitle-icon">🔍</span>
                リアルタイム監視システム
                {lastUpdated && (
                  <span className="nav-status">
                    <span className="status-dot"></span>
                    {formatLastUpdated(lastUpdated)}
                  </span>
                )}
              </p>
            </div>
          </div>

          {/* 中间：导航链接（已移除） */}

          {/* 右侧：操作按钮组 */}
          <div className="nav-actions">
            {/* 时钟和状态栏容器 */}
            <div className="clock-status-group">
              {/* 时钟 */}
              <div className="clock-display" aria-live="polite">
                <span className="clock-icon">🕐</span>
                <span className="clock-text">{formatDateTime(currentTime)}</span>
              </div>

              {/* システム状態カード */}
              <div
                className="system-status-card"
                aria-live="polite"
                aria-label="システム状態"
              >
                <p className="system-status-title sr-only">システム状態</p>
                <span
                  className={`system-status-dot ${
                    systemStatus === 'active'
                      ? 'system-status-dot--active'
                      : systemStatus === 'collecting'
                      ? 'system-status-dot--collecting'
                      : 'system-status-dot--future'
                  }`}
                ></span>
                <span className="system-status-text">
                  {systemStatus === 'active'
                    ? '正常稼働'
                    : systemStatus === 'collecting'
                    ? 'データ収集中'
                    : '異常（将来）'}
                </span>
              </div>
            </div>

            <div className="refresh-control">
              <div className="status-row">
                <span className="auto-refresh-status">{autoStatusText}</span>
                <label className="auto-label" htmlFor="auto-refresh">⏱️ 动态间隔</label>
              </div>
              <div className="refresh-actions">
                <button
                  className={`nav-button refresh-btn ${isRefreshing ? 'refreshing' : ''}`}
                  onClick={handleRefresh}
                  disabled={isRefreshing}
                  title="データを更新"
                >
                  <span className="button-icon">{isRefreshing ? '🔄' : '↻'}</span>
                  <span className="button-text">{isRefreshing ? '処理中' : '手動'}</span>
                </button>

                <select
                  id="auto-refresh"
                  className="dropdown-select auto-interval-select"
                  value={frequency}
                  onChange={handleIntervalChange}
                >
                  <option value={0}>なし</option>
                  <option value={1}>1分</option>
                  <option value={10}>10分</option>
                </select>
              </div>
            </div>

            {/* 登出按钮 */}
            <button
              className="nav-button logout-btn power-btn"
              onClick={handleLogout}
              aria-label="ログアウト"
            >
              <span className="button-icon">⏻</span>
              <span className="button-text sr-only">ログアウト</span>
            </button>

            {/* 移动端菜单开关（已移除） */}
          </div>
        </div>
      </nav>

      <div className="dashboard-content-compact">
        {/* トップ: 主要指標（4つ） */}
        <div className="top-stats" id="overview">
          <StatsCard
            title="ユーザー数"
            value={`${onlineCount}/${stats.totalUsers}`}
            icon="👥"
            color="#FFD54F"
            loading={usersLoading || statsLoading}
            subtitle="5分以内アクティブ · 総登録ユーザー"
          />
          <StatsCard
            title="今日の投稿"
            value={stats.postsToday}
            icon="📝"
            color="#FF9800"
            loading={statsLoading}
            subtitle={`合計 ${stats.totalPosts} • クリックで詳細`}
            onClick={() => setShowPostsModal(true)}
          />
          <StatsCard
            title="今日のすれ違い"
            value={stats.encountersToday}
            icon="🤝"
            color="#FF6F00"
            loading={statsLoading}
            subtitle="本日の出会い"
          />
        </div>

        {/* メイン: チャートエリア */}
        <div className="main-charts">
          {/* 左側: 統計データの棒グラフ */}
          <section className="chart-section" id="stats">
            <div className="section-header">
              <h2>📊 統計データ</h2>
            </div>
            <StatsBarChart stats={stats} loading={statsLoading} onlineCount={onlineCount} />
          </section>

          {/* 右側: 感情分布 */}
          <section className="chart-section" id="emotion">
            <div className="section-header">
              <h2>😊 感情分布</h2>
            </div>
            <EmotionChart emotionStats={emotionStats} loading={emotionLoading} />
          </section>
        </div>

        {/* ボトム: 活動トレンドとオンラインユーザー */}
        <div className="bottom-section">
          {/* 活動トレンド（コンパクト） */}
          <section className="chart-section activity-section" id="activity">
            <div className="section-header">
              <div>
                <h2>📈 24時間活動トレンド</h2>
                <p className="section-subtitle">必要な範囲を選べば、その期間だけチャートが伸びます。</p>
              </div>
              <div className="activity-range-switch">
                {activityRangeOptions.map((option) => (
                  <button
                    key={option.key}
                    type="button"
                    className={`range-button ${activityRange === option.key ? 'range-button--active' : ''}`}
                    onClick={() => setActivityRange(option.key)}
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            </div>
            <div className="compact-chart-container activity-chart-large">
              <ActivityChart refreshKey={refreshKey} range={activityRange} />
            </div>
          </section>

          {/* オンラインユーザー（コンパクト） */}
          <section className="users-section compact-users" id="users">
            <div className="section-header">
              <h2>👥 オンラインユーザー</h2>
              <span className="user-count-badge">{onlineUsers.length}</span>
            </div>
            <OnlineUsersList users={onlineUsers} loading={usersLoading} error={usersError} />
          </section>
        </div>
      </div>

      {/* 投稿モーダル */}
      {showPostsModal && (
        <PostsModal
          posts={todayPosts}
          loading={postsLoading}
          onClose={() => setShowPostsModal(false)}
        />
      )}
    </div>
  );
};
