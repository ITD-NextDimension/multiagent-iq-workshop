<#
.SYNOPSIS
    企业 AI 化转型 Lab · AI Company（3 小时）—— 课前环境自检（Windows）

.DESCRIPTION
    这个脚本是独立的：不需要课程仓库，不需要任何凭据，单独一个文件就能跑。

    课程当天所有命令都在 WSL 的 Ubuntu 里敲（Lab 05 的部署脚本是 bash），
    所以这里分两侧检查：

      Windows 侧   VS Code + Lab 02–04 需要的扩展、WSL2 + Ubuntu
      Ubuntu 侧    Git、Python 3.10-3.12、课程依赖预热、az、kubectl

    Ubuntu 侧的检查由本脚本内嵌的一段 bash 完成，不需要你另外下载什么。

    反复运行是安全的。装完 WSL 需要重启一次，重启后把同一条命令再跑一遍。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File workshop-precheck-windows.ps1 -Yes
#>
[CmdletBinding()]
param(
    [string]$Distro = "Ubuntu",
    [switch]$Yes,
    [switch]$CheckOnly,
    [switch]$SkipAzure
)

$ErrorActionPreference = "Continue"
$script:Results = @()

function Write-Step { param($t) Write-Host ""; Write-Host "==> $t" -ForegroundColor Blue }
function Add-Pass { param($t) Write-Host "  [OK]   $t" -ForegroundColor Green;  $script:Results += ,@("PASS", $t, "") }
function Add-Warn { param($t) Write-Host "  [WARN] $t" -ForegroundColor Yellow; $script:Results += ,@("WARN", $t, "") }
function Add-Skip { param($t) Write-Host "  [--]   $t" -ForegroundColor DarkGray; $script:Results += ,@("SKIP", $t, "") }
function Add-Fail {
    param($t, $fix)
    Write-Host "  [FAIL] $t" -ForegroundColor Red
    if ($fix) { Write-Host "         修复：$fix" -ForegroundColor DarkGray }
    $script:Results += ,@("FAIL", $t, $fix)
}
function Note { param($t) Write-Host "         $t" -ForegroundColor DarkGray }

# 装好之后把先前那条 FAIL 就地改成 PASS。没有它，全新机器跑 -Yes 明明什么都装上了，
# 回执仍然是 NOT-READY，学员会以为失败又跑来问。
function Resolve-Fail {
    param($Label, $NewText)
    for ($i = 0; $i -lt $script:Results.Count; $i++) {
        if ($script:Results[$i][0] -eq "FAIL" -and $script:Results[$i][1] -eq $Label) {
            $script:Results[$i] = @("PASS", $NewText, "")
            Write-Host "  [OK]   $NewText" -ForegroundColor Green
            return
        }
    }
    Add-Pass $NewText
}

function Confirm-Action {
    param($Message)
    if ($CheckOnly) { return $false }
    if ($Yes)       { return $true  }
    return ((Read-Host "  ?  $Message [y/N]") -match '^[Yy]$')
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Host "企业 AI 化转型 Lab · AI Company —— 课前环境自检（Windows）" -ForegroundColor Blue

# ---- 平台 -------------------------------------------------------------------
Write-Step "平台"
if ($env:OS -ne "Windows_NT") {
    Write-Host "  这是 Windows 版脚本。macOS / Linux 请用 workshop-precheck-mac.sh" -ForegroundColor Red
    exit 1
}
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($os) { Add-Pass "$($os.Caption)（$($os.Version)）" } else { Add-Pass "Windows" }
if (Test-Admin) { Add-Pass "以管理员身份运行" }
else { Add-Warn "非管理员运行 —— 安装 WSL 时需要管理员权限，届时请用管理员 PowerShell 重跑" }

# ---- winget -----------------------------------------------------------------
Write-Step "包管理器 winget"
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) { Add-Pass "winget $(winget --version 2>$null)" }
else { Add-Fail "未找到 winget" "从 Microsoft Store 安装「应用安装程序 / App Installer」，然后重开 PowerShell" }

# ---- VS Code ----------------------------------------------------------------
Write-Step "VS Code 与扩展（Lab 02–04 用）"

function Resolve-CodeCli {
    $c = Get-Command code -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
                     "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd")) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

$codeCli = Resolve-CodeCli
if (-not $codeCli) {
    Add-Fail "未找到 VS Code" "winget install --id Microsoft.VisualStudioCode，或到 https://code.visualstudio.com/download 下载"
    if ($winget -and (Confirm-Action "winget 安装 VS Code ?")) {
        winget install --id Microsoft.VisualStudioCode --exact --silent `
            --accept-package-agreements --accept-source-agreements | Out-Null
        $codeCli = Resolve-CodeCli
    }
}

if ($codeCli) {
    Resolve-Fail "未找到 VS Code" "VS Code $((& $codeCli --version 2>$null | Select-Object -First 1))"
    $installed = @()
    try { $installed = & $codeCli --list-extensions 2>$null | ForEach-Object { $_.ToLower() } } catch { }
    # remote-wsl 是关键：没有它，VS Code 打开的是 Windows 侧文件系统，
    # 解释器和 .venv 全对不上。
    foreach ($ext in @("ms-vscode-remote.remote-wsl", "github.copilot", "github.copilot-chat", "ms-python.python")) {
        if ($installed -contains $ext) { Add-Pass "扩展 $ext" }
        elseif (Confirm-Action "安装扩展 $ext ?") {
            & $codeCli --install-extension $ext --force | Out-Null
            if ($LASTEXITCODE -eq 0) { Add-Pass "扩展 $ext 已安装" }
            else { Add-Fail "扩展 $ext 安装失败" "在 VS Code 扩展面板里手动搜索安装" }
        }
        else { Add-Fail "缺少扩展 $ext" "code --install-extension $ext" }
    }
}

# ---- WSL --------------------------------------------------------------------
Write-Step "WSL2 + $Distro"
$wslReady = $false
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Add-Fail "未安装 WSL" "以管理员身份运行 PowerShell 执行：wsl --install -d $Distro，重启后再跑本脚本"
} else {
    # wsl -l -q 输出是 UTF-16，先切编码再匹配
    $prev = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [Text.Encoding]::Unicode } catch { }
    $distros = @(wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    try { [Console]::OutputEncoding = $prev } catch { }

    if ($distros -contains $Distro) { Add-Pass "已安装发行版 $Distro"; $wslReady = $true }
    else {
        Add-Fail "未安装发行版 $Distro" "以管理员身份执行：wsl --install -d $Distro"
        if ((Test-Admin) -and (Confirm-Action "现在安装 WSL + $Distro（可能需要重启）?")) {
            wsl --install -d $Distro
            Write-Host ""
            Write-Host "  安装已触发。请：重启电脑 → 在 $Distro 窗口里设置用户名和密码 → 重新运行本脚本。" -ForegroundColor Yellow
            exit 1
        }
    }
}

# ---- Ubuntu 侧 --------------------------------------------------------------
Write-Step "Ubuntu 侧环境（Git / Python / 课程依赖 / az / kubectl）"

# 与 mac 版脚本、课程仓库 requirements 完全一致的锁定版本。
# MCP 2.x 移除了 mcp.server.fastmcp；agent-framework 元包会让 pip 解析失败；
# pydantic-monty 0.0.17+ 改了 API 会让沙箱画不出图。三处都必须钉住。
$payload = @'
#!/usr/bin/env bash
set -uo pipefail
SKIP_AZURE="${1:-0}"
AUTO="${2:-1}"
WORKDIR="$HOME/frontier-workshop-precheck"
REPORT="$WORKDIR/precheck-report.txt"
FAILED=0
RESULTS=()
ok()   { echo "  [OK]   $1"; RESULTS+=("PASS  $1"); }
bad()  { echo "  [FAIL] $1"; echo "         修复：$2"; RESULTS+=("FAIL  $1"); RESULTS+=("      -> $2"); FAILED=$((FAILED+1)); }
mkdir -p "$WORKDIR"

# 不带 -Yes 时逐项确认。脚本是以文件方式执行的（不是管道喂给 bash），
# 所以 stdin 干净，read 和 sudo 都能正常向你要输入。
ask() {
  [ "$AUTO" = "1" ] && return 0
  printf "  ?  %s [Y/n] " "$1"
  read -r reply || return 0
  case "$reply" in [Nn]*) return 1 ;; *) return 0 ;; esac
}

cat > "$WORKDIR/requirements.txt" <<'REQ'
mcp==1.29.0
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
uvicorn==0.52.3
REQ

echo "== 基础工具 =="
need=""
for pkg in git python3 python3-venv python3-pip curl; do
  dpkg -s "$pkg" >/dev/null 2>&1 || need="$need $pkg"
done
if [ -n "$need" ]; then
  if ask "安装${need}（需要你的 Ubuntu 密码）"; then
    sudo apt-get update -qq && sudo apt-get install -y $need
  fi
fi
command -v git >/dev/null 2>&1 && ok "git $(git --version | awk '{print $3}')" \
  || bad "git 未安装" "sudo apt-get install -y git"

echo "== 网络连通性 =="
for pair in "github.com|https://github.com" \
            "pypi.org|https://pypi.org/simple/mcp/" \
            "Azure|https://management.azure.com/"; do
  nm="${pair%%|*}"; url="${pair##*|}"
  if curl -sS --max-time 10 -o /dev/null "$url" >/dev/null 2>&1; then
    ok "可访问 $nm"
  else
    bad "无法访问 $nm（$url）" "换个网络重试；公司网络请检查代理 / VPN"
  fi
done

echo "== Python =="
PY=""
for c in python3.12 python3.11 python3.10 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  v="$("$c" -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null)"
  case "$v" in 3.10|3.11|3.12) PY="$(command -v "$c")"; break ;; esac
done
if [ -n "$PY" ]; then
  ok "$($PY -V 2>&1)"
else
  bad "没有 Python 3.10-3.12" "sudo apt-get install -y python3 python3-venv python3-pip"
fi

echo "== 课程依赖（约 64 个包 / ~210MB，提前下好，课上就是秒装）=="
if [ -n "$PY" ]; then
  [ -x "$WORKDIR/.venv/bin/python" ] || "$PY" -m venv "$WORKDIR/.venv"
  VPY="$WORKDIR/.venv/bin/python"
  if [ -x "$VPY" ]; then
    if ! "$VPY" -c "import agent_framework, mcp, matplotlib, fastapi" >/dev/null 2>&1; then
      if ask "下载安装课程依赖（约 210MB，视网速可能要几分钟）"; then
        "$VPY" -m pip install --quiet --upgrade pip
        "$VPY" -m pip install -r "$WORKDIR/requirements.txt"
      fi
    fi
    if "$VPY" -c "import agent_framework, mcp, matplotlib, fastapi" >/dev/null 2>&1; then
      ok "依赖齐全，pip 缓存已就绪"
    else
      bad "依赖安装失败" "看上面的 pip 输出；换个网络后重跑本脚本"
    fi
  else
    bad "虚拟环境创建失败" "sudo apt-get install -y python3-venv 后重跑"
  fi
fi

if [ "$SKIP_AZURE" != "1" ]; then
  echo "== Lab 05 工具 =="
  if ! command -v az >/dev/null 2>&1; then
    ask "安装 Azure CLI（需要 sudo）" && curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  fi
  command -v az >/dev/null 2>&1 && ok "az $(az version --output tsv --query '"azure-cli"' 2>/dev/null)" \
    || bad "Azure CLI 未安装" "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"

  # Lab 05 的 deploy.sh 会调 az containerapp。它是动态扩展：不预装的话，
  # 学员第一次跑部署脚本会撞上"是否安装扩展"的交互提示，正好卡在最后 30 分钟。
  if command -v az >/dev/null 2>&1; then
    if ! az extension show --name containerapp >/dev/null 2>&1; then
      ask "安装 az 扩展 containerapp（Lab 05 部署脚本要用）" \
        && az extension add --name containerapp --only-show-errors >/dev/null 2>&1
    fi
    az extension show --name containerapp >/dev/null 2>&1 && ok "az 扩展 containerapp" \
      || bad "缺少 az 扩展 containerapp" "az extension add --name containerapp"
  fi

  if ! command -v kubectl >/dev/null 2>&1; then
    ask "安装 kubectl（需要 sudo）" && { command -v az >/dev/null 2>&1 && sudo az aks install-cli; }
  fi
  command -v kubectl >/dev/null 2>&1 && ok "$(kubectl version --client 2>/dev/null | head -1)" \
    || bad "kubectl 未安装" "sudo az aks install-cli"
fi

if [ "$FAILED" -eq 0 ]; then V="READY"; else V="NOT-READY"; fi
LINE="[precheck-wsl] $V | ubuntu | $( [ -n "$PY" ] && $PY -V 2>&1 || echo no-python ) | FAIL=$FAILED"
{ echo "$LINE"; printf '%s\n' "${RESULTS[@]}"; } > "$REPORT"
echo
echo "$LINE"
echo "  完整报告（WSL 内）：$REPORT"
exit "$FAILED"
'@

$wslReceipt = ""
$wslReport  = ""
if (-not $wslReady) {
    Add-Skip "跳过（WSL 尚未就绪）"
} elseif ($CheckOnly) {
    Add-Skip "跳过（--CheckOnly 不做安装类检查）"
} else {
    # 写成文件再执行，而不是管道喂给 bash -s：管道会占用 stdin，
    # 里面的 sudo 就没法向你要密码了。
    $tmp = Join-Path $env:TEMP "workshop-precheck-wsl.sh"
    [System.IO.File]::WriteAllText($tmp, ($payload -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
    $wslPath = & wsl -d $Distro -- wslpath -u ($tmp -replace '\\', '/')
    $azFlag   = if ($SkipAzure) { "1" } else { "0" }
    $autoFlag = if ($Yes)       { "1" } else { "0" }

    Write-Host ""
    & wsl -d $Distro -- bash $wslPath $azFlag $autoFlag
    $wslExit = $LASTEXITCODE

    $wslReceipt = & wsl -d $Distro -- bash -lc "head -1 ~/frontier-workshop-precheck/precheck-report.txt 2>/dev/null"
    $wslReport  = & wsl -d $Distro -- bash -lc "wslpath -w ~/frontier-workshop-precheck/precheck-report.txt 2>/dev/null"
    if ($wslExit -eq 0) { Add-Pass "Ubuntu 侧环境就绪" }
    else { Add-Fail "Ubuntu 侧还有未通过项" "按上面 Ubuntu 输出里每条的「修复：」处理，然后重跑本脚本" }
}

# ---- 手动确认 ---------------------------------------------------------------
Write-Host ""
Write-Host "================ 手动确认（30 秒，脚本查不了）================" -ForegroundColor Blue
Write-Host @"
  1. 打开 VS Code，左下角点 "><" -> Connect to WSL，进入 Ubuntu
  2. 确认已登录 GitHub 账号
  3. 打开 Copilot Chat（Ctrl+Alt+I），确认输入框上方能切到 "Agent" 模式
  4. 在 Agent 模式里随便问一句，能正常回答 = Copilot 可用

  切不到 Agent 模式 = 你的 GitHub 组织策略关掉了它，现场无法解决。
  -> 找组织的 GitHub 管理员开启，或装 Claude Code / Cursor 顶替（讲义里两种写法都有）
"@

# ---- 汇总 -------------------------------------------------------------------
Write-Host ""
Write-Host "================ 结果 ================" -ForegroundColor Blue
$nFail = 0; $nWarn = 0
foreach ($r in $script:Results) {
    switch ($r[0]) {
        "FAIL" { Write-Host "  FAIL  $($r[1])" -ForegroundColor Red
                 if ($r[2]) { Write-Host "        -> $($r[2])" -ForegroundColor DarkGray }
                 $nFail++ }
        "WARN" { Write-Host "  WARN  $($r[1])" -ForegroundColor Yellow; $nWarn++ }
    }
}
if ($nFail -eq 0 -and $nWarn -eq 0) { Write-Host "  全部通过" -ForegroundColor Green }

$verdict = if ($nFail -eq 0) { "READY" } else { "NOT-READY" }
$receipt = "[precheck] $verdict | windows+wsl | FAIL=$nFail WARN=$nWarn"

$reportPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "precheck-report-windows.txt"
$lines = @($receipt, "生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", "")
foreach ($r in $script:Results) {
    $lines += ("{0,-5} {1}" -f $r[0], $r[1])
    if ($r[0] -eq "FAIL" -and $r[2]) { $lines += "      -> $($r[2])" }
}
if ($wslReceipt) { $lines += ""; $lines += "Ubuntu 侧: $wslReceipt" }
if ($wslReport)  { $lines += "Ubuntu 侧报告: $wslReport" }
$lines | Set-Content -Path $reportPath -Encoding UTF8

Write-Host ""
Write-Host "================ 回执 ================" -ForegroundColor Blue
Write-Host "  $receipt"
if ($wslReceipt) { Write-Host "  $wslReceipt" }
Write-Host "  完整报告：$reportPath" -ForegroundColor DarkGray
if ($wslReport) { Write-Host "  Ubuntu 侧报告：$wslReport" -ForegroundColor DarkGray }
Write-Host ""

if ($nFail -eq 0) {
    Write-Host "环境就绪。把上面的回执发到班级群就算准备完毕。" -ForegroundColor Green
    Write-Host "上课提醒：所有课程命令都在 WSL 的 Ubuntu 里敲，不要用 PowerShell。" -ForegroundColor DarkGray
    exit 0
} else {
    Write-Host "还有 $nFail 项未通过。按每条的「->」修完，重跑本脚本，直到回执变成 READY。" -ForegroundColor Red
    Write-Host "自助兜底顺序："
    Write-Host "  1. 重跑：powershell -ExecutionPolicy Bypass -File workshop-precheck-windows.ps1 -Yes"
    Write-Host "  2. 装 Docker Desktop（课上用容器跑，完全不依赖本机 Python）"
    Write-Host "  3. 把桌面上的 precheck-report-windows.txt 发到班级群"
    exit 1
}
