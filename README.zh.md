# AKS Multi-Agent IQ Workshop

> English version: [README.md](README.md)

这个 Workshop 围绕一家企业的 **AI 化转型**展开。企业的项目、财务账户、预算和任务数据分散在不同系统中，员工和管理者缺少一个可信、统一的业务洞察入口。团队将构建 **AI Company**：一个了解企业情况的 Copilot 解决方案。它通过本体连接业务数据，通过 MCP 暴露受治理的知识能力，使用 Microsoft Agent Framework 多智能体完成查询与分析，并通过云端聊天界面提供答案、图表和邮件分享。

## 你将构建什么

完成 Workshop 后，你会得到一套端到端企业洞察 Copilot：

```text
AI Company 聊天应用
   |
   +--------------------+
   |                    |
   v                    v
FastAPI /ask       FastAPI /send-email
   |
   v
Microsoft Agent Framework 工作流
   |                         |
   v                         v
MCP 本体工具              图表生成
   |
   v
企业本体 + Project / BankAccount / Task 数据
   |
   v
基于 AKS、Container Apps、ACS Email、ACR、Log Analytics 的 Azure 部署
```

平台可以回答这些问题：

- 哪些账户正在支持企业战略项目？
- 按项目状态统计的总预算是多少？
- 哪些任务和依赖关系会影响项目交付？
- 将本次洞察和图表发送给指定业务负责人。

## Workshop Labs

Workshop 拆分为 5 个独立 Lab。每个 Lab 都包含故事、架构和不超过 5 步的动手实验。

| Lab | 主题 | 中文 | 英文 |
|---|---|---|---|
| 01 | 定义企业 AI 化转型解决方案 | [labs/cn/lab-01.md](labs/cn/lab-01.md) | [labs/en/lab-01.md](labs/en/lab-01.md) |
| 02 | 使用 dataIQ / Fabric IQ 概念构建数据架构 | [labs/cn/lab-02.md](labs/cn/lab-02.md) | [labs/en/lab-02.md](labs/en/lab-02.md) |
| 03 | 创建两个 Microsoft Agent Framework 智能体 | [labs/cn/lab-03.md](labs/cn/lab-03.md) | [labs/en/lab-03.md](labs/en/lab-03.md) |
| 04 | 生成并运行 Web 应用 | [labs/cn/lab-04.md](labs/cn/lab-04.md) | [labs/en/lab-04.md](labs/en/lab-04.md) |
| 05 | 云端结构与一键部署 | [labs/cn/lab-05.md](labs/cn/lab-05.md) | [labs/en/lab-05.md](labs/en/lab-05.md) |

Lab 目录：

- [中文 Lab 目录](labs/cn/README.md)
- [English lab index](labs/en/README.md)

## 仓库结构

| 路径 | 作用 |
|---|---|
| [code/dataIQ](code/dataIQ) | 企业本体、数据绑定、模拟数据和自然语言查询示例；现有样例文件名仍为 `opc.rdf`。 |
| [code/mcp](code/mcp) | 暴露本体和关系查询工具的 MCP 服务器。 |
| [code/agents](code/agents) | Microsoft Agent Framework 工作流、FastAPI API、图表输出和测试。 |
| [code/app](code/app) | Copilot 风格 HTML/CSS/JavaScript 聊天应用。 |
| [code/cloud](code/cloud) | Azure Bicep、Dockerfile、Kubernetes 清单和部署脚本。 |
| [labs/cn](labs/cn) | 中文 Workshop Lab。 |
| [labs/en](labs/en) | English workshop labs。 |

实现层说明见 [code/README.zh.md](code/README.zh.md)。

## 先决条件

- macOS、Linux 或 Windows WSL。
- Python 3.12，推荐使用 `conda` 环境 `agentdev`。
- Azure CLI，并已执行 `az login`。
- 用于 AKS 部署的 `kubectl`。
- Azure OpenAI 或 Azure AI Foundry 模型部署。
- 在目标 Azure 资源组中创建或更新资源的权限。

## 本地设置

```bash
cd code
conda activate agentdev
pip install -r mcp/requirements.txt
pip install -r agents/requirements.txt
cp agents/.env.example agents/.env
```

编辑 `code/agents/.env` 并设置：

```bash
AZURE_OPENAI_ENDPOINT=https://<resource>.openai.azure.com/
AZURE_OPENAI_MODEL=<deployment-name>
AZURE_OPENAI_API_VERSION=2024-10-21
```

如果本地使用无密钥认证，可保持 `AZURE_OPENAI_API_KEY` 为空，并依赖 `az login`。

## 本地运行

验证本体和 MCP 工具：

```bash
cd code
python mcp/server.py --selftest
```

运行智能体工作流检查：

```bash
cd code/agents
python test_workflow.py
python test_workflow.py --live "What is the total budget by project status? Draw a bar chart."
```

启动 API 和 Web 应用：

```bash
cd code/agents
uvicorn api:app --port 8000
```

打开 `http://127.0.0.1:8000/`，向 AI Company 询问企业项目、账户、预算或任务问题。

## 部署到 Azure

云端部署使用 [code/cloud](code/cloud) 完成以下资源的创建和发布：

- Azure Kubernetes Service，用于运行 agents API 工作负载。
- Azure Container Apps，用于运行 Web 应用和 HTTP MCP + dataIQ 服务。
- Azure Container Apps 动态会话池，用于隔离代码执行沙箱。
- Azure Container Registry，用于保存容器镜像。
- Log Analytics，用于可观测性。
- AKS Workload Identity，用于无密钥访问 Azure OpenAI / Foundry。
- Azure Communication Services Email 与 Azure 托管域，用于发送 Copilot 结果和图表。

执行一键部署：

```bash
cd code/cloud
bash scripts/deploy.sh
```

脚本会使用 ACR Tasks 构建 3 个容器镜像，部署包含 Azure Communication Services Email
的 Bicep 资源栈，发布 AKS 工作负载，把自动生成的发件配置写入 Kubernetes Secret，
等待 LoadBalancer IP，并把 Web App 指向 agents API。

> 执行部署会创建计费 Azure 资源。

清理 Workshop 资源：

```bash
cd code/cloud
bash scripts/teardown.sh
```

## 学习目标

完成 Workshop 后，你将理解如何：

- 使用 dataIQ / Fabric IQ 风格本体概念连接企业业务知识。
- 通过 MCP 工具暴露本体关系查询能力。
- 构建双智能体 Microsoft Agent Framework 工作流。
- 将工作流封装成 FastAPI 服务和适配手机的 AI Company 聊天应用。
- 使用 Azure Communication Services Email 分享答案和图表附件。
- 使用模块化 Bicep、AKS、Container Apps、ACS Email 和一键脚本把完整系统部署到 Azure。