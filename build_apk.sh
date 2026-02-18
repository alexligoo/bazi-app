#!/bin/bash
# ============================================================
# 八字排盘 App — Android APK 一键打包脚本
# 用法: sh build_apk.sh
# ============================================================

set -e

APP_DIR="$HOME/bazi_app"
KEYSTORE_DIR="$APP_DIR/android/app"
KEYSTORE_FILE="$KEYSTORE_DIR/bazi-release-key.jks"
KEY_PROPERTIES="$APP_DIR/android/key.properties"

export PATH="$HOME/development/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export JAVA_HOME=$(/usr/libexec/java_home)

echo "=== 八字排盘 APK 打包 ==="

# 1. 生成签名文件（如果不存在）
if [ ! -f "$KEYSTORE_FILE" ]; then
  echo ">>> 生成签名文件..."
  keytool -genkey -v \
    -keystore "$KEYSTORE_FILE" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias bazi \
    -storepass bazi123456 \
    -keypass bazi123456 \
    -dname "CN=BaZi, OU=Dev, O=BaZi, L=HK, ST=HK, C=CN"
  echo ">>> 签名文件已生成: $KEYSTORE_FILE"
fi

# 2. 生成 key.properties
if [ ! -f "$KEY_PROPERTIES" ]; then
  echo ">>> 生成 key.properties..."
  cat > "$KEY_PROPERTIES" << EOF
storePassword=bazi123456
keyPassword=bazi123456
keyAlias=bazi
storeFile=bazi-release-key.jks
EOF
  echo ">>> key.properties 已生成"
fi

# 3. 打包 APK
echo ">>> 开始打包 APK..."
cd "$APP_DIR"
flutter build apk --release

echo ""
echo "=== 打包完成 ==="
echo "APK 文件位置: $APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
echo "可以直接传到 Android 手机安装"
