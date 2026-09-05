# Copilot 指令 · 企业 AI 化转型 Lab

这是一个**教学仓库**，不是生产项目。使用者是 workshop 学员，多数是第一次接触本体（Ontology）
和 MCP。回答请优先解释**为什么**，再给命令；学员用中文提问就用中文回答。

## 这个项目是什么

`AI Company` —— 一个端到端的企业 Copilot 示例：把散落的业务数据变成可查询的**本体层**，
通过 **MCP 服务器**暴露受治理的查询能力，用 **Microsoft Agent Framework** 的双智能体工作流
生成分析和图表，再通过 FastAPI + 网页应用交付，最后一键部署到 Azure。

样例领域只有三个实体：`Project`、`BankAccount`、`Task`，两条关系：`funds`、`has_task`。

## 五层架构

| 层 | 目录 | 关键文件 |
|---|---|---|
| 业务数据 | `code/dataIQ` | `ontology/opc.rdf`、`bindings/data-bindings.json`、`data/*.json` |
| 数据能力 | `code/mcp` | `server.py`（FastMCP，stdio，6 个工具） |
| 智能体 | `code/agents/opc_agents` | `workflow.py`（`SequentialBuilder`）、`assistant_agent.py`、`data_analyst_agent.py` |
| API | `code/agents/api.py` | `GET /health`、`POST /ask`、`POST /send-email`、`GET /charts/{name}` |
| Copilot 入口 | `code/app` | 原生 HTML/CSS/JS 聊天应用 |
| 云端部署 | `code/cloud` | Bicep + `scripts/deploy.sh`（AKS + ACA + ACR + ACS Email） |

**主链路**：`POST /ask` → `run_pipeline()` → `AssistantAgent`（经 MCP 查本体）
→ `DataAnalystAgent`（在 Monty CodeAct 沙箱里写 Python，调用宿主工具 `render_chart`）
→ 返回文字答案 + PNG 图表。

## 命名：`opc` 是历史标识，不要改

代码里大量出现 `opc`（`opc.rdf`、`opc_agents/`、`opc-ontology`、k8s 的 `opc-iq`/`opc-agents`）。
它是早期 "one-person company" 的遗留标识，**作为实现标识保留**。

- **面向用户的文案**一律用「AI Company」/「企业」，不要出现 "OPC"、"one-person company"。
- **不要**主动重命名这些标识符、目录或 k8s 资源名 —— 会连带改动 Bicep、Dockerfile 和部署脚本。

## 依赖版本已锁死，不要建议升级

`code/agents/requirements.txt` 里三个版本是踩出来的，升级会直接弄坏课程：

| 包 | 锁定原因 |
|---|---|
| `mcp==1.29.0` | 2.x 移除了 `mcp.server.fastmcp`，`code/mcp/server.py` 依赖它 |
| 四个 `agent-framework-*` 子包 | 装 `agent-framework` 元包会拉进约 31 个可选集成，pip 解析失败 |
| `pydantic-monty==0.0.16` | ≥0.0.17 改了 Monty 沙箱 API，`DataAnalystAgent` 画不出图 |

学员问「能不能升级 xxx」时，先说明后果，再让他自己决定。

## 环境与常用命令

虚拟环境**必须建在 `code/` 下**（`.vscode/mcp.json` 按这个路径找解释器）：

```bash
cd code
python3.12 -m venv .venv          # Python 3.10–3.12，推荐 3.12；3.13 未验证
source .venv/bin/activate
pip install -r mcp/requirements.txt
pip install -r agents/requirements.txt
cp agents/.env.example agents/.env
```

装完是 **64 个包**。验证：

```bash
python mcp/server.py --selftest            # 本体查询，不需要 Azure
cd agents && python test_workflow.py       # 离线：图表 + MCP 工具发现
cd agents && uvicorn api:app --port 8000   # 打开 http://127.0.0.1:8000/
```

`test_workflow.py --live "..."` 和 `uvicorn` 需要 `agents/.env` 里配好 Azure OpenAI。

## 三个已知现象，不要当成 bug

1. **`IncompleteFieldDefinitionWarning`** —— `pydantic-settings` 对 `mcp` 内部一个前向引用
   字段的警告，**完全正常**，不影响功能。不要建议学员去 `model_rebuild()`。
2. **在 `code/` 目录下 `import mcp` 会拿到本地目录** —— `code/mcp/` 会被当成命名空间包，
   遮蔽 PyPI 的 `mcp`。用 `python mcp/server.py`（脚本路径）不受影响；写诊断脚本时
   要先 `cd` 出去，不要用 `find_spec('mcp')` 判断安装成功。
3. **matplotlib 不能在 Monty 沙箱里跑** —— 它是 C 扩展。沙箱里的代码通过宿主工具
   `render_chart` 出图，这是刻意设计，不是绕路。

## 回答时请注意

- **给命令要带 `cd`**。学员最常见的错误就是在错的目录下执行。
- **不要编造 Azure 资源名、订阅 ID、邮箱域名**。仓库里是占位符（如
  `<azure-managed-domain>`），保持占位符原样。
- **不要把密钥写进任何文件**。`agents/.env` 已被 gitignore；本地可留空
  `AZURE_OPENAI_API_KEY` 并依赖 `az login`。
- **改本体时三个文件要同步**：`ontology/opc.rdf`（类型与关系）、
  `bindings/data-bindings.json`（映射）、`data/*.json`（实例）。
  只加 RDF、不加 binding 时**不会报错**：`list_instances` 返回
  `{"count": 0, "instances": []}` 且 `isError=false`。这是 Lab 02 最常见的坑。
  最快的诊断是 `list_entity_types` —— 新实体会以 `"instanceCount": 0` 出现，
  说明 RDF 加对了、binding 漏了。
- **`owl:Class` 的 `rdf:about` 必须写完整 URI**（`http://example.org/ontology/opc/Xxx`）。
  写成 `#Xxx` 不会报错，但实体名会变成 `#Xxx`，后续所有查询都对不上。
- 学员在做 Lab 时，**先问他想达成什么**，不要直接把整段代码贴给他 —— 这门课的目的是理解。
