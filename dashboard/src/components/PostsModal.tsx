import React from 'react';
import { BaseModal } from './BaseModal';
import { Post } from '../hooks/useAllPosts';
import './PostsModal.css';

interface PostsModalProps {
  posts: Post[];
  loading: boolean;
  onClose: () => void;
}

export const PostsModal: React.FC<PostsModalProps> = ({ posts, loading, onClose }) => {
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
    // 超过7天的显示完整日期和时间
    return date.toLocaleString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const argb32ToHex = (argb32: number): string => {
    // ARGB32格式: AARRGGBB，转换为RGB十六进制
    const rgb = (argb32 & 0x00FFFFFF).toString(16).padStart(6, '0');
    return `#${rgb}`;
  };

  return (
    <BaseModal 
      title="📝 投稿一覧" 
      onClose={onClose}
      headerColor="linear-gradient(135deg, #FFD54F 0%, #FFB74D 50%, #FF9800 100%)"
    >
      {loading ? (
        <div className="posts-loading">
          <p>読み込み中...</p>
        </div>
      ) : posts.length === 0 ? (
        <div className="posts-empty">
          <p>投稿はありません</p>
        </div>
      ) : (
        <div className="posts-list">
          {posts.map((post) => (
            <div key={post.id} className="post-item">
              <div className="post-header">
                <div className="post-author">
                  <div className="post-avatar">
                    {post.authorAvatarImageBase64 ? (
                      <img 
                        src={`data:image/jpeg;base64,${post.authorAvatarImageBase64}`}
                        alt={post.authorName}
                        className="post-avatar-image"
                      />
                    ) : (
                      <div 
                        className="post-avatar-placeholder"
                        style={{ 
                          background: post.authorColorValue 
                            ? argb32ToHex(post.authorColorValue)
                            : `linear-gradient(135deg, #FFB74D 0%, #FF9800 100%)`
                        }}
                      >
                        {post.authorName.charAt(0).toUpperCase()}
                      </div>
                    )}
                  </div>
                  <div className="post-author-info">
                    <div className="post-author-name">{post.authorName}</div>
                    <div className="post-time">{formatTime(post.createdAt)}</div>
                  </div>
                </div>
                <div className="post-likes">
                  ❤️ {post.likeCount}
                </div>
              </div>
              
              {post.caption && (
                <div className="post-caption">{post.caption}</div>
              )}
              
              {post.hashtags && post.hashtags.length > 0 && (
                <div className="post-hashtags">
                  {post.hashtags.map((tag, index) => (
                    <span key={index} className="hashtag">{tag}</span>
                  ))}
                </div>
              )}
              
              {(post.imageUrl || post.imageBase64) && (
                <div className="post-image">
                  {post.imageUrl ? (
                    <img src={post.imageUrl} alt="投稿画像" />
                  ) : post.imageBase64 ? (
                    <img src={`data:image/jpeg;base64,${post.imageBase64}`} alt="投稿画像" />
                  ) : null}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </BaseModal>
  );
};

