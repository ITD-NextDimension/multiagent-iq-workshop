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

# ---- 欢迎信息 ---------------------------------------------------------------
cat <<BANNER

${G}环境就绪${N} ${D}· Python $("$CODE_DIR/.venv/bin/python" --version 2>&1 | cut -d' ' -f2) · $("$CODE_DIR/.venv/bin/python" -m pip list --format=freeze | wc -l | tr -d ' ') 个包${N}

${B}先验证一下（不需要任何凭证）：${N}
  cd code && python mcp/server.py --selftest
  cd code/agents && python test_workflow.py

${B}Lab 03 开始需要 Azure OpenAI 凭证，讲师会在课上发：${N}
  bash .devcontainer/set-key.sh

${D}实验手册：labs/cn/  ·  代码说明：code/README.zh.md${N}

BANNER
