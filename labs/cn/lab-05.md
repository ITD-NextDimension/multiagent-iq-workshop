# Lab 05. 云端结构与一键部署

> **配额或时间不够？** 用 [Lab 05-1](lab-05-1.md) 替代本课：讲师预置共享的 AKS、ACR 和
> Container Apps 环境，学员只部署自己的 Web 前端，约 15 分钟，不需要 `kubectl`。

## 故事

AI Company 原型已经证明了业务价值，企业平台团队需要把它升级为可重复、可治理的云端服务。员工要能从电脑和手机访问，智能体需要无密钥调用模型，代码执行需要隔离，业务洞察还要能通过邮件分享给负责人。团队把完整架构写入 [code/cloud](../../code/cloud)，并使用一个脚本自动完成交付。

## 架构

```text
公网用户
  |
  v
Azure Container Apps: opciq-app
  |  反向代理 /ask、/charts 和 /send-email
  v
AKS: opc-agents FastAPI + Microsoft Agent Framework
  |\
  | \-> Azure Container Apps Session Pool: Python 沙箱
  |
  +-> Azure OpenAI / Foundry: Entra ID Workload Identity
  |
  +-> MCP + dataIQ: 本体查询
  |
  +-> Azure Communication Services Email
        |  关联 Azure 托管邮件域
        v
      业务负责人邮箱：答案 + 可选图表

共享能力: Azure Container Registry + Log Analytics
```

部署脚本 [code/cloud/scripts/deploy.sh](../../code/cloud/scripts/deploy.sh) 会完成 6 个阶段：
创建 ACR、用 ACR Tasks 构建 3 个不可变标签镜像、部署包含 ACS Email 与 Azure 托管域的
Bicep 资源栈、把自动生成的连接字符串和发件地址写入 AKS Secret、发布 AKS 工作负载、
等待公网 IP 并把 Web App 指向 API。

## 实验步骤

1. 打开 [code/cloud/README.md](../../code/cloud/README.md)，确认 AKS、Container Apps、ACR、Log Analytics、Workload Identity 和 Azure Communication Services Email 设计。
2. 检查 [code/cloud/main.bicep](../../code/cloud/main.bicep) 与 [code/cloud/modules/communicationEmail.bicep](../../code/cloud/modules/communicationEmail.bicep)，确认 Communication Service、Email Service、Azure 托管域及域关联均由 Bicep 描述。
3. 检查 [code/cloud/docker](../../code/cloud/docker) 与 [code/cloud/k8s](../../code/cloud/k8s)，确认三个镜像和 AKS 工作负载定义。
4. 在 [code/agents/.env](../../code/agents/.env.example) 配置 Azure OpenAI Endpoint、Model 和 API Version，然后执行 `cd code/cloud && bash scripts/deploy.sh`。ACS Email 会自动创建，凭据不需要写入 `.env`。
5. 使用脚本输出的 Web App URL 访问系统，提出企业问题并把结果发送到测试邮箱；不再需要环境时执行 `bash scripts/teardown.sh`。

## 部署提醒

- `deploy.sh` 会创建计费 Azure 资源。
- 云端智能体通过 AKS Workload Identity 使用 Entra ID 调用 Azure OpenAI，不需要在云端保存 `AZURE_OPENAI_API_KEY`。
- Workshop 使用 Azure 托管邮件域快速启用 ACS Email；生产环境应使用已验证的自定义域，并评估邮件发送配额。
- 部署脚本会把 ACS 连接字符串和发件地址写入 `opc-agents-secret`，浏览器不会接触邮件凭据。
- Bicep 采用模块化结构，敏感值应使用安全参数或运行时 Secret，不应硬编码在模板中。
- 如果 AKS LoadBalancer IP 暂时未分配，可稍后重新执行 `bash scripts/deploy.sh`，脚本会重新连线 Web App。