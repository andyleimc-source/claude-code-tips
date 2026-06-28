#!/bin/sh
# 把 statusline-command.sh 从唯一真相源(私有 dotfiles)同步到本公开教程仓库。
#
# 为什么要这个脚本:
#   - 真相源 = ~/dotfiles/claude/statusline-command.sh(私有,两台 Mac 软链共用)
#   - 本仓库是公开教程,读者需要一份真实可读的脚本,不能放指向私有路径的软链
#   - 所以这里保留一份真实快照;改完 dotfiles 后跑一下本脚本再提交,即可保持一致、不手抄、不漂移
#
# 用法:  ./scripts/sync-from-dotfiles.sh   然后  git add -A && git commit && git push

set -e

SRC="${DOTFILES:-$HOME/dotfiles}/claude/statusline-command.sh"
DEST="$(cd "$(dirname "$0")/.." && pwd)/statusline-command.sh"

if [ ! -f "$SRC" ]; then
  echo "✗ 源文件不存在: $SRC" >&2
  echo "  (设 DOTFILES 环境变量指向你的 dotfiles 根,或确认 ~/dotfiles 已克隆)" >&2
  exit 1
fi

cp "$SRC" "$DEST"

if git -C "$(dirname "$DEST")" diff --quiet -- statusline-command.sh 2>/dev/null; then
  echo "✓ 已是最新,无变化:$DEST"
else
  echo "✓ 已从 dotfiles 同步:$DEST"
  echo "  记得提交:git add statusline-command.sh && git commit -m 'sync statusline from dotfiles' && git push"
fi
