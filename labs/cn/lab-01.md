# Lab 01. 定义企业 AI Copilot 解决方案

## 故事

企业 AI 化转型团队首先面对一个典型问题：项目交付、财务账户、预算和任务分散在不同系统中。员工提出一个简单问题，也需要人工跨系统核对。团队决定构建 **AI Company**，让 Copilot 理解相互关联的企业上下文，并把数据转化为有依据的答案、图表和后续操作。

## 架构

```text
AI Company 聊天应用
   |
   v
FastAPI /ask
   |
   v
Microsoft Agent Framework 工作流
   |                         |
   v                         v
MCP 本体查询服务          图表生成工具
   |
   v
dataIQ: Project / BankAccount / Task
```

平台分成 5 层：

| 层 | 作用 | 目录 |
|---|---|---|
| Copilot 入口 | 聊天式企业洞察与结果分享 | [code/app](../../code/app) |
| API | 对外封装 `/ask`、`/send-email`、`/health`、`/charts` | [code/agents/api.py](../../code/agents/api.py) |
| 智能体 | 理解问题、查询本体、生成分析 | [code/agents/opc_agents](../../code/agents/opc_agents) |
| 数据能力 | MCP 工具暴露本体和关系查询 | [code/mcp](../../code/mcp) |
| 业务数据 | 企业本体、绑定和模拟数据 | [code/dataIQ](../../code/dataIQ) |

## 实验步骤

1. 打开 [code/README.zh.md](../../code/README.zh.md)，理解企业 Copilot 的端到端架构。
2. 检查 [code/dataIQ/data](../../code/dataIQ/data)，确认企业的 `Project`、`BankAccount`、`Task` 数据。
3. 执行 `python mcp/server.py --selftest`，验证数据关系可以被 MCP 服务查询。
4. 执行 `cd agents && python test_workflow.py`，验证智能体工作流的离线能力。
5. 记录转型目标：先在本地跑通可信的企业洞察 Copilot，最后通过 [code/cloud/scripts/deploy.sh](../../code/cloud/scripts/deploy.sh) 部署到 Azure。