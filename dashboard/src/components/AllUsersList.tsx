import React, { useState, useEffect, useRef } from 'react';
import { AllUser } from '../hooks/useAllUsers';
import { reverseGeocode } from '../services/geocoding';
import './AllUsersList.css';

interface AllUsersListProps {
  users: AllUser[];
  loading: boolean;
  error?: string | null;
}

export const AllUsersList: React.FC<AllUsersListProps> = ({ users, loading, error }) => {
  const [addresses, setAddresses] = useState<Map<string, string | null>>(new Map());
  const [loadingAddresses, setLoadingAddresses] = useState<Set<string>>(new Set());
  const addressesRef = useRef<Map<string, string | null>>(new Map());
  const loadingAddressesRef = useRef<Set<string>>(new Set());
  
  // 同步ref和state
  useEffect(() => {
    addressesRef.current = addresses;
  }, [addresses]);
  
  useEffect(() => {
    loadingAddressesRef.current = loadingAddresses;
  }, [loadingAddresses]);

  const formatTime = (date: Date) => {
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    
    if (diffMins < 1) return 'たった今';
    if (diffMins < 60) return `${diffMins}分前`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}時間前`;
    return date.toLocaleDateString('ja-JP');
  };

  // 为有坐标的用户获取地址
  useEffect(() => {
    const fetchAddresses = async () => {
      const usersWithLocation = users.filter(u => u.isOnline && u.location);
      
      for (const user of usersWithLocation) {
        if (!user.location) continue;
        
        const key = `${user.id}-${user.location.lat}-${user.location.lng}`;
        
        // 使用ref检查最新状态，避免重复请求
        if (addressesRef.current.has(key) || loadingAddressesRef.current.has(key)) {
          continue;
        }

        // 标记为加载中
        setLoadingAddresses(prev => new Set(prev).add(key));
        loadingAddressesRef.current.add(key);

        // 获取地址（带延迟以避免API速率限制）
        try {
          const result = await reverseGeocode(user.location.lat, user.location.lng);
          setAddresses(prev => {
            const next = new Map(prev);
            next.set(key, result.address);
            addressesRef.current = next;
            return next;
          });
        } catch (error) {
          console.warn('地址取得に失敗:', error);
          setAddresses(prev => {
            const next = new Map(prev);
            next.set(key, null);
            addressesRef.current = next;
            return next;
          });
        } finally {
          setLoadingAddresses(prev => {
            const next = new Set(prev);
            next.delete(key);
            loadingAddressesRef.current = next;
            return next;
          });
        }
      }
    };

    if (users.length > 0) {
      fetchAddresses();
    }
  }, [users]);

  const getAddress = (user: AllUser): string | null => {
    if (!user.location) return null;
    const key = `${user.id}-${user.location.lat}-${user.location.lng}`;
    return addresses.get(key) || null;
  };

  if (loading) {
    return (
      <div className="users-list-loading">
        <p>読み込み中...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="users-list-error">
        <p>⚠️ {error}</p>
        <p style={{ fontSize: '12px', color: '#999', marginTop: '8px' }}>
          ブラウザのコンソールを確認してください
        </p>
      </div>
    );
  }

  if (users.length === 0) {
    return (
      <div className="users-list-empty">
        <p>ユーザーはいません</p>
        <p style={{ fontSize: '12px', color: '#999', marginTop: '8px' }}>
          登録されているユーザーがいません
        </p>
      </div>
    );
  }

  return (
    <div className="all-users-list">
      {users.map((user) => (
        <div key={user.id} className={`user-item ${user.isOnline ? 'user-online' : 'user-offline'}`}>
          <div className="user-avatar">
            {user.avatarImageBase64 ? (
              <img
                src={`data:image/jpeg;base64,${user.avatarImageBase64}`}
                alt={user.displayName}
                className="user-avatar-image"
              />
            ) : (
              <span
                className="user-avatar-placeholder"
                style={{
                  backgroundColor: user.avatarColorValue
                    ? (() => {
                        const rgb = (user.avatarColorValue & 0x00ffffff)
                          .toString(16)
                          .padStart(6, '0');
                        return `#${rgb}`;
                      })()
                    : '#FFB74D',
                  opacity: user.isOnline ? 1 : 0.6,
                }}
              >
                {user.displayName.charAt(0).toUpperCase()}
              </span>
            )}
          </div>
          <div className="user-info">
            <div className="user-name">{user.displayName}</div>
            <div className="user-meta">
              {user.isOnline && user.location && (() => {
                const address = getAddress(user);
                const isLoading = loadingAddresses.has(`${user.id}-${user.location.lat}-${user.location.lng}`);
                
                return (
                  <span className="user-location">
                    📍 {isLoading ? (
                      <span className="address-loading">読み込み中...</span>
                    ) : address ? (
                      address
                    ) : (
                      `${user.location.lat.toFixed(4)}, ${user.location.lng.toFixed(4)}`
                    )}
                  </span>
                );
              })()}
              {user.isOnline && user.lastUpdated && (
                <span className="user-time">{formatTime(user.lastUpdated)}</span>
              )}
            </div>
          </div>
          <div className={`user-status ${user.isOnline ? 'online' : 'offline'}`}>
            {user.isOnline ? 'オンライン' : 'オフライン'}
          </div>
        </div>
      ))}
    </div>
  );
};

