import React from 'react';
import { TodayPost } from '../hooks/useTodayPosts';
import './PostsModal.css';

interface PostsModalProps {
  posts: TodayPost[];
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
    return date.toLocaleTimeString('ja-JP');
  };

  const argb32ToHex = (argb32: number): string => {
    // ARGB32格式: AARRGGBB，转换为RGB十六进制
    const rgb = (argb32 & 0x00FFFFFF).toString(16).padStart(6, '0');
    return `#${rgb}`;
  };

  return (
    <div className="posts-modal-overlay" onClick={onClose}>
      <div className="posts-modal" onClick={(e) => e.stopPropagation()}>
        <div className="posts-modal-header">
          <h2>📝 今日の投稿</h2>
          <button className="close-button" onClick={onClose}>×</button>
        </div>
        
        <div className="posts-modal-content">
          {loading ? (
            <div className="posts-loading">
              <p>読み込み中...</p>
            </div>
          ) : posts.length === 0 ? (
            <div className="posts-empty">
              <p>今日の投稿はありません</p>
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
        </div>
      </div>
    </div>
  );
};

