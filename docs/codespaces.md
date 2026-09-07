# 用 Codespaces 跑完这门课 · 学员操作手册

> 这份手册从「打开浏览器」一直写到「课后清理」，按顺序做就行。
> 走本地安装路线的同学不用看这份，看[课前环境清单](../scripts/pre-request-check/00-学员环境清单.md)。

Codespaces 是 GitHub 提供的云端开发环境。你的代码、Python、VS Code 都跑在云上，
本地只要一个浏览器。**这门课需要的 64 个依赖、Azure CLI、kubectl 都已经装好了**，
你不需要在自己电脑上装任何东西。

---

## 开始之前 · 确认四件事

| # | 要确认的 | 怎么确认 |
|---|---|---|
| 1 | 有 GitHub 账号 | 能打开 <https://github.com> 并已登录 |
| 2 | 网络能开 Codespaces | 能打开 <https://github.dev>（域名是 `*.app.github.dev`） |
| 3 | **Copilot 的 Agent 模式可用** | 见下方说明，**这条最重要** |
| 4 | 用 Chrome 或 Edge | Safari 也能用，但 Chrome/Edge 体验更稳 |

**第 3 条为什么最重要**：Lab 02–04 要用 GitHub Copilot 的 **Agent 模式**来读代码、
改代码。Agent 模式包含在免费版 Copilot 里，不用额外付费，但有两种情况会用不了：

- **你用的是公司/组织的 GitHub 账号** → 组织策略可能把 Agent 模式关掉了。
  这个只能找组织管理员开，**当天现找来不及，请提前一天确认**。
- **免费版额度用尽** → Copilot 现在按用量计费，免费额度用完 Agent 模式就不响应了。

两种情况的备选方案都一样：改用 Claude Code 或 Cursor 完成 Lab 02–04
（用的是同一套 MCP 协议，只是注册配置文件不同）。**课前发现，比课上发现好。**

---

## 第 1 步 · 创建 Codespace

1. 打开讲师给的仓库地址
2. 点绿色的 **Code** 按钮 → 切到 **Codespaces** 标签页
3. 点 **Create codespace on main**

> ### ⚠️ 不要先 fork
>
> 直接在**讲师的仓库**上创建。预构建（依赖已经装好的镜像）是跟着仓库走的，
> fork 出来的仓库不继承，你会白等好几分钟重装 64 个包。
>
> 想保留自己写的代码？往下看「课后 · 保存你的作业」，有办法。

浏览器会打开一个网页版 VS Code。第一次创建时下方会滚动一些日志，
**等到左下角显示绿色的 Codespaces 图标、终端可以输入**，就算好了。

---

## 第 2 步 · 确认环境就绪

按 <kbd>Ctrl</kbd>+<kbd>`</kbd>（反引号，在 Tab 键上面）打开终端。你应该看到类似这样的欢迎信息：

```text
环境就绪 · Python 3.12.x · 64 个包

先验证一下（不需要任何凭证）：
  cd code && python mcp/server.py --selftest
  cd code/agents && python test_workflow.py
```

**检查提示符最前面有没有 `(.venv)`。** 有就说明虚拟环境已自动激活，可以直接敲命令。

<details>
<summary>没看到 <code>(.venv)</code> 怎么办</summary>

先在**当前终端**手动激活（只对这个终端有效）：

```bash
source /workspaces/*/code/.venv/bin/activate
```

如果每开一个新终端都要重来一遍，说明自动激活那行没写进去，补上：

```bash
echo 'source /workspaces/*/code/.venv/bin/activate' >> ~/.bashrc
```

如果连 `code/.venv` 都不存在，说明依赖没装成功，手动补一次（约 2–3 分钟）：

```bash
bash .devcontainer/on-create.sh
```
</details>

跑一条命令确认包数量对：

```bash
pip list --format=freeze | wc -l
```

**期望输出：`64`**。数字不对就告诉讲师，别往下走。

---

## 第 3 步 · Lab 01 · 让系统读得懂业务

这一步**不需要任何凭证**，纯本地验证。

```bash
cd code
python mcp/server.py --selftest
```

**期望输出的最后一行**（这是 Lab 01 的验收标准）：

```json
{"entityType": "Project", "op": "sum", "field": "budget", "groupBy": "status", "result": {"active": 105000.0, "done": 25000.0}}
```

看到 `{"active": 105000.0, "done": 25000.0}` 就对了 —— 说明本体、数据绑定、
实例数据三层已经能被一起解析。

接着验证智能体的离线能力：

```bash
cd agents
python test_workflow.py
```

**期望输出的最后一行**：

```text
All offline tests passed ✅
```

> **会看到一堆 `IncompleteFieldDefinitionWarning`，这是正常的**，不是报错。
> 它来自 MCP SDK 依赖的 `pydantic-settings`，检查照样全过，不用管。

---

## 第 4 步 · Lab 02 · 把本体变成可调用的工具

这一步主要是读文件 + 用 Copilot 理解结构。左侧文件树里依次打开：

- `code/dataIQ/ontology/opc.rdf` —— 三类实体：`Project`、`BankAccount`、`Task`
- `code/dataIQ/bindings/data-bindings.json` —— 主键和外键怎么映射
- `code/dataIQ/data/project.json` —— 项目的预算、状态、账户字段
- `code/dataIQ/queries/sample-queries.json` —— 挑一个问题，后面测智能体要用

### 打开 Copilot 并切到 Agent 模式

1. 按 <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>I</kbd>（Mac 是 <kbd>⌃</kbd>+<kbd>⌘</kbd>+<kbd>I</kbd>）打开 Copilot Chat
2. 在输入框**上方**的下拉框里，把模式从 `Ask` 切到 **`Agent`**
3. 试着问一句，确认能正常回答

> 切不到 Agent 模式 = 组织策略关闭了它。**现场解决不了**，改用 Claude Code / Cursor。

### 确认 MCP 服务器已注册

仓库里的 `.vscode/mcp.json` 已经把本体 MCP 服务器注册好了，容器里路径直接可用，
**你不需要改任何配置**。在 Copilot Chat 的工具列表里应该能看到 `opc-ontology`。

改完文件后再跑一次自检，确认没改坏：

```bash
cd /workspaces/*/code && python mcp/server.py --selftest
```

---

## 第 5 步 · Lab 03 · 两个智能体分工协作

这一步开始**需要 Azure OpenAI 凭证**，讲师会在课上发给你。

### 5.1 填凭证

在终端里跑：

```bash
bash .devcontainer/set-key.sh
```

脚本会依次问你三样东西，照着讲师发的填：

```text
Endpoint  [https://my-ai-foundry.services.ai.azure.com/]: ← 粘贴讲师发的地址
部署名     [gpt-5.5]:                                      ← 粘贴讲师发的部署名
API Key    (输入时不显示，回车=不改动，输 - 表示清空):        ← 粘贴 Key
```

> **方括号里是示例值，不是能用的配置。** 一路回车会被脚本拦下来，
> 因为那样填出来的是 `.env.example` 里的样例地址，Lab 03 会报一个
> 看起来像密钥错误、其实是地址错误的问题。三样都要照讲师发的填。

> **Key 输入时屏幕没反应是正常的**，不是卡住了，粘贴完直接回车。
> 这样做是为了不让 Key 留在命令历史里。写入的 `code/agents/.env` 已被 `.gitignore` 忽略，
> 不会跟着代码提交出去。

填完会打印一份回执，确认三行都对：

```text
  ✔ 已写入 code/agents/.env (权限 600，已被 .gitignore 忽略)
    Endpoint : https://...
    部署名   : ...
    API Key  : 已更新
```

最后脚本会问一句**可选**的邮件凭证（Lab 04 最后一步「发送结果到 Email」用的）。
讲师没发就一路回车跳过 —— 不影响问答和图表，只有发邮件那个按钮用不了。

### 5.2 跑通端到端

先读懂这两个文件（可以让 Copilot Agent 帮你讲解）：

- `code/agents/opc_agents/workflow.py` —— `AssistantAgent → DataAnalystAgent` 的顺序工作流
- `code/agents/api.py` —— 工作流怎么被包成 `POST /ask`

然后真正调用一次模型：

```bash
cd /workspaces/*/code/agents
python test_workflow.py --live "What is the total budget by project status? Draw a bar chart."
```

**期望**：打印出答案文字，以及一个图表文件路径。去 `code/agents/ontology_charts/`
里能看到新生成的 PNG，点开就能预览。

---

## 第 6 步 · Lab 04 · 做成 Copilot 应用

### 6.1 启动服务

```bash
cd /workspaces/*/code/agents
uvicorn api:app --port 8000
```

### 6.2 ⚠️ Codespaces 和讲义不一样的地方

讲义里写的是「打开 `http://127.0.0.1:8000/`」。**在 Codespaces 里这个地址打不开** ——
服务跑在云端容器里，不在你的电脑上。你要用**转发端口**：

**方法一（最快）**：服务起来后右下角会弹出提示
「你的应用程序在端口 8000 上运行」→ 点 **在浏览器中打开**。

**方法二**：点终端旁边的 **端口 / PORTS** 标签页 → 找到 8000 那一行 →
点「本地地址」列后面的地球图标 🌐。

打开的地址长这样：`https://<你的codespace名>-8000.app.github.dev`

> 网页里所有请求都用相对路径，所以**换成转发地址后一切照常工作**，不用改任何代码。

### 6.3 验证

在页面里输入：

```text
Which projects does the business account fund?
```

确认页面返回了答案。再点一个带图表的问题，确认图能显示出来。
然后展开「发送结果到 Email」，填一个收件邮箱试试。

> 停止服务：在终端按 <kbd>Ctrl</kbd>+<kbd>C</kbd>。

---

## 第 7 步 · Lab 05-1 · 部署到 Azure（资源受限路线）

### 7.1 放配置文件

讲师会发一个 `workshop-web.env`。把它放到 `code/cloud/scripts/` 下面 ——
最简单的办法是**直接把文件从电脑上拖进 VS Code 左侧的文件树**。

### 7.2 起个唯一的应用名

**每位学员必须不一样**，建议用「姓名缩写-web」，比如 `zhangsan-web`。
规则：3–32 个字符，只能用小写字母、数字和连字符，字母开头。

### 7.3 先预览，再部署

```bash
cd /workspaces/*/code/cloud/scripts
bash deploy-web-only.sh <你的应用名> --preview
```

确认没问题后正式部署（约 1–2 分钟）：

```bash
bash deploy-web-only.sh <你的应用名>
```

> 脚本会用讲师发的**服务主体**自动登录，密码是运行时隐藏输入的。
> **你不需要执行 `az login`。**

部署完会输出一个地址，打开它，把第 6 步的问题再问一遍，确认云上版本也能答。

> ### 走 Lab 05 完整版的同学看这里
> 完整版需要你自己的 Azure 订阅，得先登录。**Codespaces 里没有浏览器可以跳转，
> 必须加 `--use-device-code`**：
> ```bash
> az login --use-device-code
> ```
> 按提示打开显示的网址、输入显示的验证码即可。

---

## 课后

### 保存你的作业

你在讲师的仓库上没有写权限，但**不影响你保存**：在源代码管理面板里正常提交，
GitHub 会自动帮你 fork 一份到你自己名下，改动推到你的 fork 里。

也可以简单点：右键文件 → **下载**，把改过的文件存到本地。

### 停掉 Codespace（**重要，省额度**）

个人免费账号每月有 120 core-hours。这门课用 2 核机器跑 3 小时，
大约消耗 6 core-hours，额度很宽裕 —— 但**别让它一直开着**。

- 闲置 30 分钟会自动停止
- 想立刻停：回到 <https://github.com/codespaces> → 找到它 → 右侧 `...` → **Stop codespace**
- 确定不用了：同一个菜单里选 **Delete**（删了就找不回来了，先确认作业已保存）

> 停止 ≠ 删除。停止只是不再计算 core-hours，磁盘内容还在，下次打开接着用。

---

## 出问题怎么办

| 现象 | 原因 | 怎么办 |
|---|---|---|
| Codespace 创建后一直在装依赖 | 你 fork 了再开，没吃到预构建 | 关掉，回到讲师的仓库直接创建 |
| 终端提示符没有 `(.venv)` | 虚拟环境没自动激活 | `source /workspaces/*/code/.venv/bin/activate` |
| `ModuleNotFoundError: mcp` | 同上，环境没激活 | 同上 |
| 满屏 `IncompleteFieldDefinitionWarning` | **正常现象**，不是报错 | 不用管，检查照样通过 |
| `pip list \| wc -l` 不是 64 | 依赖没装全 | `bash .devcontainer/on-create.sh` 重装 |
| 浏览器打不开 `127.0.0.1:8000` | Codespaces 服务在云端 | 用端口转发，见第 6.2 步 |
| Copilot 切不到 Agent 模式 | 组织策略关闭 | 现场解决不了，改用 Claude Code / Cursor |
| Copilot 用着用着不响应了 | 免费额度耗尽 | 升级 Copilot Pro，或改用 Claude Code / Cursor |
| Lab 03 报缺少 Azure OpenAI 设置 | 凭证没填或填错 | 重跑 `bash .devcontainer/set-key.sh` |
| `deploy-web-only.sh` 说找不到配置 | `workshop-web.env` 没放对位置 | 必须在 `code/cloud/scripts/` 下 |
| Codespace 整个打不开 | 网络到不了 `*.app.github.dev` | 找讲师要离线安装包，改走本地路线 |

---

## 命令速查

```bash
pip list --format=freeze | wc -l                       # → 64
cd code && python mcp/server.py --selftest             # → {"active": 105000.0, ...}
cd code/agents && python test_workflow.py              # → All offline tests passed
bash .devcontainer/set-key.sh                          # 填 Azure OpenAI 凭证
cd code/agents && python test_workflow.py --live "..." # 端到端调模型
cd code/agents && uvicorn api:app --port 8000          # 起 Web 应用（用转发端口打开）
```

---

**相关文档**：[代码架构](../code/README.zh.md) · [中文 Lab 目录](../labs/cn/README.md) · [Lab 05-1 部署走查](deployment.md)
