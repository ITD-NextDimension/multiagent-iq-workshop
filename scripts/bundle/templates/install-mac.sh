#!/usr/bin/env bash
# =============================================================================
# 企业 AI 化转型 Lab · AI Company —— 一键安装（macOS）
#
# 讲师已经把所有大文件放进这个包了，这个脚本只做"安装"，不下载。
#
#   bash install.sh          # 一键装（推荐）
#   bash install.sh --dry-run # 只看会做什么，不动系统
#
# 反复运行是安全的：已经装好的会跳过。
# 装完会自动跑一次环境自检，最后打印一行回执，发到班级群就算完成。
# =============================================================================
set -uo pipefail

DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --help|-h) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "未知参数: $a" >&2; exit 1 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="$HOME/frontier-workshop-precheck"

if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; N=$'\033[0m'
else R=''; G=''; Y=''; B=''; D=''; N=''; fi
step() { echo; echo "${B}==>${N} $1"; }
ok()   { echo "  ${G}✔${N} $1"; }
warn() { echo "  ${Y}!${N} $1"; }
err()  { echo "  ${R}✘${N} $1"; FAILED=$((FAILED+1)); }
run()  { if [[ $DRY -eq 1 ]]; then echo "  ${D}[dry-run] $*${N}"; else "$@"; fi; }
have() { command -v "$1" >/dev/null 2>&1; }
FAILED=0

echo "${B}企业 AI 化转型 Lab · AI Company —— 一键安装（macOS）${N}"
[[ $DRY -eq 1 ]] && echo "${Y}dry-run 模式：不会真的改动系统${N}"

# ---- 架构核对 ---------------------------------------------------------------
# 这个包是按架构打的。下错包的话与其让 pip 报一堆看不懂的错，不如在这里直接讲清楚。
step "机器架构"
ARCH="$(uname -m)"
BUNDLE_ARCH="$(cat "$HERE/arch.txt" 2>/dev/null | tr -d '[:space:]')"
case "$ARCH" in
  arm64)  ARCH_NAME="Apple Silicon" ;;
  x86_64) ARCH_NAME="Intel" ;;
  *) err "不认识的架构 $ARCH"; exit 1 ;;
esac

if [[ -n "$BUNDLE_ARCH" && "$BUNDLE_ARCH" != "$ARCH" ]]; then
  case "$BUNDLE_ARCH" in
    arm64)  want="Apple Silicon"; pkg="workshop-bundle-mac-arm64.zip" ;;
    x86_64) want="Intel";         pkg="workshop-bundle-mac-intel.zip" ;;
    *)      want="$BUNDLE_ARCH";  pkg="另一个 mac 包" ;;
  esac
  echo
  echo "${R}你下错包了。${N}"
  echo "  这台电脑是 ${G}${ARCH_NAME}${N}，但这个包是给 ${Y}${want}${N} 的。"
  echo "  请到班级群下载：${G}$( [[ "$ARCH" == "arm64" ]] && echo workshop-bundle-mac-arm64.zip || echo workshop-bundle-mac-intel.zip )${N}"
  echo "  ${D}（当前这个包是 ${pkg}）${N}"
  exit 1
fi
ok "$ARCH_NAME ($ARCH)"

WHEEL_DIR="$HERE/wheels"
KUBECTL_BIN="$HERE/installers/kubectl"

# ---- VS Code ----------------------------------------------------------------
step "VS Code"
CODE_APP="/Applications/Visual Studio Code.app"
CODE_CLI="$CODE_APP/Contents/Resources/app/bin/code"
if [[ -d "$CODE_APP" ]]; then
  ok "已安装，跳过"
else
  ZIP="$(ls "$HERE"/installers/VSCode-darwin*.zip 2>/dev/null | head -1)"
  if [[ -n "$ZIP" && -f "$ZIP" ]]; then
    # ditto 保留 macOS 的 app bundle 元数据，unzip 会破坏签名。
    run ditto -xk "$ZIP" /Applications/ && ok "已安装到 /Applications" || err "解压失败"
    # Gatekeeper 会因为文件来自"网络下载"而拦截首次启动。
    run xattr -dr com.apple.quarantine "$CODE_APP" 2>/dev/null || true
  else
    err "包里缺少 VS Code 安装包"
  fi
fi

# 让 `code` 命令可用（装扩展要靠它）。
if [[ -x "$CODE_CLI" ]] && ! have code; then
  if [[ -w /usr/local/bin ]] || [[ $DRY -eq 1 ]]; then
    run ln -sf "$CODE_CLI" /usr/local/bin/code && ok "已链接 code 命令"
  else
    warn "无法写入 /usr/local/bin，稍后可在 VS Code 里按 ⇧⌘P → Shell Command: Install 'code' command"
  fi
fi

# ---- Python -----------------------------------------------------------------
step "Python 3.10–3.12"
PY=""
py_ok() { local v; v="$("$1" -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null)" || return 1
          [[ "$v" == "3.10" || "$v" == "3.11" || "$v" == "3.12" ]]; }
for c in python3.12 python3.11 python3.10 python3; do
  if have "$c" && py_ok "$c"; then PY="$(command -v "$c")"; break; fi
done
if [[ -n "$PY" ]]; then
  ok "$("$PY" -V 2>&1) ${D}($PY)${N}"
else
  PKG="$(ls "$HERE"/installers/python-*-macos11.pkg 2>/dev/null | head -1)"
  if [[ -f "$PKG" ]]; then
    echo "  ${D}需要管理员密码来安装 Python${N}"
    run sudo installer -pkg "$PKG" -target / && ok "Python 已安装" || err "Python 安装失败"
    for c in python3.12 python3.11 python3.10 python3; do
      have "$c" && py_ok "$c" && { PY="$(command -v "$c")"; break; }
    done
    [[ -z "$PY" && $DRY -eq 0 ]] && err "装完仍找不到可用的 Python"
  else
    err "包里缺少 Python 安装器"
  fi
fi

# ---- 课程依赖（全部来自本地 wheels，不联网）--------------------------------
step "课程依赖（本地安装，不联网）"
if [[ $DRY -eq 1 ]]; then
  echo "  ${D}[dry-run] 会在 $WORKDIR/.venv 里从 $WHEEL_DIR 安装${N}"
elif [[ -z "$PY" ]]; then
  err "跳过（没有可用的 Python）"
elif [[ ! -d "$WHEEL_DIR" ]]; then
  err "包里缺少 $WHEEL_DIR"
else
  mkdir -p "$WORKDIR"
  [[ -x "$WORKDIR/.venv/bin/python" ]] || "$PY" -m venv "$WORKDIR/.venv"
  VPY="$WORKDIR/.venv/bin/python"
  if [[ -x "$VPY" ]]; then
    # --no-index + --find-links 强制只用本地 wheel，网络断了也能装完。
    if "$VPY" -m pip install -q --no-index --find-links "$WHEEL_DIR" \
         -r "$HERE/requirements.txt" 2>/tmp/pipfail.$$; then
      ok "$("$VPY" -m pip list --format=freeze 2>/dev/null | wc -l | tr -d ' ') 个包已装好（pip 缓存已就绪）"
    else
      err "依赖安装失败"; sed 's/^/      /' /tmp/pipfail.$$ | tail -6
    fi
    rm -f /tmp/pipfail.$$
  else
    err "虚拟环境创建失败"
  fi
fi

# ---- VS Code 扩展（本地 .vsix）----------------------------------------------
step "VS Code 扩展（本地安装）"
if [[ -x "$CODE_CLI" ]] || have code; then
  CODE="${CODE_CLI}"; [[ -x "$CODE" ]] || CODE="code"
  installed="$("$CODE" --list-extensions 2>/dev/null | tr 'A-Z' 'a-z')"
  for v in "$HERE"/vsix/*.vsix; do
    [[ -f "$v" ]] || continue
    id="$(basename "$v" .vsix)"
    if grep -qx "$(echo "$id" | tr 'A-Z' 'a-z')" <<<"$installed"; then
      ok "$id ${D}(已装)${N}"
    elif [[ $DRY -eq 1 ]]; then
      echo "  ${D}[dry-run] 会安装 $id${N}"
    else
      "$CODE" --install-extension "$v" --force >/dev/null 2>&1 \
        && ok "$id" || err "$id 安装失败"
    fi
  done
else
  err "找不到 code 命令，扩展需要在 VS Code 扩展面板里手动拖入 vsix/ 里的文件"
fi

# ---- kubectl ----------------------------------------------------------------
step "Lab 05 工具"
if have kubectl; then
  ok "kubectl 已安装"
elif [[ -f "$KUBECTL_BIN" ]]; then
  echo "  ${D}需要管理员密码来安装 kubectl 到 /usr/local/bin${N}"
  run sudo install -m 0755 "$KUBECTL_BIN" /usr/local/bin/kubectl && ok "kubectl 已安装" || err "kubectl 安装失败"
else
  err "包里缺少 kubectl"
fi

# Azure CLI 在 macOS 上没有官方独立安装器，微软只提供 Homebrew 渠道，
# 所以这一项无法离线预装，需要联网装一次（约 100MB，几分钟）。
if have az; then
  ok "Azure CLI 已安装"
elif have brew; then
  warn "Azure CLI 需要联网安装（macOS 无官方离线安装包）"
  echo "     ${D}现在装：brew install azure-cli${N}"
else
  warn "Azure CLI 需要联网安装，且先要有 Homebrew"
  echo "     ${D}1) /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/brew/HEAD/install.sh)\"${N}"
  echo "     ${D}2) brew install azure-cli${N}"
fi

# ---- 自检 -------------------------------------------------------------------
if [[ $DRY -eq 1 ]]; then
  echo; echo "${Y}dry-run 结束，没有改动任何东西。${N}"; exit 0
fi

step "环境自检"
if [[ -x "$HERE/verify.sh" ]]; then
  echo "  ${D}跑一遍自检脚本确认结果 ...${N}"; echo
  bash "$HERE/verify.sh" --check-only
  exit $?
else
  warn "包里没有 verify.sh，跳过自检"
fi

echo
if [[ $FAILED -eq 0 ]]; then
  echo "${G}安装完成。${N}"
else
  echo "${R}有 $FAILED 项失败${N}，把上面的输出发到班级群。"
  exit 1
fi
