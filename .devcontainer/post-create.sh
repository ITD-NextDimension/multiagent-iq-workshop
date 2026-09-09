#!/usr/bin/env bash
# =============================================================================
# devcontainer · postCreate —— 每个学员各自的初始化
#
# 这里只做「每人一份」且很轻的事。重活在 on-create.sh，那部分会被 Codespaces
# 预构建打进镜像；写到这里的话每个学员都要重跑一遍。
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CODE_DIR="$REPO_ROOT/code"

if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; N=$'\033[0m'
else R=''; G=''; Y=''; B=''; D=''; N=''; fi

# ---- 环境自检 ---------------------------------------------------------------
# 没有预构建时 onCreate 是现跑的，可能失败。与其打印一个骗人的「环境就绪」，
# 不如直接告诉学员出了什么事。
if [[ ! -x "$CODE_DIR/.venv/bin/python" ]]; then
  echo
  echo "${R}✘ 虚拟环境没建起来（找不到 code/.venv/bin/python）${N}"
  echo "${D}  依赖安装可能失败了。在终端里手动重跑：${N}"
  echo "${D}    bash .devcontainer/on-create.sh${N}"
  echo "${D}  还是不行就找讲师，或改用课前发的离线安装包。${N}"
  echo
  exit 0   # 不阻断容器启动，让学员还能进终端排查
fi

# ---- .env 模板 --------------------------------------------------------------
# 只在不存在时创建，不覆盖学员已经填好的值（重建容器时尤其重要）。
# 真实的 Key 由讲师课上发放，用 .devcontainer/set-key.sh 填。
if [[ ! -f "$CODE_DIR/agents/.env" ]]; then
  cp "$CODE_DIR/agents/.env.example" "$CODE_DIR/agents/.env"
  chmod 600 "$CODE_DIR/agents/.env"
fi

# ---- 终端自动激活 venv -------------------------------------------------------
# 放在 postCreate 而不是 onCreate：预构建快照是否包含 $HOME 没有明确保证，
# 而这只是两行追加，每次创建都跑一遍的成本可以忽略，换来的是确定性。
# 学员按文档敲 `source .venv/bin/activate` 仍然有效（重复激活无副作用）。
#
# 两个细节都不能省：
#   * [ -f ] 守卫 —— venv 万一没建起来，不能让每个新终端都先吐一行
#     "No such file or directory" 才让学员打字。
#   * 路径加引号 —— 本地路线下工作区目录名可能含空格。
MARKER="# workshop: auto-activate code/.venv"
if ! grep -qF "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
  {
    printf '\n%s\n' "$MARKER"
    printf '[ -f "%s/.venv/bin/activate" ] && . "%s/.venv/bin/activate"\n' "$CODE_DIR" "$CODE_DIR"
  } >> "$HOME/.bashrc"
fi

# ---- 欢迎信息 ---------------------------------------------------------------
cat <<BANNER

${G}环境就绪${N} ${D}· Python $("$CODE_DIR/.venv/bin/python" --version 2>&1 | cut -d' ' -f2) · $("$CODE_DIR/.venv/bin/python" -m pip list --format=freeze | wc -l | tr -d ' ') 个包${N}

${B}先验证一下（不需要任何凭证）：${N}
  cd /workspaces/*/code && python mcp/server.py --selftest
  cd /workspaces/*/code/agents && python test_workflow.py

${B}Lab 03 开始需要 Azure OpenAI 凭证，讲师会在课上发：${N}
  bash /workspaces/*/.devcontainer/set-key.sh

${D}实验手册：labs/cn/  ·  代码说明：code/README.zh.md${N}

BANNER
