#!/usr/bin/env bash
# =============================================================================
# 企业 AI 化转型 Lab · AI Company —— 离线包打包器（讲师用）
#
# 在讲师的 macOS（或 Linux）机器上运行一次，产出三个可分发的离线包：
#
#   dist/workshop-bundle-mac-arm64/    + .zip   (Apple Silicon)
#   dist/workshop-bundle-mac-intel/    + .zip   (Intel Mac)
#   dist/workshop-bundle-windows/      + .zip
#
# mac 按架构分开是为了体积：universal 版 VS Code 是 542MB，分架构后只要 309/332MB。
#
# 学员拿到后解压，双击/运行里面的 install 脚本即可，全程不需要再下载大文件。
#
#   bash build-bundle.sh                  # 两个平台都打
#   bash build-bundle.sh --platform mac   # 只打 mac
#   bash build-bundle.sh --no-zip         # 只产出目录，不压缩
#   bash build-bundle.sh --out /tmp/x     # 换输出目录
#
# 反复运行是安全的：已下载且校验通过的文件会跳过，断网重跑能续上。
#
# 为什么 Windows 包里装的是 Linux 版 az/kubectl/wheels：
#   课程所有命令都在 WSL 的 Ubuntu 里执行（deploy.sh 是 bash），VS Code 通过
#   Remote-WSL 连进去。所以 Windows 侧只需要 VS Code + Git，真正的运行时依赖
#   全部是 Linux 的。
# =============================================================================
set -uo pipefail

PLATFORM="both"
MAKE_ZIP=1
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/dist"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="${2:-both}"; shift 2 ;;
    --out)      OUT="${2:?}"; shift 2 ;;
    --no-zip)   MAKE_ZIP=0; shift ;;
    --help|-h)  sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数: $1（试试 --help）" >&2; exit 1 ;;
  esac
done
case "$PLATFORM" in mac|windows|both) ;; *) echo "--platform 只能是 mac / windows / both" >&2; exit 1 ;; esac

# ---- 版本锁定 ---------------------------------------------------------------
# Python 3.12.12 之后的 3.12.x 只发源码，没有二进制安装器；3.12.10 是最后一个有的。
PY_VER="3.12.10"
KUBECTL_VER="v1.37.0"
# `wsl --install -d Ubuntu` 当前给的是 24.04（noble）。
AZ_DEB_DIST="noble"

REQUIREMENTS="$REPO_ROOT/code/agents/requirements.txt"

# ---- 输出 -------------------------------------------------------------------
if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; N=$'\033[0m'
else R=''; G=''; Y=''; B=''; D=''; N=''; fi
step() { echo; echo "${B}==>${N} $1"; }
ok()   { echo "  ${G}✔${N} $1"; }
warn() { echo "  ${Y}!${N} $1"; }
err()  { echo "  ${R}✘${N} $1"; FAILED=$((FAILED+1)); }
FAILED=0

have() { command -v "$1" >/dev/null 2>&1; }

# 下载到目标路径。已存在且非空则跳过（幂等，可续跑）。
# curl 的 -f 让 4xx/5xx 直接失败，避免把错误页当成安装包发给学员。
fetch() {
  local url="$1" dest="$2" label="${3:-$(basename "$dest")}" min="${4:-10000}"
  local stamp="${dest}.src"
  # 只看"文件在不在"会漏掉版本升级：kubectl 和 azure-cli.deb 的目标文件名不带版本，
  # 改了 KUBECTL_VER / AZ_DEB_DIST 后旧文件仍在，于是永远下不到新版。
  # 这里额外比对来源 URL，URL 变了就重下。
  if [[ -s "$dest" ]] && [[ "$(wc -c <"$dest")" -ge "$min" ]] \
     && [[ -f "$stamp" ]] && [[ "$(cat "$stamp")" == "$url" ]]; then
    ok "$label ${D}(已存在，跳过)${N}"; return 0
  fi
  if [[ -s "$dest" ]] && [[ ! -f "$stamp" || "$(cat "$stamp" 2>/dev/null)" != "$url" ]]; then
    [[ -f "$stamp" ]] && warn "$label 来源已变化，重新下载"
  fi
  mkdir -p "$(dirname "$dest")"
  if curl -fSL --compressed --retry 3 --retry-delay 2 --max-time 900 \
          --progress-bar -o "$dest.part" "$url"; then
    local sz; sz="$(wc -c <"$dest.part")"
    if [[ "$sz" -lt "$min" ]]; then
      rm -f "$dest.part"; err "$label 下载内容过小（${sz}B），可能是错误页"; return 1
    fi
    mv "$dest.part" "$dest"
    printf '%s' "$url" > "$stamp"
    ok "$label ${D}($(du -h "$dest" | cut -f1))${N}"
  else
    rm -f "$dest.part"; err "$label 下载失败：$url"; return 1
  fi
}

# 从 VS Code Marketplace 取扩展的离线 .vsix。
# 这个端点不接受 HEAD，且默认返回 gzip，所以必须 GET + --compressed。
fetch_vsix() {
  local id="$1" dest_dir="$2"
  local pub="${id%%.*}" ext="${id#*.}"
  fetch "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/$pub/vsextensions/$ext/latest/vspackage" \
        "$dest_dir/$id.vsix" "扩展 $id" 100000
}

# pip download 跨平台抓 wheel。--only-binary=:all: 是硬要求：
# 没有它 pip 会去下源码包，学员机器上就得现场编译。
fetch_wheels() {
  local platform_tag="$1" dest="$2" label="$3"
  # 只数文件个数会漏掉 requirements.txt 的改动：改了 pin 之后 wheel 不会重新解析，
  # 但新的 requirements.txt 照样会被拷进包里 —— 学员侧 --no-index 必然失败。
  # 这里用 requirements.txt 的哈希做戳，内容变了就整目录重来。
  local reqhash stamp="$dest/.requirements.sha256"
  reqhash="$(shasum -a 256 "$REQUIREMENTS" 2>/dev/null | cut -d" " -f1)"
  if [[ -d "$dest" ]] && [[ "$(ls -1 "$dest" 2>/dev/null | grep -c '\.whl$')" -ge 60 ]] \
     && [[ -f "$stamp" ]] && [[ "$(cat "$stamp")" == "$reqhash" ]]; then
    ok "$label ${D}($(ls -1 "$dest" | grep -c '\.whl$' | tr -d ' ') 个 wheel，已存在)${N}"; return 0
  fi
  if [[ -d "$dest" ]] && [[ -f "$stamp" ]] && [[ "$(cat "$stamp")" != "$reqhash" ]]; then
    warn "requirements.txt 已变化，重新解析 $label"
    rm -rf "$dest"
  fi
  mkdir -p "$dest"
  if "$PIP" download -q --only-binary=:all: \
        --platform "$platform_tag" --python-version 3.12 --implementation cp \
        --dest "$dest" -r "$REQUIREMENTS" 2>/tmp/wheelerr.$$; then
    printf '%s' "$reqhash" > "$stamp"
    ok "$label ${D}($(ls -1 "$dest" | grep -c '\.whl$' | tr -d ' ') 个 wheel, $(du -sh "$dest" | cut -f1))${N}"
  else
    err "$label 下载失败"; sed 's/^/      /' /tmp/wheelerr.$$ | tail -5
  fi
  rm -f /tmp/wheelerr.$$
}

echo "${B}企业 AI 化转型 Lab · AI Company —— 离线包打包${N}"
echo "${D}输出目录：$OUT${N}"

# ---- 前置检查 ---------------------------------------------------------------
step "打包机环境"
have curl || { echo "需要 curl" >&2; exit 1; }
ok "curl"
[[ -f "$REQUIREMENTS" ]] || { echo "找不到 $REQUIREMENTS" >&2; exit 1; }
ok "requirements.txt ${D}($(grep -cE '^[a-z]' "$REQUIREMENTS") 个锁定包)${N}"

# 优先用课程仓库自己的 venv，保证 pip 行为和学员一致。
PIP=""
for cand in "$REPO_ROOT/code/.venv/bin/pip" pip3 pip; do
  if [[ -x "$cand" ]] || have "$cand"; then PIP="$cand"; break; fi
done
[[ -n "$PIP" ]] || { echo "找不到 pip" >&2; exit 1; }
ok "pip ${D}($PIP)${N}"

PRECHECK_DIR="$REPO_ROOT/scripts/pre-request-check"
[[ -d "$PRECHECK_DIR" ]] || { echo "找不到 $PRECHECK_DIR" >&2; exit 1; }
ok "环境自检脚本"

# =============================================================================
# macOS 包 —— 按架构分成两个，学员各下一个即可
#
# VS Code 的 universal 版是 542MB，分架构后只要 309/332MB；wheels 和 kubectl
# 同理。拆开后每个学员少下约 350MB，代价是讲师要产出两个包。
# =============================================================================
build_mac() {
  local arch="$1"            # arm64 | intel
  local vscode_id wheel_tag kubectl_arch uname_m label
  case "$arch" in
    arm64) vscode_id="darwin-arm64"; wheel_tag="macosx_11_0_arm64"
           kubectl_arch="arm64"; uname_m="arm64";  label="Apple Silicon" ;;
    intel) vscode_id="darwin";       wheel_tag="macosx_10_13_x86_64"
           kubectl_arch="amd64"; uname_m="x86_64"; label="Intel" ;;
  esac
  local MAC="$OUT/workshop-bundle-mac-$arch"

  step "打包 macOS · $label"
  mkdir -p "$MAC"/{installers,vsix,wheels}

  fetch "https://update.code.visualstudio.com/latest/$vscode_id/stable" \
        "$MAC/installers/VSCode-$vscode_id.zip" "VS Code ($label)" 50000000
  fetch "https://www.python.org/ftp/python/$PY_VER/python-$PY_VER-macos11.pkg" \
        "$MAC/installers/python-$PY_VER-macos11.pkg" "Python $PY_VER (universal2)" 20000000
  fetch "https://dl.k8s.io/release/$KUBECTL_VER/bin/darwin/$kubectl_arch/kubectl" \
        "$MAC/installers/kubectl" "kubectl $KUBECTL_VER ($label)" 30000000

  for e in github.copilot github.copilot-chat ms-python.python; do
    fetch_vsix "$e" "$MAC/vsix"
  done

  fetch_wheels "$wheel_tag" "$MAC/wheels" "Python wheels ($label)"

  # 学员下错包时用它给出人话提示，而不是让 pip 报一堆看不懂的错。
  printf '%s\n' "$uname_m" > "$MAC/arch.txt"

  cp "$REQUIREMENTS" "$MAC/requirements.txt"
  cp "$HERE/templates/install-mac.sh" "$MAC/install.sh"
  cp "$PRECHECK_DIR/mac/workshop-precheck-mac.sh" "$MAC/verify.sh"
  cp "$PRECHECK_DIR/mac/checklist-mac.html" "$MAC/环境清单.html" 2>/dev/null || true
  cp "$HERE/templates/README-mac.md" "$MAC/README.md"
  chmod +x "$MAC/install.sh" "$MAC/verify.sh" "$MAC/installers/kubectl" 2>/dev/null || true
  ok "已放入 install.sh / verify.sh / README.md / 环境清单.html / arch.txt"
}

if [[ "$PLATFORM" == "mac" || "$PLATFORM" == "both" ]]; then
  build_mac arm64
  build_mac intel
fi

# =============================================================================
# Windows 包（Windows 侧 VS Code + Git，WSL 侧 Linux 运行时）
# =============================================================================
if [[ "$PLATFORM" == "windows" || "$PLATFORM" == "both" ]]; then
  WIN="$OUT/workshop-bundle-windows"
  step "打包 Windows"
  mkdir -p "$WIN"/{installers,vsix,wsl/wheels}

  fetch "https://update.code.visualstudio.com/latest/win32-x64-user/stable" \
        "$WIN/installers/VSCodeUserSetup-x64.exe" "VS Code (Windows x64)" 50000000

  GIT_URL="$(curl -sL --max-time 60 https://api.github.com/repos/git-for-windows/git/releases/latest \
    | python3 -c "
import sys, json
try:
    for a in json.load(sys.stdin).get('assets', []):
        n = a['name']
        if n.endswith('64-bit.exe') and 'Portable' not in n and 'arm64' not in n:
            print(a['browser_download_url']); break
except Exception:
    pass" 2>/dev/null)"
  if [[ -n "$GIT_URL" ]]; then
    fetch "$GIT_URL" "$WIN/installers/Git-64-bit.exe" "Git for Windows" 30000000
  else
    warn "无法解析 Git for Windows 最新版下载地址，学员需联网装 Git"
  fi

  # Windows 侧要装 Remote-WSL，否则 VS Code 打开的是 Windows 文件系统。
  for e in github.copilot github.copilot-chat ms-python.python ms-vscode-remote.remote-wsl; do
    fetch_vsix "$e" "$WIN/vsix"
  done

  # ---- WSL(Ubuntu) 侧的 Linux 运行时 ----
  fetch_wheels "manylinux_2_17_x86_64" "$WIN/wsl/wheels" "Python wheels (WSL / Linux)"

  fetch "https://dl.k8s.io/release/$KUBECTL_VER/bin/linux/amd64/kubectl" \
        "$WIN/wsl/kubectl-linux-amd64" "kubectl $KUBECTL_VER (WSL / Linux)" 30000000

  AZ_DEB_PATH="$(curl -sL --max-time 90 \
      "https://packages.microsoft.com/repos/azure-cli/dists/$AZ_DEB_DIST/main/binary-amd64/Packages" 2>/dev/null \
    | awk '/^Filename:/{f=$2} /^Version:/{v=$2} f&&v{print v"|"f; f=""; v=""}' \
    | sort -V | tail -1 | cut -d'|' -f2)"
  if [[ -n "$AZ_DEB_PATH" ]]; then
    fetch "https://packages.microsoft.com/repos/azure-cli/$AZ_DEB_PATH" \
          "$WIN/wsl/azure-cli.deb" "Azure CLI (WSL / Ubuntu $AZ_DEB_DIST)" 20000000
  else
    warn "无法解析 Azure CLI .deb 地址，学员需联网装 az"
  fi

  cp "$REQUIREMENTS" "$WIN/requirements.txt"
  cp "$HERE/templates/install-windows.ps1" "$WIN/install.ps1"
  cp "$HERE/templates/install-in-wsl.sh"   "$WIN/wsl/install-in-wsl.sh"
  cp "$PRECHECK_DIR/windows/workshop-precheck-windows.ps1" "$WIN/verify.ps1"
  cp "$PRECHECK_DIR/windows/checklist-windows.html" "$WIN/环境清单.html" 2>/dev/null || true
  cp "$HERE/templates/README-windows.md" "$WIN/README.md"
  ok "已放入 install.ps1 / install-in-wsl.sh / verify.ps1 / README.md / 环境清单.html"
fi

# =============================================================================
# 压缩 + 汇总
# =============================================================================
if [[ $MAKE_ZIP -eq 1 ]] && have zip; then
  step "压缩"
  for d in "$OUT"/workshop-bundle-*; do
    [[ -d "$d" ]] || continue
    (cd "$OUT" && rm -f "$(basename "$d").zip" && zip -rq -X "$(basename "$d").zip" "$(basename "$d")")
    ok "$(basename "$d").zip ${D}($(du -h "$OUT/$(basename "$d").zip" | cut -f1))${N}"
  done
fi

step "结果"
for d in "$OUT"/workshop-bundle-*; do
  [[ -d "$d" ]] || continue
  echo "  $(basename "$d")  ${D}$(du -sh "$d" | cut -f1)  $(find "$d" -type f | wc -l | tr -d ' ') 个文件${N}"
done
echo
if [[ $FAILED -eq 0 ]]; then
  echo "${G}打包完成。${N}把 zip 发到网盘或拷进 U 盘即可。"
  echo "${D}学员操作：解压 → macOS 跑 install.sh / Windows 右键管理员运行 install.ps1${N}"
  exit 0
else
  echo "${R}有 $FAILED 项失败。${N}修网络后重跑本脚本，已下好的会自动跳过。"
  exit 1
fi
