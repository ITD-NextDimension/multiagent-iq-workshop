# Lab 01 实操走查 · 定义企业 AI Copilot 解决方案

> 讲师用走查脚本。左边是**学员看到什么、做什么**，右边是**你在台上说什么**。
> 每个 📸 是建议的截图点，直接对应 PPT 的一页。
>
> 已在 macOS + Python 3.12.12 全程实跑验证通过。

**时长**：25–30 分钟 · **产出**：本地跑通本体查询与智能体离线测试，学员理解 5 层架构

---

## 这一课要让学员建立的认知

Lab 01 **不写代码**。它要解决的是一个认知问题：

> 为什么企业做 AI Copilot，第一步不是接大模型，而是先建本体？

学员在这一课要亲手看到的因果链：

```text
散落的 JSON 数据            →  大模型只能猜
   ↓ 加一层本体（谁funds谁、谁has_task谁）
可被机器遍历的关系图        →  大模型可以查
   ↓ 用 MCP 把查询能力标准化暴露
Copilot 直接拿到受治理的答案 →  有依据、可追溯
```

跑完 `--selftest` 那一刻，学员看到 `"funds"`、`"has_task"` 被真的遍历出来，这个认知就成立了。

---

## Step 0 · 开场：先让 Copilot 读懂这个仓库（5 分钟）

学员打开 VS Code，`⌃⌘I`（Windows `Ctrl+Alt+I`）打开 Copilot Chat，**切到 Agent 模式**。

> 🎤 讲师话术：「今天全程你不是一个人在写代码。先让 Copilot 把这个仓库读一遍，
> 它接下来才能当你的助教。注意我用的是 Agent 模式 —— 它能真的去读文件，不是凭印象编。」

**Copilot 提示词 ①**

```text
#codebase 这个仓库是做什么的？请按「数据 → 能力 → 智能体 → 应用 → 云」
五层给我一张表，每层写清楚：作用、对应目录、关键文件。
不要展开代码细节，我先要全貌。
```

Copilot 应该回答出这张表（**这是对答案，学员答不出说明 Agent 模式没开或没索引到**）：

| 层 | 作用 | 目录 |
|---|---|---|
| 业务数据 | 企业本体、绑定、模拟数据 | `code/dataIQ` |
| 数据能力 | MCP 工具暴露本体与关系查询 | `code/mcp` |
| 智能体 | 理解问题、查本体、生成分析 | `code/agents/opc_agents` |
| API | `/ask`、`/send-email`、`/health`、`/charts` | `code/agents/api.py` |
| Copilot 入口 | 聊天式洞察与结果分享 | `code/app` |

> 📸 **截图 1**：Copilot Chat 里这张五层表 + 左下角能看到 Agent 模式标识。
> 这张图在 PPT 里当「学习方式」的开篇 —— 说明这门课是**和 Copilot 一起学**，不是照着讲义抄命令。

**踩坑预警**（讲师提前说，能省 10 分钟答疑）：
- 切不到 Agent 模式 → GitHub 组织策略关掉了，现场解决不了，走 Claude Code / Cursor 备选路径。
- Copilot 答得很泛、没提到具体目录 → 少了 `#codebase`，让他重发一次。

---

## Step 1 · 环境初始化（5 分钟）

> 🎤 「一条一条粘，不要跳。第一条 `cd code` 最容易漏，漏了后面全错。」

```bash
cd code
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r mcp/requirements.txt
pip install -r agents/requirements.txt
cp agents/.env.example agents/.env
```

**正确结果**：最后一行 `Successfully installed ...`，`pip list` 数出来是 **64 个包**。

```bash
pip list --format=freeze | wc -l   # 期望 64
```

> 📸 **截图 2**：`Successfully installed` 那一屏 + `64`。
> PPT 用途：证明「版本锁定 = 每个人环境一模一样」，这是后面所有 lab 能同步推进的前提。

### 讲师必须解释的一件事：为什么依赖要锁死版本

`code/agents/requirements.txt` 里三个版本是**动不得**的，注释里也写了：

| 包 | 锁定原因 |
|---|---|
| `mcp==1.29.0` | 2.x 删掉了 `mcp.server.fastmcp`，`server.py` 直接 import 不到 |
| 四个 `agent-framework-*` 子包 | 装 `agent-framework` 元包会拉进 ~31 个可选集成，pip 解析器直接失败 |
| `pydantic-monty==0.0.16` | ≥0.0.17 改了 Monty 沙箱 API，Lab 03 的图表就画不出来 |

> 🎤 「这不是我保守。这三条每一条都是真踩出来的。你们课后自己升级可以，但今天别升。」

### 学员会卡的两个地方

**① `python3.12: command not found`** —— 装了 Python 但没进 PATH。
让 Copilot 帮他查：

```text
我在终端执行 python3.12 -m venv .venv 报 command not found，
但我确实装了 Python。帮我判断是哪种情况，并给出 macOS / Windows WSL 各自的修复命令。
```

**② 一堆 `IncompleteFieldDefinitionWarning`** —— **这是正常的**，不是报错。
`pydantic-settings` 对 `mcp` 里一个前向引用字段的警告，不影响任何功能。提前说，否则会有一半人举手。

---

## Step 2 · 看懂数据：企业到底长什么样（5 分钟）

先让学员自己看一眼原始数据：

```bash
ls code/dataIQ/data/          # project.json  bank_account.json  task.json
```

> 🎤 「就三个 JSON 文件，跟你公司导出来的报表没区别。散的。
> 现在的问题是：员工问『哪个账户在给哪些项目付钱』，光靠这三个文件，大模型答不了。」

**Copilot 提示词 ②**

```text
#codebase 读 code/dataIQ/ontology/opc.rdf 和 bindings/data-bindings.json，
用一段话 + 一张 ASCII 图告诉我：
1. 定义了哪几个实体、哪几个关系
2. 关系是靠哪个字段连起来的
3. 这一层比直接读 data/*.json 多解决了什么问题
```

对答案：

```text
BankAccount ──funds──▶ Project ──has_task──▶ Task
   ACC-001              PRJ-001               TSK-001/002/006
             (accountId)          (projectId)
```

多解决的问题：**关系被显式声明了**。`accountId` 在裸 JSON 里只是个字符串，
在本体里它是一条名为 `funds` 的、可被机器遍历的边。

> 📸 **截图 3**：Copilot 输出的这张实体关系图。
> PPT 用途：这是全课**理论上的核心一页** —— 「Fabric IQ / 本体到底解决什么」。

---

## Step 3 · 验证本体可被查询（5 分钟）⭐ 本课高光

```bash
cd code
source .venv/bin/activate
python mcp/server.py --selftest
```

跑出来是四段真实查询（实跑输出，可直接对照）：

```text
== describe_ontology ==
{"entities": ["Project", "BankAccount", "Task"], "relationships": ["funds", "has_task"]}

== get_related(BankAccount ACC-001) ==
  → PRJ-001  Mingrui Billing System Revamp   budget 60000
  → PRJ-002  Yuntu Data Dashboard            budget 45000

== get_related(Project PRJ-001, has_task) ==
  → TSK-001  Billing model design        done
  → TSK-002  Payment gateway integration doing
  → TSK-006  Regression testing          todo

== aggregate(Project budget sum group_by status) ==
{"result": {"active": 105000.0, "done": 25000.0}}
```

> 🎤 **这里停下来，用手指着屏幕讲**：
> 「看最后一行。`active: 105000`。没有人写过一行 SQL，没有人写过 join。
> 是本体告诉系统『Project 有 budget、有 status』，MCP 把它变成一个叫 aggregate 的工具，
> 大模型只要会调工具就行。**这就是企业 AI 的地基。**」

> 📸 **截图 4（最重要的一张）**：完整的 selftest 输出。
> PPT 用途：整个 workshop 的「Aha 时刻」页。建议做成动画，最后高亮 `active: 105000`。

### 加一个现场演示：让 Copilot 直接查企业数据

仓库里 `.vscode/mcp.json` 已经把这个 MCP 服务注册给 VS Code 了：

```json
{
  "servers": {
    "opc-ontology": {
      "type": "stdio",
      "command": "${workspaceFolder}/code/.venv/bin/python",
      "args": ["${workspaceFolder}/code/mcp/server.py"]
    }
  }
}
```

在 Copilot Chat 里点工具图标，勾上 `opc-ontology`，然后**用中文直接问业务问题**：

**Copilot 提示词 ③**

```text
用 opc-ontology 工具查一下：ACC-001 这个账户在给哪些项目付钱？
这些项目下面各有几个任务、分别什么状态？用表格给我。
```

> 🎤 「注意，我问的是**业务问题**，不是技术问题。它自己决定去调 `get_related`，调了两次。
> 这就是学员在 Lab 04 要做出来的东西 —— 只不过今天是 Copilot 当界面，那天是我们自己的 App。」

> 📸 **截图 5**：Copilot 调用 MCP 工具的过程（能看到工具调用记录）+ 最终表格。
> PPT 用途：「MCP = 让任意 AI 客户端都能安全访问企业数据」，一图胜千言。

**如果连不上**：VS Code 命令面板 → `MCP: List Servers` → 看 `opc-ontology` 状态和日志。
99% 是 `.venv` 没建在 `code/` 下面（建到仓库根目录了）。

---

## Step 4 · 验证智能体工作流（5 分钟）

```bash
cd code/agents
source ../.venv/bin/activate
python test_workflow.py
```

实跑输出：

```text
charts dir: .../code/agents/ontology_charts
[offline] render_chart OK -> .../ontology_charts/test_offline_bar.png
[offline] MCP tools OK -> ['aggregate', 'describe_ontology', 'get_instance',
                           'get_related', 'list_entity_types', 'list_instances']

All offline tests passed ✅
```

> 🎤 「`offline` 三个字很关键 —— **这一步不连 Azure，不花一分钱 token**。
> 它验证的是两个能力：能画图、能发现 MCP 的 6 个工具。
> 后面 Lab 03 接上大模型，就是让模型去用这 6 个工具。」

> 📸 **截图 6**：`All offline tests passed ✅`。
> PPT 用途：「离线可验证」是这套架构对企业最友好的地方 —— 学员/CI 都能在没有 Azure 的情况下自测。

顺手打开生成的图：

```bash
open code/agents/ontology_charts/test_offline_bar.png   # Windows WSL: explorer.exe .
```

### ⚠️ 讲师必读：这张图**不是**从本体查出来的

图上是 **105000 / 25000**，和 Step 3 的 `aggregate` 结果一模一样 —— 很容易让人以为
「数据自动变成了图」。**不是的。** `test_workflow.py` 第 34 行：

```python
values=[105000, 25000],   # 硬编码
```

作者刻意写成和真实数据一致，方便肉眼比对。实测验证过：把 `project.json` 里的 budget
改成 999999，`--selftest` 的 aggregate 会变成 `1044999`，但**这张图一点不变**。

> 🎤 正确讲法：「离线测试测的是**两个零件各自能不能用** —— 画图的能用，MCP 的 6 个工具
> 能被发现。它**没有**把两个零件接起来。谁来接？大模型。那是 Lab 03 的事。
> 所以你现在看到的是『地基验收』，不是『房子盖好了』。」

千万别讲成「零搬运/全自动」。台下只要有一个人翻开 `test_workflow.py`，你整场的可信度就没了。

> 📸 **截图 6b**：这张柱状图 + 旁边贴上 `values=[105000, 25000]` 那行源码。
> PPT 用途：这一页反而比"全自动"更有说服力 —— 「我们区分得清什么验证过、什么没验证过」。

---

## ⭐ 学员动手环节 · 让"过程"可见（8 分钟）

> 讲义原版的 Lab 01 只有"读文档 + 跑两条命令"，学员**只看到结果，看不到过程**。
> 下面两个练习是补上去的，都由**学员自己执行**，每个都靠"对照"把因果关系逼出来。

---

### 练习 A · 同一个问题问两遍（放在 Step 2 之后，5 分钟）

**第一遍 —— 不给本体，只给裸数据。** 让学员在 Copilot Chat 里**关掉** `opc-ontology` 工具，然后：

```text
#file:code/dataIQ/data/project.json
#file:code/dataIQ/data/bank_account.json
#file:code/dataIQ/data/task.json

ACC-001 这个账户在给哪些项目付钱？这些项目下面各有几个任务？
```

它能答对 —— 但**注意它是怎么答对的**：它得自己看出 `accountId` 是外键，自己在脑子里做 join。
让学员追问一句：

```text
你是怎么知道 accountId 能把这两个文件连起来的？这是你猜的还是文件里写了？
```

> 🎤 「记住它这个回答。**它是靠命名猜的。** 三个文件、字段名恰好一样，它猜对了。
> 你公司的系统里，同一个客户在 CRM 叫 `cust_id`、在财务叫 `KUNNR`、在工单系统叫 `customer`。
> 它还猜得对吗？猜错了你知道吗？」

**第二遍 —— 打开 `opc-ontology` 工具，问一模一样的话。**

这次它调 `get_related`，关系是**本体里声明的**，不是猜的。

> 📸 **截图 A**：两次回答并排。左边"猜的"，右边"查的"。
> PPT 用途：**这是全课最有说服力的一张图**，比任何架构图都管用。

---

### 练习 B · 改一个数字，看哪半截是活的（放在 Step 4 之后，3 分钟）

让学员**亲手改数据**，然后跑两条命令，观察两个不同的结果。

```bash
# 1. 把第一个项目的预算改成 999999
cd code
python3 -c "
import json,pathlib
p=pathlib.Path('dataIQ/data/project.json'); d=json.loads(p.read_text())
d[0]['budget']=999999.0
p.write_text(json.dumps(d,indent=2,ensure_ascii=False))
print('已改:', d[0]['name'], '->', d[0]['budget'])"

# 2. 本体查询——会变吗？
python mcp/server.py --selftest 2>/dev/null | tail -2

# 3. 离线图表——会变吗？
cd agents && python test_workflow.py 2>/dev/null | grep offline
open ontology_charts/test_offline_bar.png
```

**实测结果**（已验证）：

| 观察点 | 改之前 | 改之后 | 结论 |
|---|---|---|---|
| `aggregate` 的 active | 105000 | **1044999** | 本体链路**是活的** |
| 图上的柱子 | 105000 | **还是 105000** | 图表**没接上** |

> 🎤 「谁能解释一下？为什么一个变了一个没变？」
> 让学员自己翻 `test_workflow.py` 第 34 行，看到 `values=[105000, 25000]` 硬编码。
>
> 「对。**离线测试测的是两个零件各自能不能用，没测它们接没接上。**
> 谁负责接？大模型。它读 `aggregate` 的结果，自己决定调 `render_chart` 传什么数。
> 那是 Lab 03 干的事 —— 你们下一节课要亲手把这两半接起来。」

**务必让学员改回去**（否则后面所有 lab 的数字都对不上）：

```bash
cd ..                                    # 回到仓库根目录
git restore code/dataIQ/data/project.json
git status --short                       # 应该没有输出
```

> 📸 **截图 B**：上面那张"变 / 没变"对照表 + `values=[105000, 25000]` 源码行。
> PPT 用途：Lab 03 的**钩子**。学员带着"这两半怎么接"的问题进下一节课，注意力完全不一样。

---

### 哪些**不要**让学员执行

时间有限，把动手机会花在刀刃上。这两项建议讲师演示、学员课后自己试：

| 环节 | 为什么不让学员做 |
|---|---|
| VS Code 里注册 MCP（截图 5） | 学员环境差异最大的一环。20 人里必有几个连不上，现场排障能吃掉 15 分钟，而收益只是"看到工具列表"。讲师投屏演示，效果一样。 |
| `test_workflow.py --live` | 要 Azure OpenAI 配额和 `az login`。Lab 01 阶段不是每个人都配好了，失败率高且和本课主题无关。 |

---

## Step 5 · 收口：把目标写下来（3 分钟）

> 🎤 「最后花两分钟，每个人在自己的 README 里写一句话：
> **『我要让 ______ 岗位的同事，不用问人就能知道 ______ 。』**
> 填上你自己公司的场景。后面四个 Lab，你都拿这句话对照着做。」

然后把路线图给他们：

| Lab | 学员会得到 | 今天已经具备的基础 |
|---|---|---|
| 02 | 会改本体、加实体 | ✅ 已看懂 `opc.rdf` 和 bindings |
| 03 | 两个智能体真的跑起来 | ✅ 已验证 6 个 MCP 工具可被发现 |
| 04 | 手机可用的 Copilot App | ✅ 已见过 Copilot 调 MCP 的样子 |
| 05 | 一键部署到 Azure | ✅ 已理解本地 → 云的对应关系 |

> 📸 **截图 7**：这张路线图表。PPT 收尾页。

---

## 讲师检查清单（下课前逐个确认）

每个学员都要能给出这三条，缺一条就是没跟上：

- [ ] `pip list --format=freeze | wc -l` → **64**
- [ ] `python mcp/server.py --selftest` → 最后一行有 `{"active": 105000.0, "done": 25000.0}`
- [ ] `python test_workflow.py` → `All offline tests passed ✅`

---

## 截图清单速查（做 PPT 时对着这张表拍）

| # | 内容 | PPT 里的作用 |
|---|---|---|
| 1 | Copilot Chat 五层架构表 + Agent 模式 | 学习方式：和 Copilot 一起学 |
| 2 | `Successfully installed` + `64` | 环境可复现 |
| 3 | Copilot 画的实体关系图 | **本体是什么**（理论核心页） |
| 4 | `--selftest` 完整输出 | **Aha 时刻**（全课最重要） |
| 5 | Copilot 调 MCP 工具查业务问题 | MCP 的价值 |
| 6 | `All offline tests passed ✅` | 离线可验证 |
| 6b | 柱状图 + `values=[105000, 25000]` 源码 | 诚实划清验证边界 |
| **A** | **Copilot 两次回答并排（猜 vs 查）** | **全课最有说服力的一张** |
| **B** | **"变 / 没变"对照表** | **Lab 03 的钩子** |
| 7 | 五个 Lab 路线图 | 收尾 / 预告 |

> 截图 A 和 B 来自「学员动手环节」，是原讲义没有的。如果 PPT 只能留一张，留 A。
