# AI Company — 企业本体 + Fabric IQ + 智能体

一个端到端企业 AI 化转型示例：把相互关联的业务知识变成可查询的**本体（Ontology）**层，
通过 **MCP 服务器**暴露受治理的知识能力，用 **Microsoft Agent Framework** 多智能体工作流
完成分析，并通过 **FastAPI 后端**和适配手机的 **AI Company** Copilot 提供答案、图表与邮件分享。

样例企业领域使用 3 个实体建模：`Project`、`BankAccount`、`Task`。现有本体文件名
`opc.rdf` 作为实现标识继续保留。

> 中文 README。English version: [README.md](README.md)。

## 架构

```text
   AI Company 浏览器/手机界面
      |  POST /ask                 POST /send-email
      v                                  |
+--------------------------------------------------------------+
|  app/  ·  AI Company 聊天应用（响应式 HTML5 + CSS3 + JS）       |
+--------------------------------------------------------------+
      |
      v
+--------------------------------------------------------------+
|  agents/api.py  ·  FastAPI                                    |
|  GET /  POST /ask  GET /charts/{name}  POST /send-email       |
+--------------------------------------------------------------+
      | run_pipeline()                         | ACS Email SDK
      v                                        v
+--------------------------------------------------------------+
|  agents/  ·  Microsoft Agent Framework  (SequentialBuilder)  |
|                                                              |
|   AssistantAgent  ------------->  DataAnalystAgent           |
|   (Azure OpenAI)                  (Monty CodeAct)            |
+--------|-----------------------------------|-----------------+
         | MCP (stdio)                        | render_chart (matplotlib)
         v                                    v
+----------------------------+   +-----------------------------+
|  mcp/  ·  MCP 服务器        |   |  agents/ontology_charts/    |
|  describe_ontology,         |   |  *.png（已保存图表）        |
|  get_related, aggregate ... |   +-----------------------------+
+--------|-------------------+
         | 解析
         v
+--------------------------------------------------------------+
|  dataIQ/  ·  本体 + 数据                                      |
|  opc.rdf  ·  data-bindings.json  ·  data/*.json              |
+--------------------------------------------------------------+
                                               |
                                               v
                              +---------------------------------+
                              | Azure Communication Services     |
                              | 邮件正文 + 可选图表附件          |
                              +---------------------------------+
```

**流程：** 用户提问命中 `POST /ask` → `SequentialBuilder` 工作流依次运行
`AssistantAgent`（通过 MCP 服务器查询本体）→ `DataAnalystAgent`（在 Monty CodeAct 沙箱里写 Python，
调用宿主工具 `render_chart` 生成 PNG）→ API 返回**文字回答 + 图表图片**。用户可选择
“发送结果到 Email”，后端通过 Azure Communication Services Email 发送正文和可选图表附件。

## 每个文件夹的内容

| 文件夹 | 内容 |
|---|---|
| [dataIQ/](dataIQ) | **本体与模拟数据**（Fabric IQ 概念）。`ontology/opc.rdf`（RDF/OWL 中的实体类型、属性、关系）、`ontology/metadata.json`、`bindings/data-bindings.json`（实体/关系 → OneLake 数据源映射）、`data/*.json`（Project、BankAccount、Task 实例）、`queries/sample-queries.json`（NL2Ontology 示例）。详见 [dataIQ/README.md](dataIQ/README.md)。 |
| [mcp/](mcp) | **Model Context Protocol 服务器**（`server.py`），解析本体 + 绑定 + 数据并暴露查询工具（`describe_ontology`、`list_instances`、`get_instance`、`get_related`、`aggregate`）。含 `requirements.txt`、`README.md`。详见 [mcp/README.md](mcp/README.md)。 |
| [agents/](agents) | **Microsoft Agent Framework 多智能体应用**。`opc_agents/`（配置、AssistantAgent + MCP、DataAnalystAgent + Monty CodeAct、SequentialBuilder 工作流）、`api.py`（FastAPI）、`test_workflow.py`（离线 + 在线测试）、`ontology_charts/`（生成的 PNG）、`.env` / `.env.example`。详见 [agents/README.md](agents/README.md)。 |
| [app/](app) | 适配手机的 **AI Company** 聊天应用（`index.html`、`styles.css`、`app.js`）。原生 HTML5/CSS3/JS，自适应 + 深色模式，调用 `/ask` 与 `/send-email` 并渲染答案和图表。 |
| [../.vscode/](../.vscode) | `mcp.json`——把 MCP 服务器接入 VS Code。 |
| [cloud/](cloud) | **Azure 部署（Bicep）**——一键配置 AKS、容器应用、会话池沙箱、带 Azure 托管域的 ACS Email、ACR 与 Log Analytics。详见 [cloud/README.md](cloud/README.md)。 |

## 先决条件

- 安装好依赖的 **conda** 环境 `agentdev`（Python 3.12）。
- 一个 **Azure OpenAI / Azure AI Foundry** 部署（供智能体与在线测试使用）。
- 若使用 `AzureCliCredential`（而非 API Key），需执行 `az login`。

## 安装

```bash
# 1. 激活环境
conda activate agentdev

# 2. 安装依赖
pip install -r mcp/requirements.txt
pip install -r agents/requirements.txt

# 3. 配置 Azure OpenAI
cp agents/.env.example agents/.env
# 编辑 agents/.env：
#   AZURE_OPENAI_ENDPOINT=https://<resource>.openai.azure.com/   (或 *.services.ai.azure.com/)
#   AZURE_OPENAI_MODEL=<部署名称>
#   AZURE_OPENAI_API_VERSION=2024-10-21
#   AZURE_OPENAI_API_KEY=...            # 或留空并执行 `az login`
```

## 执行步骤

### 1) 验证 MCP 服务器（无需 Azure）

```bash
python mcp/server.py --selftest
# 列出实体/关系，并对 dataIQ 运行示例查询。
```

### 2) 运行智能体测试

```bash
cd agents
python test_workflow.py            # 离线：图表渲染 + MCP 工具发现
python test_workflow.py --live "What is the total budget by project status? Draw a bar chart."
```

### 3) 启动 API + 聊天网页

```bash
cd agents
uvicorn api:app --port 8000
# 浏览器打开 http://127.0.0.1:8000/ 即可开始聊天。
```

聊天界面（由 `app/` 提供）把问题发送到 `POST /ask`，并渲染回答文字与生成的图表图片。

### 4)（可选）直接使用 MCP 服务器

- 在 **VS Code** 中：`.vscode/mcp.json` 已注册 `opc-ontology` 服务器。
- 在 **Claude Desktop** 或任意 MCP 客户端中：以 stdio 方式运行 `python mcp/server.py`。

## 云端部署（Azure）

[cloud/](cloud) 目录用 **Bicep** 把整个应用部署到 Azure（资源组 `rg-multiagent-iq`，
区域 `swedencentral`）。网页 UI 与 MCP+dataIQ 服务运行在 **Azure 容器应用（ACA）**上，
智能体运行在 **AKS** 上，另有一个 ACA **动态会话池**作为隔离的代码执行沙箱节点。


![arch](./imgs/Designer.png)

```text
                         +------------------------------------------+
   企业员工    ─────▶  |  ACA：AI Company (opciq-app) [nginx]    |
                         |  反向代理 /ask、/charts、/send-email       |
                         +---------------------┬--------------------+
                                               │  http://<AKS 外部 IP>
                                               ▼
                         +------------------------------------------+
                         |  AKS：aks-iq-aks-agent-hol               |
                         |  Deployment “opc-agents” (FastAPI)       |
                         |  Microsoft Agent Framework 工作流：      |
                         |   AssistantAgent + DataAnalystAgent      |
                         |   经工作负载身份用 Entra ID 鉴权 ──────┼──▶ Azure OpenAI
                         +----------┬--------------------┬----------+     (my-ai-foundry)
                                    │ stdio MCP          │ 代码执行卸载
                                    │ （内置）           ▼
                                    │        +--------------------------------+
                                    │        |  ACA 会话池（沙箱）            |
                                    │        |  opciqsandbox  (PythonLTS)     |
                                    │        +--------------------------------+
                                    ▼
                         +------------------------------------------+
                         |  ACA：MCP + dataIQ (opciq-mcp-dataiq)    |
                         |  HTTP MCP 服务 (streamable-http:8080)    |
                         +------------------------------------------+
                                    |
                                    +------------------------------▶ ACS Email
                                                                     答案 + 图表

   共享：Azure 容器注册表 (opciqacr…) + Log Analytics (opciq-logs)
```

| 组件 | Azure 服务 | 资源 |
|---|---|---|
| 聊天网页 UI | 容器应用（nginx） | `opciq-app` |
| 智能体（FastAPI 工作流） | **AKS** | `aks-iq-aks-agent-hol` / Deployment `opc-agents` |
| 沙箱节点（代码执行） | 容器应用**会话池** | `opciqsandbox`（PythonLTS） |
| HTTP 版 MCP + dataIQ | 容器应用 | `opciq-mcp-dataiq` |
| 镜像仓库 | 容器注册表 | `opciqacr…` |
| 监控 | Log Analytics | `opciq-logs` |
| 大模型 | Azure OpenAI / Foundry | `my-ai-foundry` |
| 邮件发送 | Azure Communication Services Email | `opciq-acs-*` + Azure 托管域 |

**鉴权（无密钥）：** AKS 上的智能体通过 AKS **工作负载身份（Workload
Identity）** 以 **Entra ID** 调用 Azure OpenAI（一个联合托管身份，在 Foundry 上被授予
*Cognitive Services OpenAI User* 角色）——云端**无需** `AZURE_OPENAI_API_KEY`。容器
应用则用注册表管理员凭据从 ACR 拉取镜像。

**邮件安全：** 部署脚本在运行时获取 ACS 连接字符串并写入 AKS 的
`opc-agents-secret`，浏览器不会获取 ACS 凭据。

**部署：**

```bash
cd cloud
bash scripts/deploy.sh      # 构建 3 个镜像，部署 Bicep，打通 AKS ↔ 网页应用
```

完整的分步说明与拆除流程见 [cloud/README.md](cloud/README.md)。

## 技术栈

- **本体**：RDF/OWL（Fabric IQ 本体概念）
- **MCP**：`mcp` Python SDK（FastMCP，stdio）
- **智能体**：Microsoft Agent Framework（`agent-framework`、`agent-framework-monty`、`SequentialBuilder`）
- **大模型**：Azure OpenAI / Azure AI Foundry，经 `OpenAIChatCompletionClient`
- **图表**：matplotlib（由 Monty CodeAct 沙箱调用的宿主工具）
- **API**：FastAPI + Uvicorn
- **前端**：HTML5 + CSS3 + 原生 JavaScript
