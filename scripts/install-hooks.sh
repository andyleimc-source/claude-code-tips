#!/bin/sh
# 安装本仓库的 git hooks:把 core.hooksPath 指向 scripts/hooks。
# 在每台要用的机器上跑一次即可:  ./scripts/install-hooks.sh
#
# 说明:core.hooksPath 是本机 git 配置、不随 clone 传播,所以公开 clone 者默认不启用,
#       只有你自己跑过本脚本的机器才会在提交前自动同步 statusline。

set -e
ROOT="$(git rev-parse --show-toplevel)"
git -C "$ROOT" config core.hooksPath scripts/hooks
chmod +x "$ROOT/scripts/hooks/"* 2>/dev/null || true
echo "✓ hooks 已启用:core.hooksPath = scripts/hooks"
