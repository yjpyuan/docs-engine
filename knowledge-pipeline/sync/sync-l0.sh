#!/bin/bash

set -e  # 遇到错误立即退出

# ============================================
# L0 企业宪法层同步脚本
# ============================================
# 功能：
# 1. 克隆 L0 仓库到临时目录
# 2. 仅复制内容（子目录和文件）到目标目录，不包括 .git
# 3. 记录 commit hash 作为版本标识
# 4. 生成元信息文件用于审计和版本管理
# ============================================

# 1. 配置变量
# 公开仓库使用 HTTPS 方式（无需 SSH 密钥）
L0_REPO="${L0_REPO:-https://github.com/yjpyuan/L0-enterprise.git}"  # L0 仓库地址（可通过环境变量覆盖）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/../../engineering-docs-platform/docs/L0-enterprise"  # 目标目录
TEMP_DIR="/tmp/l0-sync-$$"  # 临时目录，使用进程 ID 确保唯一性
BRANCH="${BRANCH:-main}"  # L0 仓库的分支（可通过环境变量覆盖）
META_FILE="$TARGET_DIR/_meta.json"  # 元信息文件

# 2. 创建目标目录
echo "==> [1/6] Preparing target directory..."
mkdir -p "$TARGET_DIR"

# 3. 克隆 L0 仓库到临时目录
echo "==> [2/6] Cloning L0 repository to temporary directory..."
git clone --depth 1 --branch "$BRANCH" "$L0_REPO" "$TEMP_DIR"

# 4. 获取 commit hash 和其他元信息
echo "==> [3/6] Extracting commit information..."
cd "$TEMP_DIR"
COMMIT_HASH=$(git rev-parse HEAD)
COMMIT_SHORT=$(git rev-parse --short HEAD)
COMMIT_DATE=$(git log -1 --format=%cd --date=iso)
COMMIT_AUTHOR=$(git log -1 --format=%an)
COMMIT_MESSAGE=$(git log -1 --format=%s)
REMOTE_URL=$(git config --get remote.origin.url)

echo "    Commit: $COMMIT_HASH"
echo "    Date:   $COMMIT_DATE"
echo "    Author: $COMMIT_AUTHOR"

# 5. 清空目标目录并复制内容（不包括 .git）
echo "==> [4/6] Syncing content to target directory..."
# 删除目标目录中的旧内容（保留 _meta.json）
find "$TARGET_DIR" -mindepth 1 ! -name '_meta.json' -delete

# 复制所有内容（排除 .git 目录）
rsync -av --exclude='.git' "$TEMP_DIR/" "$TARGET_DIR/"

# 6. 生成元信息文件
echo "==> [5/6] Generating metadata file..."
cat > "$META_FILE" <<EOF
{
  "source": {
    "repository": "$REMOTE_URL",
    "branch": "$BRANCH",
    "commit": {
      "hash": "$COMMIT_HASH",
      "short": "$COMMIT_SHORT",
      "date": "$COMMIT_DATE",
      "author": "$COMMIT_AUTHOR",
      "message": "$COMMIT_MESSAGE"
    }
  },
  "sync": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "script_version": "1.0.0"
  },
  "pipeline": {
    "git_repo": "engineering-docs-platform",
    "commit": "$COMMIT_SHORT"
  }
}
EOF

echo "    Metadata saved to: $META_FILE"

# 7. 清理临时目录
echo "==> [6/6] Cleaning up temporary directory..."
rm -rf "$TEMP_DIR"

# 8. 完成
echo ""
echo "✅ L0 repository successfully synced!"
echo "   Target: $TARGET_DIR"
echo "   Version: $COMMIT_SHORT"
echo "   Files synced: $(find "$TARGET_DIR" -type f | wc -l | tr -d ' ')"
echo ""
