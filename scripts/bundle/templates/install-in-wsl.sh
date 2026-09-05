#!/usr/bin/env bash
# =============================================================================
# WSL(Ubuntu) 侧安装 —— 由 install.ps1 自动调用，一般不需要手动跑。
#
# 手动跑（例如 install.ps1 中途失败后重试）：
#   bash ~/workshop-offline/install-in-wsl.sh
#
# 课程所有命令都在这里执行（deploy.sh 是 bash），所以真正的运行时依赖
# ——Python、课程依赖、az、kubectl——都装在 WSL 里，不是 Windows 侧。
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="$HOME/frontier-workshop-precheck"
FAILED=0

if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; N=$'\033[0m'
else R=''; G=''; Y=''; B=''; D=''; N=''; fi
step() { echo; echo "${B}==>${N} $1"; }
ok()   { echo "  ${G}✔${N} $1"; }
warn() { echo "  ${Y}!${N} $1"; }
err()  { echo "  ${R}✘${N} $1"; FAILED=$((FAILED+1)); }
have() { command -v "$1" >/dev/null 2>&1; }

echo "${B}WSL(Ubuntu) 侧环境安装${N}"

# ---- 基础工具 ---------------------------------------------------------------
# python3-venv 在 Debian/Ubuntu 上是独立包，不装的话 `python3 -m venv` 会失败。
# 这几个包很小（几 MB），联网装即可；大件（wheels/az）都在离线包里。
step "基础工具（git / python3 / venv / pip）"
need=""
for pkg in git python3 python3-venv python3-pip; do
  dpkg -s "$pkg" >/dev/null 2>&1 || need="$need $pkg"
done
if [[ -z "$need" ]]; then
  ok "已齐全"
else
  echo "  ${D}需要 sudo 安装：$need${N}"
  if sudo apt-get update -qq && sudo apt-get install -y $need >/dev/null 2>&1; then
    ok "已安装:$need"
  else
    err "apt 安装失败:${need}（检查网络/代理，然后重跑本脚本）"
  fi
fi

# ---- Python 版本 ------------------------------------------------------------
step "Python 版本"
PY=""
py_ok() { local v; v="$("$1" -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null)" || return 1
          [[ "$v" == "3.10" || "$v" == "3.11" || "$v" == "3.12" ]]; }
for c in python3.12 python3.11 python3.10 python3; do
  if have "$c" && py_ok "$c"; then PY="$(command -v "$c")"; break; fi
done
if [[ -n "$PY" ]]; then
  ok "$("$PY" -V 2>&1)"
else
  err "没有 3.10–3.12 的 Python（Ubuntu 24.04 自带 3.12，正常不该走到这里）"
fi

# ---- 课程依赖（本地 wheels，不联网）----------------------------------------
step "课程依赖（本地安装，不联网）"
if [[ -z "$PY" ]]; then
  err "跳过（没有可用的 Python）"
elif [[ ! -d "$HERE/wheels" ]]; then
  err "缺少 wheels/ 目录"
else
  mkdir -p "$WORKDIR"
  [[ -x "$WORKDIR/.venv/bin/python" ]] || "$PY" -m venv "$WORKDIR/.venv" 2>/dev/null
  VPY="$WORKDIR/.venv/bin/python"
  if [[ -x "$VPY" ]]; then
    REQ="$HERE/../requirements.txt"
    [[ -f "$REQ" ]] || REQ="$HERE/requirements.txt"
    if [[ -f "$REQ" ]]; then
      # --no-index 强制只用本地 wheel：网络再慢也不影响这一步。
      if "$VPY" -m pip install -q --no-index --find-links "$HERE/wheels" -r "$REQ" 2>/tmp/pipfail.$$; then
        ok "$("$VPY" -m pip list --format=freeze 2>/dev/null | wc -l | tr -d ' ') 个包已装好"
      else
        err "依赖安装失败"; sed 's/^/      /' /tmp/pipfail.$$ | tail -6
      fi
      rm -f /tmp/pipfail.$$
    else
      err "找不到 requirements.txt"
    fi
  else
    err "虚拟环境创建失败（可能缺 python3-venv）"
  fi
fi

# ---- kubectl ----------------------------------------------------------------
step "Lab 05 工具"
if have kubectl; then
  ok "kubectl 已安装"
elif [[ -f "$HERE/kubectl-linux-amd64" ]]; then
  sudo install -m 0755 "$HERE/kubectl-linux-amd64" /usr/local/bin/kubectl \
    && ok "kubectl 已安装" || err "kubectl 安装失败"
else
  err "缺少 kubectl-linux-amd64"
fi

# ---- Azure CLI --------------------------------------------------------------
if have az; then
  ok "Azure CLI 已安装"
elif [[ -f "$HERE/azure-cli.deb" ]]; then
  echo "  ${D}正在从本地 .deb 安装 Azure CLI ...${N}"
  if sudo apt-get install -y "$HERE/azure-cli.deb" >/dev/null 2>&1; then
    ok "Azure CLI 已安装（离线）"
  else
    err "Azure CLI 离线安装失败（可能是 Ubuntu 版本不匹配）"
    echo "     ${D}联网兜底：curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash${N}"
  fi
else
  warn "包里没有 azure-cli.deb，需联网安装"
  echo "     ${D}curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash${N}"
fi

# containerapp 是动态扩展，deploy.sh / teardown.sh 都要用。它很小，联网装即可。
if have az; then
  if az extension show --name containerapp >/dev/null 2>&1; then
    ok "az 扩展 containerapp"
  elif az extension add --name containerapp --only-show-errors >/dev/null 2>&1; then
    ok "az 扩展 containerapp 已安装"
  else
    warn "az 扩展 containerapp 未装（Lab 05 部署要用）"
    echo "     ${D}az extension add --name containerapp${N}"
  fi
fi

# ---- 回执 -------------------------------------------------------------------
echo
if [[ $FAILED -eq 0 ]]; then
  verdict="READY"
else
  verdict="NOT-READY"
fi
receipt="[precheck] ${verdict} | wsl | $( [[ -n "$PY" ]] && "$PY" -V 2>&1 || echo 'no-python' ) | FAIL=${FAILED}"
echo "${B}================ 回执 ================${N}"
echo "  $receipt"
echo
if [[ $FAILED -eq 0 ]]; then
  echo "${G}WSL 侧就绪。${N}把上面那行回执发到班级群。"
  exit 0
else
  echo "${R}WSL 侧还有 $FAILED 项未通过。${N}修完重跑：bash ~/workshop-offline/install-in-wsl.sh"
  exit 1
fi
