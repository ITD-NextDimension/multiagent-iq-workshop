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
# 只认 3.12：包里 63 个 wheel 有 13 个是 cp312 专用，3.10/3.11 装不上。
# 最常见的受害者是 WSL 里已经装了 Ubuntu 22.04（自带 python3.10）的学员 ——
# 放行 3.10 只会让他在下一步撞上一句无从下手的"依赖安装失败"。
step "Python 3.12"
PY=""
py_ok() { local v; v="$("$1" -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null)" || return 1
          [[ "$v" == "3.12" ]]; }
for c in python3.12 python3; do
  if have "$c" && py_ok "$c"; then PY="$(command -v "$c")"; break; fi
done
if [[ -n "$PY" ]]; then
  ok "$("$PY" -V 2>&1)"
else
  CUR="$(python3 -V 2>&1 || echo '无 python3')"
  err "需要 Python 3.12，当前是 ${CUR}"
  echo "     ${D}这个离线包的依赖只支持 3.12。你的 WSL 大概率是 Ubuntu 22.04。${N}"
  echo "     ${D}查看：wsl -l -v （在 Windows 侧执行）${N}"
  echo "     ${D}方案一（推荐）：装 Ubuntu 24.04 —— wsl --install -d Ubuntu-24.04${N}"
  echo "     ${D}方案二：sudo add-apt-repository ppa:deadsnakes/ppa \\${N}"
  echo "     ${D}          && sudo apt-get install -y python3.12 python3.12-venv${N}"
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

# 把 wheel 留一份到工作目录：课上在仓库里另建 code/.venv 时可以照样离线装。
# --no-index 安装不写 pip 的 HTTP 缓存，不留这份的话课上仍要下约 210MB。
if [[ -d "$HERE/wheels" ]]; then
  mkdir -p "$WORKDIR/wheels"
  cp -n "$HERE/wheels"/*.whl "$WORKDIR/wheels/" 2>/dev/null || true
  _req="$HERE/../requirements.txt"
  [[ -f "$_req" ]] || _req="$HERE/requirements.txt"
  [[ -f "$_req" ]] && cp -n "$_req" "$WORKDIR/requirements.txt" 2>/dev/null || true
  ok "wheel 已留存到 $WORKDIR/wheels（课上离线装用）"
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

# containerapp / communication 都是动态扩展，deploy.sh 与 teardown.sh 要用。
# 它们很小，联网装即可。communication 特别重要：deploy.sh 用它取 ACS 连接串，
# 失败点在 ACR/AKS/ACA 都建好之后，学员会在最后 30 分钟眼看着部署崩掉。
if have az; then
  for ext in containerapp communication; do
    if az extension show --name "$ext" >/dev/null 2>&1; then
      ok "az 扩展 $ext"
    elif az extension add --name "$ext" --only-show-errors >/dev/null 2>&1; then
      ok "az 扩展 $ext 已安装"
    else
      warn "az 扩展 $ext 未装（Lab 05 部署要用）"
      echo "     ${D}az extension add --name ${ext}${N}"
    fi
  done
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
