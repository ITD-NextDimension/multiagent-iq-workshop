#!/usr/bin/env bash
# =============================================================================
# 企业 AI 化转型 Lab · AI Company（3 小时）
# 课前环境自检 —— macOS / Linux
#
# 这个脚本是独立的：不需要课程仓库，不需要任何凭据，单独一个文件就能跑。
# 它会检查每一项，缺的直接装上，最后打印一行回执给你发到班级群。
#
#   bash workshop-precheck-mac.sh              # 检查，逐项问你要不要装
#   bash workshop-precheck-mac.sh --yes        # 全自动，推荐
#   bash workshop-precheck-mac.sh --check-only # 只体检，一个字节都不装
#   bash workshop-precheck-mac.sh --skip-azure # 跳过 Lab 05 的 az / kubectl
#   bash workshop-precheck-mac.sh --bundle-mode # 离线包自检：brew/az 缺失记为 WARN
#                                               （这两项 macOS 上必须联网装，离线包装不了）
#
# 反复运行是安全的。
# =============================================================================

# 故意不用 set -e：要让每一项都跑完，一次看到全貌，而不是卡在第一个错误。
set -uo pipefail

AUTO_YES=0; CHECK_ONLY=0; SKIP_AZURE=0; BUNDLE_MODE=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)     AUTO_YES=1 ;;
    --check-only) CHECK_ONLY=1 ;;
    --skip-azure) SKIP_AZURE=1 ;;
    --bundle-mode) BUNDLE_MODE=1 ;;
    --help|-h)    sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数: ${arg}（试试 --help）" >&2; exit 1 ;;
  esac
done

# 依赖预热用的目录。课上你会在课程仓库里另建一个 .venv，那时候 pip 走本地缓存，
# 几秒就装完 —— 这正是提前跑这个脚本的意义。
WORKDIR="${HOME}/frontier-workshop-precheck"
REPORT="${WORKDIR}/precheck-report.txt"

# 与课程仓库 requirements 完全一致的锁定版本。
# MCP 2.x 移除了 mcp.server.fastmcp；agent-framework 元包会让 pip 解析失败；
# pydantic-monty 0.0.17+ 改了 API 会让沙箱画不出图。三处都必须钉住。
REQUIREMENTS='mcp==1.29.0
agent-framework-core==1.14.0
agent-framework-openai==1.13.0
agent-framework-orchestrations==1.1.0
agent-framework-monty==1.0.0b260730
pydantic-monty==0.0.16
azure-identity==1.25.3
azure-communication-email==1.1.0
python-dotenv==1.2.2
matplotlib==3.11.1
fastapi==0.139.2
uvicorn==0.52.3'

# ---- 输出 -------------------------------------------------------------------
if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; N=$'\033[0m'
else
  R=''; G=''; Y=''; B=''; D=''; N=''
fi

# 每条记录是 "状态|名称|怎么修"。修复命令是这个脚本能自助的关键：
# 每个 FAIL 都必须告诉学员下一步敲什么，不用问任何人。
RESULTS=()
pass() { echo "  ${G}✔${N} $1"; RESULTS+=("PASS|$1|${2:-}"); }
warn() { echo "  ${Y}!${N} $1"; RESULTS+=("WARN|$1|${2:-}"); }
skip() { echo "  ${D}-${N} $1"; RESULTS+=("SKIP|$1|${2:-}"); }
fail() { echo "  ${R}✘${N} $1"; RESULTS+=("FAIL|$1|${2:-}")
         [[ -n "${2:-}" ]] && echo "    ${D}修复：${2}${N}"; return 0; }
note() { echo "    ${D}$1${N}"; }

# 装好之后把先前那条 FAIL 就地改成 PASS。没有它，全新机器跑 --yes 明明什么都装上了，
# 回执仍然是 NOT-READY，学员会以为失败又跑来问。
fixed() {
  local i
  for i in "${!RESULTS[@]}"; do
    [[ "${RESULTS[$i]}" == "FAIL|$1|"* ]] || continue
    RESULTS[$i]="PASS|$2|"
    echo "  ${G}✔${N} $2"
    return 0
  done
  pass "$2"
}
step() { echo; echo "${B}==>${N} $1"; }

confirm() {
  [[ $CHECK_ONLY -eq 1 ]] && return 1
  [[ $AUTO_YES  -eq 1 ]] && return 0
  if [[ ! -t 0 && ! -e /dev/tty ]]; then
    note "非交互环境，跳过安装（想自动装请加 --yes）"; return 1
  fi
  local reply
  read -r -p "    ${Y}?${N} $1 [y/N] " reply </dev/tty || return 1
  [[ "$reply" =~ ^[Yy]$ ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

echo "${B}企业 AI 化转型 Lab · AI Company —— 课前环境自检${N}"
echo "${D}工作目录：${WORKDIR}${N}"

# ---- 平台 -------------------------------------------------------------------
step "平台"
OS=""
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)  if grep -qi microsoft /proc/version 2>/dev/null; then OS="wsl"; else OS="linux"; fi ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "  ${R}✘${N} 这是 Windows 环境"
    echo "    请改用 Windows 版脚本：workshop-precheck-windows.ps1"
    exit 1 ;;
  *) echo "  ${R}✘${N} 未知平台 $(uname -s)"; exit 1 ;;
esac
case "$OS" in
  macos)
    MACVER="$(sw_vers -productVersion 2>/dev/null)"
    # 离线包里的 Python 是 macos11 版，wheel 也是 macosx_11_0 —— 10.x 装不上。
    if [[ "${MACVER%%.*}" =~ ^[0-9]+$ ]] && (( ${MACVER%%.*} < 11 )); then
      fail "macOS $MACVER 过低（离线包要求 11 以上）" "升级系统，或改用联网安装路线"
    else
      pass "macOS $MACVER"
    fi ;;
  wsl)   pass "WSL2（$( . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}" )）" ;;
  linux) pass "Linux（$( . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}" )）" ;;
esac

# 磁盘：离线包解压 + VS Code + Python + venv 合计约 1.5GB，留些余量按 5GB 判。
# 空间不足的表现是解压到一半报错，学员很难判断根因，所以提前挡。
FREE_GB="$(df -g "$HOME" 2>/dev/null | awk 'NR==2{print $4}')"
if [[ -n "$FREE_GB" ]]; then
  if (( FREE_GB < 5 )); then
    fail "可用磁盘空间仅 ${FREE_GB}GB（至少需要 5GB）" "清理磁盘后重跑"
  else
    pass "磁盘可用 ${FREE_GB}GB"
  fi
fi

PKG=""
if [[ "$OS" == "macos" ]]; then
  if have brew; then
    PKG="brew"; pass "Homebrew $(brew --version 2>/dev/null | head -1 | awk '{print $2}')"
  elif [[ $BUNDLE_MODE -eq 1 ]]; then
    # 离线包装不了 Homebrew，包内 README 也写明了要联网装。记 WARN 而非 FAIL，
    # 否则每个 mac 学员都会拿到 NOT-READY —— 而 README 承诺的样例回执是 FAIL=0。
    warn "未安装 Homebrew（Lab 05 装 az 时才需要，可课前自行安装）"
    echo "     ${D}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/brew/HEAD/install.sh)\"${N}"
  else
    fail "未安装 Homebrew（macOS 上装东西都靠它）" \
         '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/brew/HEAD/install.sh)"'
  fi
elif have apt-get; then
  PKG="apt"; pass "apt-get 可用"
else
  warn "不是 Debian/Ubuntu 系，缺失项需要你手动安装"
fi

apt_install() { sudo apt-get update -qq && sudo apt-get install -y "$@"; }

# ---- 网络 -------------------------------------------------------------------
step "网络连通性"
if ! have curl; then
  fail "curl 未安装" "$( [[ "$PKG" == apt ]] && echo 'sudo apt-get install -y curl' || echo 'brew install curl' )"
fi
# 探测点按"课上真正会连的域"选，不只是能 ping 通的三个。
# 判定看 HTTP 状态码而不是 curl 退出码：不带 -f 时，公司代理返回 403/407
# 也会让 curl 退 0，于是"网络正常"，而这恰恰是最常见的 NOT-READY 原因。
# 401/403 对这些端点属于"通了但要鉴权"，算连通；000 才是真的不通。
for pair in "github.com|https://github.com" \
            "pypi.org|https://pypi.org/simple/mcp/" \
            "Azure 管理面|https://management.azure.com/" \
            "Entra 登录|https://login.microsoftonline.com/" \
            "VS Code 扩展市场|https://marketplace.visualstudio.com/" \
            "GitHub Copilot|https://api.githubcopilot.com/" \
            "微软容器仓库|https://mcr.microsoft.com/v2/"; do
  nm="${pair%%|*}"; url="${pair##*|}"
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null || echo 000)"
  if [[ "$code" == "000" ]]; then
    fail "无法访问 ${nm}（${url}）" "换个网络重试；公司网络请检查代理 / VPN，curl 需要能走 HTTPS"
  elif [[ "$code" == "407" ]] || [[ "$code" == "511" ]]; then
    fail "${nm} 被代理拦截（HTTP ${code}）" "这是公司网络策略，课前找 IT 放行或换网络"
  else
    pass "可访问 ${nm} ${D}(HTTP ${code})${N}"
  fi
done

# ---- Git --------------------------------------------------------------------
step "Git"
if have git; then
  pass "git $(git --version | awk '{print $3}')"
else
  L_GIT="git 未安装"
  fail "$L_GIT" "$( [[ "$PKG" == brew ]] && echo 'brew install git' || echo 'sudo apt-get install -y git' )"
  if [[ "$PKG" == "brew" ]] && confirm "brew install git？"; then brew install git && fixed "$L_GIT" "git 已安装"
  elif [[ "$PKG" == "apt" ]] && confirm "apt install git？"; then apt_install git && fixed "$L_GIT" "git 已安装"; fi
fi

# ---- Python -----------------------------------------------------------------
step "Python（需要 3.10 / 3.11 / 3.12）"
PY=""
py_ok() {
  local v; v="$("$1" -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null)" || return 1
  [[ "$v" == "3.10" || "$v" == "3.11" || "$v" == "3.12" ]]
}
for cand in python3.12 python3.11 python3.10 python3; do
  if have "$cand" && py_ok "$cand"; then PY="$(command -v "$cand")"; break; fi
done

if [[ -z "$PY" ]]; then
  if have python3; then
    warn "已装 $(python3 -V 2>&1)，但课程依赖只在 3.10–3.12 上验证过"
  fi
  L_PY="没有可用的 Python 3.10–3.12"
  fail "$L_PY" \
       "$( [[ "$PKG" == brew ]] && echo 'brew install python@3.12' || echo 'sudo apt-get install -y python3 python3-venv python3-pip' )"
  if [[ "$PKG" == "brew" ]] && confirm "brew install python@3.12？"; then
    brew install python@3.12 && PY="$(brew --prefix)/opt/python@3.12/bin/python3.12"
  elif [[ "$PKG" == "apt" ]] && confirm "apt install python3 python3-venv python3-pip？"; then
    apt_install python3 python3-venv python3-pip
    for cand in python3.12 python3.11 python3.10 python3; do
      have "$cand" && py_ok "$cand" && { PY="$(command -v "$cand")"; break; }
    done
  fi
fi
[[ -n "$PY" ]] && fixed "${L_PY:-没有可用的 Python 3.10–3.12}" "$($PY -V 2>&1)（${PY}）"

# ---- 依赖预热 ---------------------------------------------------------------
step "课程依赖（约 64 个包 / 装完 ~210MB，提前下好，课上就是秒装）"
VENV_PY="${WORKDIR}/.venv/bin/python"

if [[ -z "$PY" ]]; then
  skip "跳过（没有可用的 Python）"
elif [[ $CHECK_ONLY -eq 1 && ! -x "$VENV_PY" ]]; then
  fail "依赖尚未预热" "去掉 --check-only 重跑：bash $0 --yes"
else
  mkdir -p "$WORKDIR"
  printf '%s\n' "$REQUIREMENTS" > "${WORKDIR}/requirements.txt"

  if [[ ! -x "$VENV_PY" ]]; then
    echo "    创建虚拟环境 ${WORKDIR}/.venv ..."
    if ! "$PY" -m venv "${WORKDIR}/.venv" 2>/dev/null; then
      # Debian/Ubuntu 把 venv 拆成了单独的包
      if [[ "$PKG" == "apt" ]] && confirm "创建失败，安装 python3-venv 后重试？"; then
        apt_install python3-venv && "$PY" -m venv "${WORKDIR}/.venv"
      fi
    fi
  fi

  if [[ ! -x "$VENV_PY" ]]; then
    fail "虚拟环境创建失败" "$( [[ "$PKG" == apt ]] && echo 'sudo apt-get install -y python3-venv 后重跑' || echo "删掉 ${WORKDIR} 后重跑" )"
  else
    missing="$("$VENV_PY" - <<'PYEOF' 2>/dev/null
import importlib.util as u
print(",".join(m for m in ("agent_framework", "mcp", "matplotlib", "fastapi")
                if u.find_spec(m) is None))
PYEOF
)"
    if [[ -n "$missing" ]]; then
      echo "    缺少：$missing"
      if confirm "现在下载安装（视网速可能要几分钟）？"; then
        "$VENV_PY" -m pip install --quiet --upgrade pip
        # 必须整份装。单独 pip install mcp 会拿到 2.x，单独装 agent-framework
        # 会拉进 31 个可选集成然后 resolution-too-deep 失败。
        if "$VENV_PY" -m pip install -r "${WORKDIR}/requirements.txt"; then
          pass "依赖安装完成，pip 缓存已就绪"
        else
          fail "依赖安装失败" "看上面的 pip 输出；网络问题就换网重跑 bash $0 --yes"
        fi
      else
        fail "依赖未预热：$missing" "重跑：bash $0 --yes"
      fi
    else
      pass "依赖齐全（agent_framework / mcp / matplotlib / fastapi）"
    fi

    if [[ -x "$VENV_PY" ]] && "$VENV_PY" -c "import agent_framework, mcp, matplotlib, fastapi" 2>/dev/null; then
      pass "四个关键包都能正常 import"
    fi
  fi
fi

# ---- VS Code ----------------------------------------------------------------
step "VS Code 与 GitHub Copilot（Lab 02–04 用）"
CODE_BIN=""
if have code; then CODE_BIN="code"
elif [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
  CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi

if [[ -z "$CODE_BIN" ]]; then
  case "$OS" in
    macos) L_CODE="未找到 VS Code"; fail "$L_CODE" "brew install --cask visual-studio-code"
           [[ "$PKG" == "brew" ]] && confirm "brew install --cask visual-studio-code？" \
             && brew install --cask visual-studio-code \
             && CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ;;
    wsl)   fail "WSL 里找不到 code 命令" "在 Windows 侧运行 workshop-precheck-windows.ps1" ;;
    linux) L_CODE="未找到 VS Code"; fail "$L_CODE" "下载安装：https://code.visualstudio.com/download" ;;
  esac
fi

if [[ -n "$CODE_BIN" ]]; then
  fixed "${L_CODE:-未找到 VS Code}" "VS Code $("$CODE_BIN" --version 2>/dev/null | head -1)"
  exts="$("$CODE_BIN" --list-extensions 2>/dev/null | tr 'A-Z' 'a-z')"
  # 扩展装在 Windows 侧，从 WSL 里读到的列表可能是空的 —— 不能拿这个信号判失败
  if [[ "$OS" == "wsl" && -z "$exts" ]]; then
    warn "无法从 WSL 读取扩展列表 —— 扩展在 Windows 侧，用 workshop-precheck-windows.ps1 检查"
  else
    for ext in "github.copilot" "github.copilot-chat" "ms-python.python"; do
      if grep -qx "$ext" <<<"$exts"; then
        pass "扩展 $ext"
      elif confirm "安装扩展 ${ext}？"; then
        "$CODE_BIN" --install-extension "$ext" --force >/dev/null 2>&1 \
          && pass "扩展 $ext 已安装" \
          || fail "扩展 $ext 安装失败" "在 VS Code 扩展面板里手动搜索安装"
      else
        fail "缺少扩展 ${ext}" "code --install-extension ${ext}"
      fi
    done
  fi
fi

# ---- Lab 05 工具 -------------------------------------------------------------
step "Lab 05 上云工具"
if [[ $SKIP_AZURE -eq 1 ]]; then
  skip "按 --skip-azure 跳过"
else
  if have az; then
    pass "az $(az version --output tsv --query '"azure-cli"' 2>/dev/null || echo '')"
  elif [[ $BUNDLE_MODE -eq 1 ]]; then
    # 同上：macOS 只有 Homebrew 渠道，离线包无法预装，这是文档里写明的已知项。
    warn "未安装 Azure CLI（只有 Lab 05 用到，需联网装一次）"
    echo "     ${D}brew install azure-cli${N}"
  else
    L_AZ="未安装 Azure CLI"
    fail "$L_AZ" \
         "$( [[ "$PKG" == brew ]] && echo 'brew install azure-cli' || echo 'curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash' )"
    if [[ "$PKG" == "brew" ]] && confirm "brew install azure-cli？"; then
      brew install azure-cli && fixed "$L_AZ" "az 已安装"
    elif [[ "$PKG" == "apt" ]] && confirm "用微软官方脚本安装 azure-cli（需要 sudo）？"; then
      curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash && fixed "$L_AZ" "az 已安装"
    fi
  fi

  # Lab 05 的 deploy.sh 会调这两个 az 扩展。它们是动态扩展：不预装的话，
  # 学员第一次跑部署脚本会撞上"是否安装扩展"的交互提示，正好卡在最后 30 分钟。
  #   containerapp —— 会话池与容器应用
  #   communication —— deploy.sh 用 `az communication list-key` 取 ACS 连接串，
  #                    取不到就 exit 1，而且是在 ACR/AKS/ACA 都建好之后才失败。
  if have az; then
    for _ext in containerapp communication; do
      if az extension show --name "$_ext" >/dev/null 2>&1; then
        pass "az 扩展 $_ext"
      else
        L_EXT="缺少 az 扩展 ${_ext}（Lab 05 部署脚本要用）"
        fail "$L_EXT" "az extension add --name $_ext"
        if confirm "az extension add --name ${_ext}？"; then
          az extension add --name "$_ext" --only-show-errors >/dev/null 2>&1 \
            && fixed "$L_EXT" "az 扩展 $_ext 已安装"
        fi
      fi
    done
  fi

  if have kubectl; then
    pass "$(kubectl version --client 2>/dev/null | head -1)"
  else
    L_KUBE="未安装 kubectl"
    fail "$L_KUBE" \
         "$( [[ "$PKG" == brew ]] && echo 'brew install kubernetes-cli' || echo 'sudo az aks install-cli' )"
    if [[ "$PKG" == "brew" ]] && confirm "brew install kubernetes-cli？"; then
      brew install kubernetes-cli && fixed "$L_KUBE" "kubectl 已安装"
    elif have az && confirm "用 az aks install-cli 安装 kubectl（需要 sudo）？"; then
      sudo az aks install-cli && fixed "$L_KUBE" "kubectl 已安装"
    fi
  fi

  # 课上用讲师发的服务主体统一登录，课前不需要有 Azure 账号。
  note "课上会用讲师发的凭据登录：az login --service-principal -u <appId> -p <password> --tenant <tenantId>"
fi

# ---- 可选 -------------------------------------------------------------------
step "可选项"
if have docker; then
  if docker info >/dev/null 2>&1; then pass "Docker 可用（依赖出问题时的兜底方案）"
  else warn "装了 Docker 但守护进程没跑（兜底方案暂不可用）"; fi
else
  skip "未安装 Docker（非必需，只是兜底）"
fi

# ---- 手动确认 ---------------------------------------------------------------
echo
echo "${B}================ 手动确认（30 秒，脚本查不了）================${N}"
cat <<'MANUAL'
  1. 打开 VS Code，确认已登录 GitHub 账号
  2. 打开 Copilot Chat（⌃⌘I / Ctrl+Alt+I），确认输入框上方能切到 "Agent" 模式
  3. 在 Agent 模式里随便问一句，能正常回答 = Copilot 可用

  切不到 Agent 模式 = 你的 GitHub 组织策略关掉了它，现场无法解决。
  → 找组织的 GitHub 管理员开启，或装 Claude Code / Cursor 顶替（讲义里两种写法都有）
MANUAL

# ---- 汇总 -------------------------------------------------------------------
echo
echo "${B}================ 结果 ================${N}"
n_fail=0; n_warn=0
for r in "${RESULTS[@]}"; do
  IFS='|' read -r status label hint <<<"$r"
  case "$status" in
    FAIL) echo "  ${R}FAIL${N}  $label"; [[ -n "$hint" ]] && echo "        ${D}→ $hint${N}"; n_fail=$((n_fail+1)) ;;
    WARN) echo "  ${Y}WARN${N}  $label"; n_warn=$((n_warn+1)) ;;
  esac
done
[[ $n_fail -eq 0 && $n_warn -eq 0 ]] && echo "  ${G}全部通过${N}"

if [[ $n_fail -eq 0 ]]; then verdict="READY"; else verdict="NOT-READY"; fi
receipt="[precheck] ${verdict} | ${OS} | $( [[ -n "$PY" ]] && "$PY" -V 2>&1 || echo 'no-python' ) | FAIL=${n_fail} WARN=${n_warn}"

mkdir -p "$WORKDIR"
{
  echo "$receipt"
  echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "平台: $(uname -srm)"
  echo
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r status label hint <<<"$r"
    printf '%-5s %s\n' "$status" "$label"
    [[ "$status" == "FAIL" && -n "$hint" ]] && printf '      → %s\n' "$hint"
  done
} > "$REPORT"

echo
echo "${B}================ 回执 ================${N}"
echo "  $receipt"
echo "  ${D}完整报告：${REPORT}${N}"
echo

if [[ $n_fail -eq 0 ]]; then
  echo "${G}环境就绪。${N}把上面那行回执发到班级群就算准备完毕。"
  exit 0
else
  echo "${R}还有 $n_fail 项未通过。${N}按每条的「→」修完，重跑本脚本，直到回执变成 READY。"
  echo "自助兜底顺序："
  echo "  1. bash $0 --yes            ${D}# 让脚本自己装${N}"
  echo "  2. 装 Docker Desktop        ${D}# 课上用容器跑，完全不依赖本机 Python${N}"
  echo "  3. 把 ${REPORT} 发到班级群 ${D}# 讲师课前处理${N}"
  exit 1
fi
