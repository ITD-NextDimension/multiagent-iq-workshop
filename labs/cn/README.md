# 企业 AI 化转型 Lab

一家企业正在启动 AI 化转型。项目、财务账户、预算和任务数据分散在不同系统中，员工与管理者难以快速了解企业经营和交付情况。团队希望构建 **AI Company**：一个了解企业情况的 Copilot 解决方案，先用本体连接业务知识，再让智能体理解数据关系、生成分析和图表，最后部署到云端并把结果分享给业务负责人。

## Lab 目录

| 实验 | 主题 | 文件 | 对应目录 |
|---|---|---|---|
| 01 | 定义企业 AI Copilot 解决方案 | [lab-01.md](lab-01.md) | [code/README.zh.md](../../code/README.zh.md) |
| 02 | 数据架构 | [lab-02.md](lab-02.md) | [code/dataIQ](../../code/dataIQ) |
| 03 | 创建 Agents | [lab-03.md](lab-03.md) | [code/agents](../../code/agents) |
| 04 | 生成应用 app | [lab-04.md](lab-04.md) | [code/app](../../code/app) |
| 05 | 云端结构与一键部署 | [lab-05.md](lab-05.md) | [code/cloud](../../code/cloud) |
| 05-1 | *（替代）* 资源受限版：只部署 Web 应用 | [lab-05-1.md](lab-05-1.md) | [code/cloud](../../code/cloud) |

## 基本环境

- macOS、Linux 或 Windows WSL。
- Python 3.10–3.12（推荐 3.12；3.13 未验证）。
- Azure CLI，并已执行 `az login`。
- `kubectl`。
- Azure OpenAI 或 Azure AI Foundry 模型部署。
- 可访问本仓库根目录：`multiagent-iq-workshop`。

本地初始化：

```bash
cd code
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r mcp/requirements.txt
pip install -r agents/requirements.txt
cp agents/.env.example agents/.env
```

编辑 [code/agents/.env](../../code/agents/.env.example)，至少设置：

```bash
AZURE_OPENAI_ENDPOINT=https://<resource>.openai.azure.com/
AZURE_OPENAI_MODEL=<deployment-name>
AZURE_OPENAI_API_VERSION=2024-10-21
```

如果本地不用 API Key，可保持 `AZURE_OPENAI_API_KEY` 为空，并依赖 `az login`。

## 完成标准

完成 5 个 Lab 后，企业的 AI Company 解决方案应具备：

- 一个围绕企业项目、账户、预算和任务的 AI 化转型故事线。
- 一个可被 MCP 查询的 dataIQ/Fabric IQ 风格数据架构。
- 两个由 Microsoft Agent Framework 编排的智能体。
- 一个适配手机的 AI Company Copilot 应用。
- 一套通过 Azure Communication Services 分享答案和图表的邮件能力。
- 一套基于 Bicep、AKS、Container Apps、ACS Email、ACR 和 Log Analytics 的一键云端部署方式。