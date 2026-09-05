# =============================================================================
# 企业 AI 化转型 Lab · AI Company —— 一键安装（Windows）
#
# 讲师已经把所有大文件放进这个包了，这个脚本只做"安装"，不下载。
#
# 用法：右键 PowerShell → 以管理员身份运行（装 WSL 需要），然后：
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
#
# 分两侧装：
#   Windows 侧 —— VS Code、Git、VS Code 扩展
#   WSL(Ubuntu) 侧 —— Python、课程依赖、az、kubectl（课程命令都在这里跑）
#
# 反复运行是安全的。如果 WSL 是这次新装的，需要重启一次再跑一遍。
# =============================================================================
param(
    [switch]$DryRun,
    [string]$Distro = "Ubuntu"
)

$ErrorActionPreference = "Continue"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Failed = 0

function Write-Step { param($t) Write-Host ""; Write-Host "==> $t" -ForegroundColor Blue }
function Ok   { param($t) Write-Host "  [OK]   $t" -ForegroundColor Green }
function Warn { param($t) Write-Host "  [!]    $t" -ForegroundColor Yellow }
function Bad  { param($t, $fix) Write-Host "  [FAIL] $t" -ForegroundColor Red
                if ($fix) { Write-Host "         修复：$fix" -ForegroundColor DarkGray }
                $script:Failed++ }
function Test-Admin {
    try { return ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator) } catch { return $false }
}

Write-Host "企业 AI 化转型 Lab · AI Company —— 一键安装（Windows）" -ForegroundColor Blue
if ($DryRun) { Write-Host "DryRun 模式：不会真的改动系统" -ForegroundColor Yellow }

# ---- VS Code ----------------------------------------------------------------
Write-Step "VS Code"
$codeCli = $null
foreach ($p in @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd")) {
    if (Test-Path $p) { $codeCli = $p; break }
}
if ($codeCli) {
    Ok "已安装，跳过"
} else {
    $exe = Join-Path $Here "installers\VSCodeUserSetup-x64.exe"
    if (Test-Path $exe) {
        if ($DryRun) { Write-Host "  [dry-run] $exe /VERYSILENT" -ForegroundColor DarkGray }
        else {
            # /mergetasks 把 code 加进 PATH，否则后面装扩展找不到命令。
            Start-Process -FilePath $exe -Wait -ArgumentList `
                "/VERYSILENT","/SP-","/MERGETASKS=!runcode,addcontextmenufiles,addtopath"
            foreach ($p in @(
                "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
                "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd")) {
                if (Test-Path $p) { $codeCli = $p; break }
            }
            if ($codeCli) { Ok "VS Code 已安装" } else { Bad "VS Code 安装后仍找不到" }
        }
    } else { Bad "包里缺少 VSCodeUserSetup-x64.exe" }
}

# ---- Git（Windows 侧，可选：课程主要在 WSL 里用 git）------------------------
Write-Step "Git for Windows"
if (Get-Command git -ErrorAction SilentlyContinue) {
    Ok "已安装，跳过"
} else {
    $exe = Join-Path $Here "installers\Git-64-bit.exe"
    if (Test-Path $exe) {
        if ($DryRun) { Write-Host "  [dry-run] $exe /VERYSILENT" -ForegroundColor DarkGray }
        else {
            Start-Process -FilePath $exe -Wait -ArgumentList "/VERYSILENT","/NORESTART"
            Ok "Git 已安装"
        }
    } else { Warn "包里没有 Git 安装器（WSL 里会另装 Linux 版 git，通常够用）" }
}

# ---- VS Code 扩展（本地 .vsix）----------------------------------------------
Write-Step "VS Code 扩展（本地安装）"
if ($codeCli) {
    $installed = @()
    try { $installed = & $codeCli --list-extensions 2>$null | ForEach-Object { $_.ToLower() } } catch { }
    Get-ChildItem (Join-Path $Here "vsix\*.vsix") -ErrorAction SilentlyContinue | ForEach-Object {
        $id = $_.BaseName
        if ($installed -contains $id.ToLower()) { Ok "$id (已装)" }
        elseif ($DryRun) { Write-Host "  [dry-run] install $id" -ForegroundColor DarkGray }
        else {
            & $codeCli --install-extension $_.FullName --force 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Ok $id } else { Bad "$id 安装失败" }
        }
    }
} else {
    Bad "没有 code 命令，扩展要手动装" "在 VS Code 里 Ctrl+Shift+P → Install from VSIX，选 vsix\ 里的文件"
}

# ---- WSL2 + Ubuntu ----------------------------------------------------------
Write-Step "WSL2 + $Distro"
$wslReady = $false
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Bad "未安装 WSL" "以管理员身份运行：wsl --install -d $Distro，重启后重跑本脚本"
} else {
    $prev = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [Text.Encoding]::Unicode } catch { }
    $distros = @(wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    try { [Console]::OutputEncoding = $prev } catch { }

    if ($distros -contains $Distro) { Ok "已安装 $Distro"; $wslReady = $true }
    elseif ($DryRun) { Write-Host "  [dry-run] wsl --install -d $Distro" -ForegroundColor DarkGray }
    elseif (Test-Admin) {
        # WSL 本身必须联网装（微软不提供可离线分发的发行版包）。
        Warn "正在安装 WSL + $Distro（这一步需要联网）"
        wsl --install -d $Distro
        Write-Host ""
        Write-Host "  安装已触发。请：重启电脑 → 在 $Distro 窗口里设用户名和密码 → 重新运行本脚本。" -ForegroundColor Yellow
        exit 1
    } else {
        Bad "未安装 $Distro，且当前不是管理员" "右键以管理员身份运行 PowerShell 后重跑本脚本"
    }
}

# ---- WSL 侧：Python / 依赖 / az / kubectl -----------------------------------
Write-Step "WSL($Distro) 侧环境"
if (-not $wslReady) {
    Bad "跳过（WSL 尚未就绪）" "先装好 WSL 并重启，再重跑本脚本"
} elseif ($DryRun) {
    Write-Host "  [dry-run] 把 wsl\ 复制进 WSL 并执行 install-in-wsl.sh" -ForegroundColor DarkGray
} else {
    # 把整个 wsl\ 目录经 /mnt/c 复制进 WSL 家目录再装：直接在 /mnt 下跑 pip
    # 会因为 Windows 文件系统不支持 Linux 权限位而出各种怪问题。
    $wslSrc = (wsl wslpath -a ("'" + (Join-Path $Here "wsl") + "'") 2>$null)
    if (-not $wslSrc) { $wslSrc = (wsl wslpath -a "$Here/wsl" 2>$null) }
    if ($wslSrc) {
        Write-Host "  正在把离线文件复制进 WSL（约 300MB，请稍候）..." -ForegroundColor DarkGray
        wsl bash -lc "rm -rf ~/workshop-offline && mkdir -p ~/workshop-offline && cp -r '$wslSrc'/. ~/workshop-offline/ && chmod +x ~/workshop-offline/install-in-wsl.sh"
        if ($LASTEXITCODE -eq 0) {
            Ok "文件已复制进 WSL"
            Write-Host ""
            wsl bash -lc "bash ~/workshop-offline/install-in-wsl.sh"
            if ($LASTEXITCODE -ne 0) { Bad "WSL 侧安装未全部成功（看上面的输出）" }
        } else { Bad "复制到 WSL 失败" }
    } else { Bad "无法解析 WSL 路径" }
}

# ---- 汇总 -------------------------------------------------------------------
if ($DryRun) { Write-Host ""; Write-Host "DryRun 结束，没有改动任何东西。" -ForegroundColor Yellow; exit 0 }

Write-Host ""
Write-Host "================ 手动确认（30 秒，脚本查不了）================" -ForegroundColor Blue
Write-Host @"
  1. 打开 VS Code，左下角 >< → Connect to WSL，进入 Ubuntu
  2. 确认已登录 GitHub 账号
  3. 打开 Copilot Chat（Ctrl+Alt+I），确认能切到 "Agent" 模式

  切不到 Agent 模式 = 你的 GitHub 组织策略关掉了它，现场无法解决。
"@

Write-Host ""
if ($script:Failed -eq 0) {
    Write-Host "安装完成。" -ForegroundColor Green
    Write-Host "把 WSL 侧打印的那行 [precheck] 回执发到班级群就算准备完毕。" -ForegroundColor DarkGray
    exit 0
} else {
    Write-Host "有 $($script:Failed) 项失败。把上面的输出发到班级群。" -ForegroundColor Red
    exit 1
}
