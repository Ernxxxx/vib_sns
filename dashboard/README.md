# VIB SNS 管理仪表盘

React + TypeScript + Firebase 构建的管理仪表盘，用于监控 VIB SNS 应用的实时状态和用户活动。

## 功能特性

- 🔐 密码保护登录（密码：hal222）
- 👥 实时在线用户统计和列表
- 📊 活动数据统计（帖子、情感帖子、新用户等）
- 📈 24小时活动趋势图表
- 🎨 现代化响应式UI设计

## 技术栈

- React 18
- TypeScript
- Firebase (Firestore)
- Recharts (图表库)

## 安装和运行

### 1. 安装依赖

```bash
cd dashboard
npm install
```

### 2. 启动开发服务器

```bash
npm start
```

应用将在 http://localhost:3000 打开

### 3. 构建生产版本

```bash
npm run build
```

## 部署

### 使用 Firebase Hosting

1. 构建项目：
```bash
npm run build
```

2. 部署到 Firebase：
```bash
firebase deploy --only hosting
```

### 使用其他平台

构建后的文件在 `build` 目录，可以部署到：
- Vercel
- Netlify
- GitHub Pages
- 任何静态网站托管服务

## 项目结构

```
dashboard/
├── public/
│   └── index.html
├── src/
│   ├── components/      # React 组件
│   │   ├── Login.tsx
│   │   ├── Dashboard.tsx
│   │   ├── StatsCard.tsx
│   │   ├── ActivityChart.tsx
│   │   └── OnlineUsersList.tsx
│   ├── hooks/          # 自定义 Hooks
│   │   ├── useOnlineUsers.ts
│   │   └── useActivityStats.ts
│   ├── services/       # 服务层
│   │   ├── firebase.ts
│   │   └── auth.ts
│   ├── App.tsx
│   └── index.tsx
└── package.json
```

## 数据源

仪表盘从以下 Firestore 集合获取数据：

- `streetpass_presences` - 在线用户状态
- `profiles` - 用户资料
- `timelinePosts` - 时间线帖子
- `emotion_map_posts` - 情感地图帖子

## 安全说明

- 管理员密码存储在客户端代码中（hal222）
- 建议在生产环境中使用 Firebase Functions 进行服务端验证
- 考虑添加 IP 白名单或其他安全措施

## 许可证

与主项目相同

