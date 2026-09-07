# Workshop 运行记录 · 2026-09-07

> 本文只记录本轮实际执行并取得输出的验证。没有执行的 live 模型调用、浏览器交互或邮件发送不会标记为通过。

## Lab 01 · 本体与数据查询

执行：

```bash
cd /workspaces/multiagent-iq-workshop/code
source .venv/bin/activate
python mcp/server.py --selftest
```

结果：通过。MCP 服务正确识别 `Project`、`BankAccount`、`Task` 三个实体和 `funds`、`has_task` 两个关系；`ACC-001` 可关联两个项目，`PRJ-001` 可关联三个任务。

预算汇总验收结果为：

```json
{"entityType": "Project", "op": "sum", "field": "budget", "groupBy": "status", "result": {"active": 105000.0, "done": 25000.0}}
```

运行时出现的 `IncompleteFieldDefinitionWarning` 来自 MCP 依赖的 `pydantic-settings`，属于本仓库已知正常警告，不影响结果。

## Lab 02 · 本体能力与 MCP 工具

使用 Lab 01 的 `--selftest` 重新验证了本体、绑定和 JSON 实例数据协同工作正常。离线工作流测试也通过：

```bash
cd /workspaces/multiagent-iq-workshop/code/agents
source ../.venv/bin/activate
python test_workflow.py
```

结果：通过。测试成功生成 `ontology_charts/test_offline_bar.png`，并发现 6 个工具：`aggregate`、`describe_ontology`、`get_instance`、`get_related`、`list_entity_types`、`list_instances`。

## Lab 03 · 双智能体工作流

已验证不需要 Azure OpenAI 凭据的离线路径：`test_workflow.py` 输出 `All offline tests passed`，图表渲染与 MCP 工具发现正常。

本轮没有执行 `python test_workflow.py --live "..."`，因此尚未验证真实 Azure OpenAI 调用、文字回答和 live 图表生成。完成此验收前，需要在 `code/agents/.env` 配置讲师提供的 Azure OpenAI 信息；不要将 Key 写入本文或提交到 Git。

## Lab 04 · FastAPI 与网页应用

本轮未启动 `uvicorn api:app --port 8000`，也没有完成浏览器问答、图表显示或邮件发送测试。因此该 Lab 的网页端到端验收仍待执行。

建议验收命令：

```bash
cd /workspaces/multiagent-iq-workshop/code/agents
source ../.venv/bin/activate
uvicorn api:app --port 8000
```

在 Codespaces 中，应从 **PORTS** 面板打开转发的 8000 端口，而不是在本机访问 `127.0.0.1`。详见 [Codespaces 操作手册](codespaces.md)。

## Lab 05-1 · 仅部署 Web Container App

本轮验证了共享 Azure 资源和已部署的应用 `iq-ask-ocp`：

- 资源组 `rg-hol-demo` 可访问。
- 共享 Container Apps 环境 `aca-hol` 存在，预配状态为 `Succeeded`。
- 共享拉取身份 `iq-ask-agents-identity` 存在，其 client ID 与讲师提供的标识一致。
- `bash deploy-web-only.sh iq-ask-ocp --preview` 成功完成预检和 Azure what-if；该应用已存在，正式部署会更新它。
- 应用状态为 `Succeeded`，镜像为 `holacr9fa48e1aabb8.azurecr.io/opc-app:workshop`，扩缩容范围为 `minReplicas=0`、`maxReplicas=1`。
- HTTPS 域名为 `https://iq-ask-ocp.politeisland-b890c856.swedencentral.azurecontainerapps.io`。

### 解决的问题

原 [Web-only 部署脚本](../code/cloud/scripts/deploy-web-only.sh) 用 `az containerapp env show` 预检共享环境。当前开发容器的 Azure CLI 使用系统 Python，而系统 Python 缺少 `pip`，因此可选的 `containerapp` 扩展无法安装；脚本把这个本地 CLI 问题误报为共享环境不可用。

脚本现改用 Azure Resource Manager 内建的 `az resource show` 验证 `Microsoft.App/managedEnvironments`，不再依赖该可选扩展。`bash -n code/cloud/scripts/deploy-web-only.sh` 和 `--preview` 均已通过。

如需恢复 `az containerapp` 命令，系统管理员需安装系统 `pip` 后再安装扩展：

```bash
sudo apt update
sudo apt install -y python3-pip
az extension add --name containerapp --upgrade
```

没有管理员权限时，可通过 ARM 查询应用域名：

```bash
az resource show \
  --resource-group rg-hol-demo \
  --resource-type Microsoft.App/containerApps \
  --name iq-ask-ocp \
  --query properties.configuration.ingress.fqdn \
  --output tsv
```

## 结论

本轮已通过 Lab 01、Lab 02 的离线验证，以及 Lab 03 的离线工作流验证；Lab 05-1 的部署预检和已有 Web App 状态验证通过。Lab 03 的真实模型调用与 Lab 04 的网页端到端测试仍需在配置了讲师 Azure OpenAI 信息后完成。