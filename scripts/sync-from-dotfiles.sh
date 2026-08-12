#!/bin/sh
# 把 statusline-command.sh 从唯一真相源(私有 dotfiles)同步到本公开教程仓库。
#
# 为什么要这个脚本:
#   - 真相源 = ~/dotfiles/claude/statusline-command.sh(私有,两台 Mac 软链共用)
#   - 本仓库是公开教程,读者需要一份真实可读的脚本,不能放指向私有路径的软链
#   - 所以这里保留一份真实快照;改完 dotfiles 后跑一下本脚本再提交,即可保持一致、不手抄、不漂移
#
# 同步两处(缺一就会漂):
#   1. 仓库根的 statusline-command.sh 快照(读者 curl 下载的那份)
#   2. README 技巧 3 里贴出来的那段代码(读者手抄的那份)
#      —— 靠 README 里 <!-- BEGIN/END statusline-command.sh --> 两行锚点定位
#
# 用法:  ./scripts/sync-from-dotfiles.sh   然后  git add -A && git commit && git push

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${DOTFILES:-$HOME/dotfiles}/claude/statusline-command.sh"
DEST="$ROOT/statusline-command.sh"
README="$ROOT/README.md"

if [ ! -f "$SRC" ]; then
  echo "✗ 源文件不存在: $SRC" >&2
  echo "  (设 DOTFILES 环境变量指向你的 dotfiles 根,或确认 ~/dotfiles 已克隆)" >&2
  exit 1
fi

cp "$SRC" "$DEST"

# README 里的那份用锚点整段换掉
if grep -q '<!-- BEGIN statusline-command.sh' "$README" && grep -q '<!-- END statusline-command.sh -->' "$README"; then
  TMP="$README.tmp.$$"
  awk -v src="$SRC" '
    /<!-- BEGIN statusline-command.sh/ {
      print; print "```sh"
      while ((getline line < src) > 0) print line
      close(src)
      print "```"
      skip = 1
      next
    }
    /<!-- END statusline-command.sh -->/ { skip = 0 }
    !skip { print }
  ' "$README" > "$TMP"
  mv "$TMP" "$README"
  echo "✓ README 技巧 3 里的代码块已回填"
else
  echo "⚠ README 里找不到 <!-- BEGIN/END statusline-command.sh --> 锚点,只同步了快照文件" >&2
fi

if git -C "$ROOT" diff --quiet -- statusline-command.sh README.md 2>/dev/null; then
  echo "✓ 已是最新,无变化"
else
  echo "✓ 已从 dotfiles 同步:$DEST"
  echo "  记得提交:git add statusline-command.sh README.md && git commit && git push"
fi
