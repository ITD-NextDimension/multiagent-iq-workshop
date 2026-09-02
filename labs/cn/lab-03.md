# Lab 03. 创建 Agents

## 故事

企业员工不应该为了获得答案而手工查看 JSON 或理解数据关联。AI 化转型团队创建一个 Agent 负责理解企业问题并检索受治理的知识，再由第二个 Agent 把数字结果转化为可用于决策的图表。团队使用 GitHub Copilot Coding Agent 辅助开发，并通过 Microsoft Agent Framework 编排两个 Agent。

## 架构

```text
用户问题
  |
  v
AssistantAgent
  |  通过 MCPStdioTool 查询 dataIQ 本体
  v
DataAnalystAgent
  |  通过 Monty CodeAct 调用 render_chart
  v
FastAPI 响应: answer + chart_url + transcript
```

两个 Agent 的职责：

| Agent | 职责 | 文件 |
|---|---|---|
| AssistantAgent | 使用 MCP 工具回答项目、账户、任务关系问题 | [code/agents/opc_agents/assistant_agent.py](../../code/agents/opc_agents/assistant_agent.py) |
| DataAnalystAgent | 把结果转成图表并保存 PNG | [code/agents/opc_agents/data_analyst_agent.py](../../code/agents/opc_agents/data_analyst_agent.py) |

## 实验步骤

1. 使用 GitHub Copilot Coding Agent 阅读 [code/agents/README.md](../../code/agents/README.md)，确认双 Agent 的目标和样例。
2. 查看 [code/agents/opc_agents/workflow.py](../../code/agents/opc_agents/workflow.py)，理解 `AssistantAgent → DataAnalystAgent` 的顺序工作流。
3. 查看 [code/agents/api.py](../../code/agents/api.py)，确认工作流已经封装成 `POST /ask` API。
4. 执行 `cd agents && python test_workflow.py --live "What is the total budget by project status? Draw a bar chart."`，验证端到端智能体回答。
5. 检查 [code/agents/ontology_charts](../../code/agents/ontology_charts)，确认 DataAnalystAgent 生成了图表文件。