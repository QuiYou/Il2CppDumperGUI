#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Il2CppDumperGUI Git 推送助手${NC}"
echo -e "${BLUE}========================================${NC}"

if git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠️  没有检测到任何更改，无需提交。${NC}"
    exit 0
fi

echo -e "\n${GREEN}📋 检测到的更改：${NC}"
git status --short

echo -e "\n${BLUE}💬 请输入提交信息（留空则使用默认）:${NC}"
read -p "> " commit_msg

if [ -z "$commit_msg" ]; then
    commit_msg="更新项目文件 $(date +'%Y-%m-%d %H:%M:%S')"
    echo -e "${YELLOW}使用默认信息: ${commit_msg}${NC}"
fi

echo -e "\n${GREEN}📦 添加所有更改...${NC}"
git add .

echo -e "${GREEN}📝 提交更改...${NC}"
git commit -m "$commit_msg"

echo -e "${GREEN}🚀 推送到 GitHub...${NC}"
git push

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ 推送成功！${NC}"
    echo -e "${BLUE}🔗 https://github.com/QuiYou/Il2CppDumperGUI${NC}"
else
    echo -e "\n${RED}❌ 推送失败，请检查网络或手动处理。${NC}"
    exit 1
fi
