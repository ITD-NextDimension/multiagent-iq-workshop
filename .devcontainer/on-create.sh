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
# --clear 不能省。本地 Dev Containers 路线是把宿主机的目录挂进来的，
# 那里可能已经有一个 macOS/Windows 建的 code/.venv：它的 bin/python 指向
# /opt/homebrew/... 之类容器里不存在的路径，不加 --clear 会直接失败
#   Error: [Errno 2] No such file or directory: '.../.venv/bin/python'
# 而且 venv 本身不清 site-packages，会留下一堆 *-darwin.so，import 时才炸。
# venv 完全可以从 requirements 重建，清掉没有任何损失。
step "创建虚拟环境 code/.venv"
python -m venv --clear .venv
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
# 这是一个「检查」，不该有能力弄挂它检查的东西：pipefail 下 pip 的一次
# 抖动会让整个 onCreate 在安装成功之后才失败。
COUNT="$(.venv/bin/python -m pip list --format=freeze 2>/dev/null | wc -l | tr -d ' ')" || COUNT="?"
if [[ "$COUNT" == "64" ]]; then
  ok "已安装 $COUNT 个包"
else
  warn "装出来是 $COUNT 个包，预期 64 个 —— 依赖可能有漂移，课前请复核"
fi

# ---- 3. Azure CLI -----------------------------------------------------------
# 只有 Lab 05 / 05-1 用得到。装不上不该让整个环境构建失败，
# Lab 01-04 完全不受影响。
step "准备 Azure CLI（Lab 05 用）"

# onCreate 以 vscode 身份运行，装系统包要 sudo；某些本地跑法直接就是 root。
as_root() { if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

# az 的版本值得报一下。devcontainer 的 azure-cli feature 正常会从微软的 apt 源
# 装最新版，但它的逻辑是「apt-get update 失败就删掉微软源接着装」——
# 构建时网络一抖，就会静默退回 Debian 自带的 azure-cli（bookworm 是 2.45.0）。
AZ_VER="$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo unknown)"
case "$AZ_VER" in
  unknown) warn "az 没装上 —— Lab 05 会用不了" ;;
  2.[0-9].*|2.[0-4][0-9].*) warn "az 版本偏低（$AZ_VER）—— 像是退回了发行版自带的包，构建时网络可能中断过；Lab 05 前请复核" ;;
  *) ok "az $AZ_VER" ;;
esac

# 装扩展时 az 会 fork 一个 `pip install --target ...`，用的是 **az 自己的**
# 解释器，跟 code/.venv 没有关系。发行版那个 azure-cli 跑在系统 python3.11 上，
# 而这个镜像的系统 python 恰恰没有 pip，于是课上那句
#     az containerapp show ...
# 会触发扩展自动安装，然后以 "Pip failed with status code 1" 收场。
# 学员当场补不了：Codespaces 里 apt / pip 都可能被网络策略拦住。
# 所以 pip 必须在构建阶段补齐，而且要补到 az 真正使用的那个解释器上。
AZ_PY=""
for cand in /opt/az/bin/python3 /usr/local/pipx/venvs/azure-cli/bin/python /usr/bin/python3; do
  if [[ -x "$cand" ]] && "$cand" -c "import azure.cli" >/dev/null 2>&1; then AZ_PY="$cand"; break; fi
done

if [[ -n "$AZ_PY" ]] && ! "$AZ_PY" -m pip --version >/dev/null 2>&1; then
  warn "az 用的解释器（$AZ_PY）没有 pip —— 扩展装不上，现在补"
  as_root apt-get update -qq >/dev/null 2>&1 || true
  as_root apt-get install -y -qq python3-pip >/dev/null 2>&1 || true
  "$AZ_PY" -m pip --version >/dev/null 2>&1 || "$AZ_PY" -m ensurepip --upgrade >/dev/null 2>&1 || true
  if "$AZ_PY" -m pip --version >/dev/null 2>&1; then
    ok "已补上 pip"
  else
    warn "pip 还是缺 —— az 扩展装不了，但 Lab 05-1 的脚本不依赖扩展，仍能跑"
  fi
fi

# 扩展在这里装好，学员课上就不需要装任何东西。
# 装不上也不致命：Lab 05-1 的脚本和文档走的是 az resource show（核心命令，
# 不需要扩展），这里装上只是让 az containerapp 这类顺手命令也能用。
for ext in containerapp communication; do
  az extension show --name "$ext" >/dev/null 2>&1 \
    || az extension add --name "$ext" --only-show-errors >/dev/null 2>&1 || true
  if az extension show --name "$ext" >/dev/null 2>&1; then
    ok "az extension: $ext"
  else
    warn "az extension $ext 没装上 —— Lab 05-1 不受影响，Lab 05 完整版需要时再手动装"
  fi
done

# feature 的 installBicep 在网络不稳时会静默失败，这里补一次。
# Lab 05 / 05-1 都要用 az deployment 跑 .bicep 模板。
# 注意不能只看 az bicep install 的退出码：它可能返回 0 却装下一个跑不起来的
# 二进制（在 arm64 上就会 rosetta error）。装完必须再验一次。
if ! az bicep version >/dev/null 2>&1; then
  az bicep install --only-show-errors >/dev/null 2>&1 || true
fi
if az bicep version >/dev/null 2>&1; then
  ok "bicep $(az bicep version 2>/dev/null | head -1 | tr -d '\n')"
else
  warn "bicep 不可用 —— 只影响 Lab 05，课上可手动 az bicep install"
fi

echo
echo "${D}onCreate 完成。${N}"
