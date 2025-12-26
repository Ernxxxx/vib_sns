import React, { useState, FormEvent } from 'react';
import { verifyAdminPassword, saveAuthState, isAdminPasswordConfigured } from '../services/auth';
import './Login.css';

interface LoginProps {
  onLoginSuccess: () => void;
}

export const Login: React.FC<LoginProps> = ({ onLoginSuccess }) => {
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const passwordConfigured = isAdminPasswordConfigured();

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    // 模拟验证延迟
    setTimeout(() => {
      if (verifyAdminPassword(password)) {
        saveAuthState(true);
        onLoginSuccess();
      } else {
        setError('パスワードが間違っています。もう一度お試しください');
        setPassword('');
      }
      setLoading(false);
    }, 300);
  };

  return (
    <div className="login-container">
      <div className="login-box">
        <div className="login-header">
          <h1>🔐 管理ダッシュボード</h1>
          <p>管理者パスワードを入力してください</p>
        </div>
        
        <form onSubmit={handleSubmit} className="login-form">
          <div className="form-group">
            <label htmlFor="password">管理者パスワード</label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="パスワードを入力"
              autoFocus
              disabled={loading}
            />
          </div>
          
          {error && <div className="error-message">{error}</div>}
          {!passwordConfigured && (
            <div className="error-message">
              管理者パスワードが構成されていません。`REACT_APP_ADMIN_PASSWORD` を .env に設定してください。
            </div>
          )}
          
          <button 
            type="submit" 
            className="login-button"
            disabled={loading || !password || !passwordConfigured}
          >
            {loading ? '確認中...' : 'ログイン'}
          </button>
        </form>
      </div>
    </div>
  );
};

