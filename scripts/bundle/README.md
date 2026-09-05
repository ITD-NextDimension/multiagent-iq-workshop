# 离线包（讲师用）

给学员分发的**预装软件包**。学员拿到后一条命令装完，现场不需要再下载大文件。

课前自检脚本（`../pre-request-check/`）是"联网自己装"的路子；这里是"讲师预制、U 盘/网盘分发"的路子。两者可以并行给：网络好的学员跑自检脚本，网络差或公司电脑有代理限制的学员用离线包。

---

## 打包

在你自己的 mac 上跑一次即可，**三个包（含 Windows 的）都能在 mac 上打出来**：

```bash
bash scripts/bundle/build-bundle.sh
```

产出：

```text
scripts/bundle/dist/
  workshop-bundle-mac-arm64/   523MB  → workshop-bundle-mac-arm64.zip   471MB
  workshop-bundle-mac-intel/   553MB  → workshop-bundle-mac-intel.zip   505MB
  workshop-bundle-windows/     534MB  → workshop-bundle-windows.zip     479MB
```

mac 按芯片分成两个包：universal 版 VS Code 是 542MB，分架构后只要 309/332MB，
每个学员少下约 350MB。学员下错包时 `install.sh` 第一步就会明确告诉他该下哪个
（靠包内的 `arch.txt` 比对 `uname -m`），不会留下半装的系统。

常用参数：

| 参数 | 作用 |
|---|---|
| `--platform mac` / `windows` | 只打一个平台 |
| `--no-zip` | 只产出目录，不压缩 |
| `--out DIR` | 换输出目录 |

**反复运行是安全的**：已下载且大小合格的文件会跳过，网络中断后重跑能续上。

> `dist/` 已被 `.gitignore` 排除 —— 1.4GB 二进制不进版本库，需要时重新生成。

---

## 包里有什么

| 组件 | macOS 包 | Windows 包 | 离线安装？ |
|---|---|---|---|
| VS Code | 按芯片分 arm64 / x64 .zip | x64 用户版 .exe | ✅ |
| Python 3.12.10 | .pkg | 用 WSL 自带 | ✅ |
| 课程依赖（64 个包） | 对应架构的 wheels | manylinux wheels | ✅ |
| Copilot / Copilot Chat / Python 扩展 | .vsix | .vsix | ✅ |
| WSL 扩展 | — | .vsix | ✅ |
| Git | 系统自带 | Git-64-bit.exe | ✅ |
| kubectl | 对应架构的 darwin 版 | linux amd64 | ✅ |
| Azure CLI | ⚠️ 无官方离线包 | .deb（Ubuntu noble） | mac ❌ / win ✅ |
| WSL2 + Ubuntu | — | ⚠️ 必须联网 | ❌ |

### 两个无法离线的项，课前必须告诉学员

1. **macOS 的 Azure CLI** —— 微软在 mac 上只提供 Homebrew 渠道，没有可分发的独立安装包。学员需要 `brew install azure-cli`（约 100MB）。只在 Lab 05 用到，实在装不上可以两人一机。
2. **Windows 的 WSL2 + Ubuntu** —— 微软不提供可离线分发的发行版包，`wsl --install` 必须联网（约 500MB），且**需要重启一次**。这是 Windows 学员课前最容易卡住的地方，务必让他们提前一天做完。

### 为什么 Windows 包里装的是 Linux 版工具

课程所有命令都在 WSL 的 Ubuntu 里执行（`deploy.sh` 是 bash，PowerShell 跑不了），VS Code 通过 Remote-WSL 连进去。所以 Windows 侧只需要 VS Code + Git + 扩展，真正的运行时依赖（Python、课程依赖、`az`、`kubectl`）全是 Linux 版，装在 WSL 里。

---

## 分发与学员操作

把三个 zip 传网盘或拷进 U 盘，**让学员按自己的电脑只下一个**。

| 平台 | 学员操作 |
|---|---|
| macOS | 先按芯片选包（ → 关于本机）→ 解压 → `bash install.sh` |
| Windows | 解压 → 右键 PowerShell **以管理员身份运行** → `.\install.ps1` |

每个包里都有一份面向学员的 `README.md`（中文、含排障），以及 `环境清单.html`（可勾选的网页版）。

学员装完会得到一行回执，让他们发到班级群：

```text
[precheck] READY | macos | Python 3.12.10 | FAIL=0 WARN=0
```

---

## 内部结构

```text
workshop-bundle-mac-{arm64,intel}/
  install.sh              学员一键安装（支持 --dry-run）
  verify.sh               装完自动调用的环境自检
  README.md               学员看的说明（中文）
  环境清单.html            可勾选的网页版清单
  arch.txt                arm64 / x86_64 —— 供 install.sh 防呆比对
  requirements.txt        与 code/agents/requirements.txt 同源
  installers/             VS Code / Python / kubectl（均为该架构）
  vsix/                   3 个 VS Code 扩展
  wheels/                 63 个 wheel（该架构）

workshop-bundle-windows/
  install.ps1             学员一键安装（Windows 侧，支持 -DryRun）
  verify.ps1              环境自检
  README.md / 环境清单.html
  requirements.txt
  installers/             VS Code / Git
  vsix/                   4 个扩展（含 remote-wsl）
  wsl/                    ← 由 install.ps1 复制进 WSL 后执行
    install-in-wsl.sh     WSL 侧安装
    wheels/               63 个 manylinux wheel
    azure-cli.deb
    kubectl-linux-amd64
```

`install.ps1` 会把整个 `wsl/` 复制到 WSL 的家目录再安装 —— 直接在 `/mnt/c` 下跑 pip 会因为 Windows 文件系统不支持 Linux 权限位而出各种怪问题。

---

## 版本锁定

`build-bundle.sh` 顶部有三个锁定版本，升级前先确认：

| 变量 | 当前值 | 说明 |
|---|---|---|
| `PY_VER` | `3.12.10` | 3.12.10 之后的 3.12.x 只发源码，**没有二进制安装器** |
| `KUBECTL_VER` | `v1.37.0` | |
| `AZ_DEB_DIST` | `noble` | `wsl --install -d Ubuntu` 当前给的是 24.04 |

Python 依赖的版本不在这里，它直接读 `code/agents/requirements.txt`，与课程仓库和自检脚本三方一致。
