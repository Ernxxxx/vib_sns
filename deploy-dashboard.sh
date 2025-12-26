#!/bin/bash
# 部署 Dashboard 到 /dashboard 路径的脚本
# 同时构建 Flutter Web 应用和 Dashboard

set -e

echo "📦 构建 Flutter Web 应用..."
flutter build web || {
  echo "⚠️  Flutter 构建失败，请确保已安装 Flutter 并配置正确"
  echo "   如果 Flutter Web 应用已构建，将跳过此步骤"
}

echo "📦 构建 Dashboard..."
cd dashboard
npm run build
cd ..

echo "📋 复制 Dashboard 文件到 build/web/dashboard..."
mkdir -p build/web/dashboard
cp -r dashboard/build/* build/web/dashboard/

echo "🔍 检查构建结果..."
if [ ! -f "build/web/index.html" ]; then
  echo "❌ 错误: build/web/index.html 不存在"
  echo "   请先运行 'flutter build web' 构建 Flutter Web 应用"
  exit 1
fi

if [ ! -f "build/web/dashboard/index.html" ]; then
  echo "❌ 错误: build/web/dashboard/index.html 不存在"
  exit 1
fi

echo "🚀 部署到 Firebase Hosting..."
firebase deploy --only hosting

echo "✅ 部署完成！"
echo "📍 Dashboard 访问地址: https://vib-sns-prod.web.app/dashboard"
echo "📍 原应用访问地址: https://vib-sns-prod.web.app"

