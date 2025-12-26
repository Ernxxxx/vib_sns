import React, { useState, useEffect } from 'react';
import { Login } from './components/Login';
import { Dashboard } from './components/Dashboard';
import { checkAuthState, initializeAuth } from './services/auth';
import './App.css';

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [loading, setLoading] = useState(true);
  const [firebaseAuthReady, setFirebaseAuthReady] = useState(false);

  useEffect(() => {
    // Firebase匿名認証を初期化
    const initFirebase = async () => {
      try {
        const user = await initializeAuth();
        if (user) {
          console.log('Firebase認証成功');
          setFirebaseAuthReady(true);
        } else {
          console.error('Firebase認証に失敗しました');
          setFirebaseAuthReady(true); // エラーでも続行
        }
      } catch (error) {
        console.error('Firebase初期化エラー:', error);
        setFirebaseAuthReady(true);
      }
    };

    initFirebase();
  }, []);

  useEffect(() => {
    // Firebase認証が準備できたら、管理者認証状態を確認
    if (firebaseAuthReady) {
      const authenticated = checkAuthState();
      setIsAuthenticated(authenticated);
      setLoading(false);
    }
  }, [firebaseAuthReady]);

  const handleLoginSuccess = () => {
    setIsAuthenticated(true);
  };

  const handleLogout = () => {
    setIsAuthenticated(false);
  };

  if (loading || !firebaseAuthReady) {
    return (
      <div className="app-loading">
        <p>読み込み中...</p>
        <p style={{ fontSize: '14px', color: '#999', marginTop: '8px' }}>
          Firebaseに接続しています...
        </p>
      </div>
    );
  }

  return (
    <div className="App">
      {isAuthenticated ? (
        <Dashboard onLogout={handleLogout} />
      ) : (
        <Login onLoginSuccess={handleLoginSuccess} />
      )}
    </div>
  );
}

export default App;
