import React, { useState, useEffect, useRef } from 'react';
import { BaseModal } from './BaseModal';
import { EncounterPair } from '../hooks/useTodayEncounters';
import { reverseGeocode } from '../services/geocoding';
import './EncountersModal.css';

interface EncountersModalProps {
  encounterPairs: EncounterPair[];
  loading: boolean;
  onClose: () => void;
}

export const EncountersModal: React.FC<EncountersModalProps> = ({ 
  encounterPairs, 
  loading, 
  onClose 
}) => {
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

  // 为有位置的配对获取地址
  useEffect(() => {
    const fetchAddresses = async () => {
      const pairsWithLocation = encounterPairs.filter(p => p.location);
      
      for (const pair of pairsWithLocation) {
        if (!pair.location) continue;
        
        const key = `${pair.id}-${pair.location.latitude}-${pair.location.longitude}`;
        
        // 使用ref检查最新状态，避免重复请求
        if (addressesRef.current.has(key) || loadingAddressesRef.current.has(key)) {
          continue;
        }

        // 标记为加载中
        setLoadingAddresses(prev => new Set(prev).add(key));
        loadingAddressesRef.current.add(key);

        // 获取地址（API自带延迟以避免速率限制）
        try {
          const result = await reverseGeocode(pair.location.latitude, pair.location.longitude);
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

    if (encounterPairs.length > 0) {
      fetchAddresses();
    }
  }, [encounterPairs]);

  const getAddress = (pair: EncounterPair): string | null => {
    if (!pair.location) return null;
    const key = `${pair.id}-${pair.location.latitude}-${pair.location.longitude}`;
    return addresses.get(key) || null;
  };

  const isAddressLoading = (pair: EncounterPair): boolean => {
    if (!pair.location) return false;
    const key = `${pair.id}-${pair.location.latitude}-${pair.location.longitude}`;
    return loadingAddresses.has(key);
  };

  const formatTime = (date: Date) => {
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffSecs = Math.floor(diffMs / 1000);
    const diffMins = Math.floor(diffSecs / 60);
    const diffHours = Math.floor(diffMins / 60);
    
    if (diffSecs < 10) return 'たった今';
    if (diffSecs < 60) return `${diffSecs}秒前`;
    if (diffMins < 60) return `${diffMins}分前`;
    if (diffHours < 24) return `${diffHours}時間前`;
    
    // 超过24小时显示完整日期和时间
    return date.toLocaleString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatDateTime = (date: Date) => {
    return date.toLocaleString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  };

  const argb32ToHex = (argb32: number): string => {
    const rgb = (argb32 & 0x00FFFFFF).toString(16).padStart(6, '0');
    return `#${rgb}`;
  };

  const formatLocation = (pair: EncounterPair) => {
    if (!pair.location) {
      return '位置情報なし';
    }

    const address = getAddress(pair);
    const isLoading = isAddressLoading(pair);

    if (isLoading) {
      return '読み込み中...';
    }

    if (address) {
      return address;
    }

    // 如果地址获取失败，显示坐标作为后备
    return `${pair.location.latitude.toFixed(6)}, ${pair.location.longitude.toFixed(6)}`;
  };

  return (
    <BaseModal 
      title="🤝 今日のすれ違い" 
      onClose={onClose}
      headerColor="linear-gradient(135deg, #FF6F00 0%, #FF8F00 50%, #FFA000 100%)"
    >
      {loading ? (
        <div className="encounters-loading">
          <p>読み込み中...</p>
        </div>
      ) : encounterPairs.length === 0 ? (
        <div className="encounters-empty">
          <p>今日のすれ違いはありません</p>
        </div>
      ) : (
        <div className="encounters-list">
          {encounterPairs.map((pair) => (
            <div key={pair.id} className="encounter-item">
              <div className="encounter-header">
                <div className="encounter-pair">
                  {/* 用户 A */}
                  <div className="encounter-user">
                    <div className="encounter-avatar">
                      {pair.userA.avatarImageBase64 ? (
                        <img 
                          src={`data:image/jpeg;base64,${pair.userA.avatarImageBase64}`}
                          alt={pair.userA.displayName}
                          className="encounter-avatar-image"
                        />
                      ) : (
                        <div 
                          className="encounter-avatar-placeholder"
                          style={{ 
                            background: pair.userA.colorValue 
                              ? argb32ToHex(pair.userA.colorValue)
                              : `linear-gradient(135deg, #FF8F00 0%, #FFA000 100%)`
                          }}
                        >
                          {pair.userA.displayName.charAt(0).toUpperCase()}
                        </div>
                      )}
                    </div>
                    <div className="encounter-user-info">
                      <div className="encounter-user-name">{pair.userA.displayName}</div>
                    </div>
                  </div>
                  
                  {/* 中间的连接符号 */}
                  <div className="encounter-connector">
                    <span className="connector-icon">🤝</span>
                    <span className="connector-text">すれ違い</span>
                  </div>
                  
                  {/* 用户 B */}
                  <div className="encounter-user">
                    <div className="encounter-avatar">
                      {pair.userB.avatarImageBase64 ? (
                        <img 
                          src={`data:image/jpeg;base64,${pair.userB.avatarImageBase64}`}
                          alt={pair.userB.displayName}
                          className="encounter-avatar-image"
                        />
                      ) : (
                        <div 
                          className="encounter-avatar-placeholder"
                          style={{ 
                            background: pair.userB.colorValue 
                              ? argb32ToHex(pair.userB.colorValue)
                              : `linear-gradient(135deg, #FF8F00 0%, #FFA000 100%)`
                          }}
                        >
                          {pair.userB.displayName.charAt(0).toUpperCase()}
                        </div>
                      )}
                    </div>
                    <div className="encounter-user-info">
                      <div className="encounter-user-name">{pair.userB.displayName}</div>
                    </div>
                  </div>
                </div>
                
                <div className="encounter-time-badge">
                  {formatTime(pair.encounteredAt)}
                </div>
              </div>
              
              <div className="encounter-details">
                {pair.distance !== undefined && (
                  <div className="detail-row">
                    <span className="detail-label">📏 距離:</span>
                    <span className="detail-value">
                      {pair.distance < 1 
                        ? `${Math.round(pair.distance * 100)}cm`
                        : `${Math.round(pair.distance)}m`
                      }
                    </span>
                  </div>
                )}
                {pair.location && (
                  <div className="detail-row">
                    <span className="detail-label">📍 位置:</span>
                    <span className={`detail-value ${isAddressLoading(pair) ? 'address-loading' : ''}`}>
                      {formatLocation(pair)}
                    </span>
                  </div>
                )}
                <div className="detail-row">
                  <span className="detail-label">🕐 時刻:</span>
                  <span className="detail-value">{formatDateTime(pair.encounteredAt)}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </BaseModal>
  );
};

