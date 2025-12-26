import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

// Firebase配置 - 从Flutter项目的firebase_options.dart获取
const firebaseConfig = {
  apiKey: 'AIzaSyDVCjnjYL8FcxywHc4jwMIMDk1ZlZxExu0',
  authDomain: 'vib-sns-prod.firebaseapp.com',
  projectId: 'vib-sns-prod',
  storageBucket: 'vib-sns-prod.firebasestorage.app',
  messagingSenderId: '115691400203',
  appId: '1:115691400203:web:9fdd9f9de392913a6eab0e',
  measurementId: 'G-GBYDE6M5YM',
};

// 初始化Firebase
const app = initializeApp(firebaseConfig);

// 导出服务
export const db = getFirestore(app);
export const auth = getAuth(app);
export default app;

