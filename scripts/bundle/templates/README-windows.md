# 课前环境安装 · Windows

**请在开课前一天完成，不要留到现场。** Windows 需要重启一次，务必留出时间。

这个包里已经放好了所有需要的软件，**装的时候基本不需要下载**，所以哪怕现场网络很慢也不影响你上课。

---

## 先理解一件事：你会在 WSL 的 Ubuntu 里上课

课程里的部署脚本是 bash，**PowerShell 跑不了**。所以：

- **Windows 侧**只装 VS Code、Git 和扩展
- **真正的运行环境在 WSL 的 Ubuntu 里** —— Python、课程依赖、`az`、`kubectl` 都装在那边

这个脚本两侧都会自动帮你装好，你不用手动切来切去。

---

## 一步搞定

1. 把这个文件夹整个解压出来（**不要在压缩包里直接双击**）
2. 开始菜单搜 **PowerShell** → **右键 → 以管理员身份运行**（装 WSL 必须要管理员）
3. 粘贴这两行（第一行是进入文件夹，按你实际解压的位置改）：

```powershell
cd "$env:USERPROFILE\Downloads\workshop-bundle-windows"
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### ⚠️ 中途会让你重启一次，这是正常流程

如果你之前没装过 WSL，脚本会先装 WSL2 + Ubuntu，然后提示你重启。请：

1. **重启电脑**
2. 重启后会自动弹出一个 Ubuntu 窗口，让你**设置用户名和密码**（这是 Ubuntu 的账号，和 Windows 无关；密码输入时不显示字符，正常）
3. **把上面那两行命令再跑一遍**

第二遍才会装 Python、课程依赖、`az` 和 `kubectl`。

> WSL 本身必须联网安装 —— 微软不提供可以离线分发的发行版包，这一项没法放进离线包里。它大约 500MB，请在**家里的网络**下完成。

装完最后会打印一行回执：

```text
[precheck] READY | wsl | Python 3.12.3 | FAIL=0
```

**看到 `READY` 就把这行发到班级群，你的准备就完成了。**

---

## 装了什么

| 位置 | 组件 | 来源 |
|---|---|---|
| Windows | VS Code | 包内 |
| Windows | Git for Windows | 包内 |
| Windows | Copilot、Copilot Chat、Python、**WSL** 扩展 | 包内 |
| WSL | Python 3.12 + venv | Ubuntu 自带 / apt（很小） |
| WSL | 课程依赖（64 个包） | 包内，**完全离线安装** |
| WSL | Azure CLI | 包内 `.deb`，**离线安装** |
| WSL | kubectl | 包内 |

> **WSL 扩展是关键。** 没有它，VS Code 打开的是 Windows 侧的文件，Python 解释器全对不上。脚本已经帮你装了。

---

## 课上建仓库环境时，也不用下载

安装脚本已经把全部 wheel 留了一份在 WSL 的 `~/frontier-workshop-precheck/wheels/`。
课上按讲义建 `code/.venv` 时，在 **WSL 终端**里用下面这条命令，同样不联网：

```bash
cd code
python3.12 -m venv .venv
source .venv/bin/activate
pip install --no-index --find-links ~/frontier-workshop-precheck/wheels \
  -r mcp/requirements.txt -r agents/requirements.txt
```

> 讲义里给的是不带 `--no-index` 的版本（面向没用离线包的同学）。
> 你用了离线包，就加上这两个参数，省掉约 210MB 下载。

---

## 出问题了怎么办

**先重跑一次**，脚本是幂等的，已经装好的会自动跳过：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

想先看看它会做什么、不实际改动系统：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
```

只想重装 WSL 那一侧（Windows 侧已经好了）：

```powershell
wsl bash -lc "bash ~/workshop-offline/install-in-wsl.sh"
```

搞不定就把命令的完整输出发到班级群，讲师课前帮你看。

### 常见情况

**脚本反复说「未安装发行版 Ubuntu」** —— 你装完 WSL 没重启，或者重启后没在 Ubuntu 窗口里设置用户名密码。补上这两步再重跑。

**「无法加载文件，因为在此系统上禁止运行脚本」** —— 你漏了 `-ExecutionPolicy Bypass`。用上面给的完整命令。

**不是管理员** —— WSL 装不了。关掉窗口，右键 PowerShell 重新「以管理员身份运行」。

---

## 脚本查不了的两件事（手动，30 秒）

脚本能看到扩展装没装，**但看不到你的 GitHub 登录状态和组织策略**。Lab 02–04 全程依赖 Copilot，务必自己确认：

1. 打开 VS Code，**左下角 `><` → Connect to WSL**，进入 Ubuntu
2. 确认**已登录 GitHub 账号**
3. 打开 Copilot Chat（`Ctrl+Alt+I`），确认输入框上方能切到 **Agent** 模式

> ⚠️ **切不到 Agent 模式 = 你所在 GitHub 组织的策略把它关掉了。这是唯一必须提前一天发现的问题**，当天再找管理员来不及。
> → 找组织的 GitHub 管理员开启；或者装 Claude Code / Cursor 顶替，讲义里两种写法都给了。
