#!/bin/bash

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}开始构建无签名IPA文件...${NC}"

# 清理旧的构建
echo -e "${BLUE}清理旧的构建文件...${NC}"
rm -rf build/mantou.app
rm -rf build/Payload
rm -f build/mantou.ipa

# 创建必要的目录
mkdir -p build

# 构建应用程序 - 使用特定的目标设备
echo -e "${BLUE}正在构建应用程序...${NC}"
xcodebuild -project mantou.xcodeproj -scheme mantou -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

if [ $? -ne 0 ]; then
    echo -e "${RED}构建失败!${NC}"
    exit 1
fi

# 查找 .app 文件
APP_PATH=$(find build/DerivedData -name "*.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}找不到构建的 .app 文件!${NC}"
    exit 1
fi

echo -e "${GREEN}找到应用程序: $APP_PATH${NC}"

# 创建 Payload 目录
mkdir -p build/Payload
cp -r "$APP_PATH" build/Payload/

# 打包成 IPA
echo -e "${BLUE}打包成IPA文件...${NC}"
cd build && zip -r mantou.ipa Payload && cd ..

if [ -f build/mantou.ipa ]; then
    echo -e "${GREEN}成功创建未签名IPA: $(pwd)/build/mantou.ipa${NC}"
else
    echo -e "${RED}IPA创建失败!${NC}"
    exit 1
fi

echo -e "${BLUE}清理临时文件...${NC}"
rm -rf build/Payload
rm -rf build/DerivedData

echo -e "${GREEN}构建完成!${NC}"
