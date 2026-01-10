#!/bin/bash

APP_NAME="StatusCmdManager"
SOURCES="Sources/StatusCmdManager/*.swift"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "编译 Swift 代码..."
swiftc $SOURCES \
    -o "$MACOS_DIR/$APP_NAME" \
    -target arm64-apple-macosx12.0 \
    -sdk $(xcrun --show-sdk-path --sdk macosx) \
    -O

if [ $? -ne 0 ]; then
    echo "编译失败！"
    exit 1
fi

echo "复制资源..."
cp Sources/StatusCmdManager/Info.plist "$CONTENTS_DIR/"

# 签名（本地运行需要 ad-hoc 签名）
echo "签名应用..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "构建完成！"
echo "你可以通过运行 open $APP_BUNDLE 来启动应用"
