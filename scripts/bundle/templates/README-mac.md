# 课前环境安装 · macOS

**请在开课前一天完成，不要留到现场。**

这个包里已经放好了所有需要的软件，**装的时候基本不需要下载**，所以哪怕现场网络很慢也不影响你上课。

---

## 先确认你该下哪个包

mac 有两种芯片，包也分两个，**下错了装不上**。查看方法：点左上角  → 「关于本机」：

| 「芯片」或「处理器」显示 | 你要下的包 |
|---|---|
| Apple M1 / M2 / M3 / M4… | `workshop-bundle-mac-arm64.zip` |
| Intel Core i5 / i7 / i9… | `workshop-bundle-mac-intel.zip` |

万一下错了也不要紧，脚本第一步就会告诉你下错了、该下哪个，不会把系统搞乱。

---

## 一步搞定

1. 把这个文件夹整个解压出来（**不要在压缩包里直接双击**）
2. 打开「终端」（聚焦搜索 `Terminal`）
3. 输入 `bash `（**注意后面有个空格**），然后把解压出来的文件夹里的 `install.sh` **直接拖进终端窗口**，回车

或者直接粘贴（按你实际的包名改 `arm64` / `intel`）：

```bash
bash ~/Downloads/workshop-bundle-mac-arm64/install.sh
```

中途会问你要一次**管理员密码**（装 Python 和 kubectl 需要），输入你的开机密码即可（输入时不显示字符，是正常的）。

装完最后会打印一行回执：

```text
[precheck] READY | macos | Python 3.12.10 | FAIL=0 WARN=0
```

**看到 `READY` 就把这行发到班级群，你的准备就完成了。**

---

## 装了什么

| 组件 | 用途 | 来源 |
|---|---|---|
| VS Code | 上课的主要工具 | 包内 |
| Python 3.12 | 跑课程代码 | 包内（系统已有合适版本则跳过） |
| 课程依赖（64 个包） | Agent / MCP / 图表 | 包内，**完全离线安装** |
| Copilot、Copilot Chat、Python 扩展 | Lab 02–04 靠它们 | 包内 |
| kubectl | Lab 05 部署 | 包内 |
| Azure CLI | Lab 05 部署 | ⚠️ 见下 |

### 唯一需要联网的一项：Azure CLI

微软在 macOS 上**只提供 Homebrew 渠道**，没有可以离线分发的独立安装包，所以这一项没法放进包里。它只在 Lab 05（最后 30 分钟）才用到。

如果你已经有 Homebrew：

```bash
brew install azure-cli
```

没有 Homebrew 的话先装它（这一步也要联网）：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/brew/HEAD/install.sh)"
brew install azure-cli
```

**装不上也不用慌**，跟讲师说一声，Lab 05 可以两人一台机器做。

---

## 出问题了怎么办

**先重跑一次**，脚本是幂等的，已经装好的会自动跳过：

```bash
bash ~/Downloads/workshop-bundle-mac-arm64/install.sh
```

想先看看它会做什么、不实际改动系统：

```bash
bash ~/Downloads/workshop-bundle-mac-arm64/install.sh --dry-run
```

只想重新体检一遍：

```bash
bash ~/Downloads/workshop-bundle-mac-arm64/verify.sh --check-only
```

完整报告在 `~/frontier-workshop-precheck/precheck-report.txt`，**搞不定就把这个文件发到班级群**，讲师课前帮你看。

### 常见情况

**「无法打开，因为无法验证开发者」** —— macOS 对下载来的 App 的拦截。脚本已经自动处理了；如果还是被拦，到「系统设置 → 隐私与安全性」，在下面点「仍要打开」。

**提示找不到 `code` 命令** —— 打开 VS Code，按 `⇧⌘P`，输入 `Shell Command: Install 'code' command in PATH`，回车，然后重跑 install.sh。

---

## 脚本查不了的两件事（手动，30 秒）

脚本能看到扩展装没装，**但看不到你的 GitHub 登录状态和组织策略**。Lab 02–04 全程依赖 Copilot，务必自己确认：

1. 打开 VS Code，确认**已登录 GitHub 账号**
2. 打开 Copilot Chat（`⌃⌘I`），确认输入框上方能切到 **Agent** 模式
3. 在 Agent 模式里随便问一句，能正常回答

> ⚠️ **切不到 Agent 模式 = 你所在 GitHub 组织的策略把它关掉了。这是唯一必须提前一天发现的问题**，当天再找管理员来不及。
> → 找组织的 GitHub 管理员开启；或者装 Claude Code / Cursor 顶替，讲义里两种写法都给了。
