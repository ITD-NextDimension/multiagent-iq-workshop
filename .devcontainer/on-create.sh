#!/usr/bin/env bash
# =============================================================================
# devcontainer · onCreate —— 安装这门课的全部依赖
#
# 为什么是 onCreate 而不是 postCreate：
#   Codespaces 预构建(prebuild)会执行 onCreateCommand，并把结果打进预构建镜像；
#   postCreateCommand 则是每次创建 Codespace 时现跑。把 64 个包的安装放这里，
#   学员开 Codespace 时依赖已经在镜像里，进环境只要几十秒；放错地方的话每个
#   学员都要重装一遍，等 3~5 分钟。
#
# 这里的安装步骤与 code/README.md 给学员的手动步骤严格一致 —— 容器里和本地
# 装出来的必须是同一套东西，否则双轨就失去意义了。
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CODE_DIR="$REPO_ROOT/code"

if [[ -t 1 ]]; then
  G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; N=$'\033[0m'
else G=''; Y=''; B=''; D=''; N=''; fi
step() { echo; echo "${B}==>${N} $1"; }
ok()   { echo "  ${G}✔${N} $1"; }
warn() { echo "  ${Y}!${N} $1"; }

cd "$CODE_DIR"

# ---- 1. 虚拟环境 ------------------------------------------------------------
# 位置必须是 code/.venv：.vscode/mcp.json 里写死了
# ${workspaceFolder}/code/.venv/bin/python，换地方 MCP 服务器就注册不上。
step "创建虚拟环境 code/.venv"
python -m venv .venv
.venv/bin/python -m pip install --quiet --upgrade pip
ok "$(.venv/bin/python --version)"

# ---- 2. 依赖 ----------------------------------------------------------------
# 分两次装，顺序与 code/README.md 一致。三个版本钉死的原因见
# code/agents/requirements.txt 顶部的注释。
step "安装依赖（64 个包，预构建时只跑这一次）"
.venv/bin/python -m pip install --quiet -r mcp/requirements.txt
.venv/bin/python -m pip install --quiet -r agents/requirements.txt

# Lab 01 用包数量当检查点。这里先自查一遍：预构建阶段就能发现问题，
# 总好过课上 30 个学员同时发现。
COUNT="$(.venv/bin/python -m pip list --format=freeze | wc -l | tr -d ' ')"
if [[ "$COUNT" == "64" ]]; then
  ok "已安装 $COUNT 个包"
else
  warn "装出来是 $COUNT 个包，预期 64 个 —— 依赖可能有漂移，课前请复核"
fi

# ---- 3. Azure CLI 扩展 ------------------------------------------------------
# 只有 Lab 05 / 05-1 用得到。装不上不该让整个环境构建失败，
# Lab 01-04 完全不受影响。
step "安装 Azure CLI 扩展（Lab 05 用）"
for ext in containerapp communication; do
  if az extension add --name "$ext" --only-show-errors >/dev/null 2>&1; then
    ok "az extension: $ext"
  else
    warn "az extension $ext 没装上 —— 只影响 Lab 05，需要时可手动重装"
  fi
done

# ---- 4. 终端自动激活 venv ---------------------------------------------------
# 学员按文档敲 `source .venv/bin/activate` 仍然有效（重复激活无副作用），
# 这里只是省掉「忘了激活导致 ModuleNotFoundError」这个课上高频问题。
step "配置终端自动激活虚拟环境"
ACTIVATE="source $CODE_DIR/.venv/bin/activate"
MARKER="# workshop: auto-activate code/.venv"
if ! grep -qF "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
  printf '\n%s\n%s\n' "$MARKER" "$ACTIVATE" >> "$HOME/.bashrc"
fi
ok "新开的终端会自动进入 code/.venv"

echo
echo "${D}onCreate 完成。${N}"
