import { signInAnonymously, onAuthStateChanged, User } from 'firebase/auth';
import { auth } from './firebase';

// 管理员密码通过环境变量注入，避免明文写在代码中
const ADMIN_PASSWORD = process.env.REACT_APP_ADMIN_PASSWORD?.trim();

/**
 * 初始化Firebase匿名认证
 */
export const initializeAuth = async (): Promise<User | null> => {
  try {
    // 如果已经有用户，直接返回
    if (auth.currentUser) {
      return auth.currentUser;
    }

    // 尝试匿名登录
    const userCredential = await signInAnonymously(auth);
    console.log('匿名認証成功:', userCredential.user.uid);
    return userCredential.user;
  } catch (error) {
    console.error('匿名認証に失敗:', error);
    return null;
  }
};

/**
 * 监听认证状态变化
 */
export const onAuthStateChange = (callback: (user: User | null) => void) => {
  return onAuthStateChanged(auth, callback);
};

/**
 * 验证管理员密码
 */
export const isAdminPasswordConfigured = (): boolean => {
  return Boolean(ADMIN_PASSWORD);
};

/**
 * 验证管理员密码
 */
export const verifyAdminPassword = (password: string): boolean => {
  if (!ADMIN_PASSWORD) {
    console.warn('管理者パスワードが設定されていません。環境変数 REACT_APP_ADMIN_PASSWORD を設定してください。');
    return false;
  }
  return password === ADMIN_PASSWORD;
};

/**
 * 将认证状态保存到localStorage
 */
export const saveAuthState = (isAuthenticated: boolean): void => {
  localStorage.setItem('admin_authenticated', String(isAuthenticated));
  if (isAuthenticated) {
    localStorage.setItem('admin_auth_time', Date.now().toString());
  } else {
    localStorage.removeItem('admin_auth_time');
  }
};

/**
 * 检查是否已认证（24小时内有效）
 */
export const checkAuthState = (): boolean => {
  const authenticated = localStorage.getItem('admin_authenticated') === 'true';
  const authTime = localStorage.getItem('admin_auth_time');
  
  if (!authenticated || !authTime) {
    return false;
  }
  
  // 检查是否超过24小时
  const timeDiff = Date.now() - parseInt(authTime, 10);
  const hours24 = 24 * 60 * 60 * 1000;
  
  if (timeDiff > hours24) {
    saveAuthState(false);
    return false;
  }
  
  return true;
};

/**
 * 登出
 */
export const logout = (): void => {
  saveAuthState(false);
};
