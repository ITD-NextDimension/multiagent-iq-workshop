# Lab 05-1 部署走查：共享平台上的 Web Container App

> 本文记录本 Workshop 的资源受限部署路径。它是 [Lab 05-1](../labs/cn/lab-05-1.md) 的实操指南，只部署学员自己的 Web 前端；不要与完整 Lab 05 同时执行。

## 目标与边界

本实验让每位学员发布一个自己的 Azure Container App。该应用托管 AI Company 网页，并由 nginx 将请求代理给讲师维护的共享 Agent API：

```text
浏览器
  -> 学员自己的 HTTPS Container App
  -> nginx: /ask, /charts, /send-email
  -> 共享 AKS Agent API
  -> Azure OpenAI, MCP + dataIQ, 图表与 ACS Email
```

本实验只创建或更新一个 Container App。它不会创建或管理 AKS、ACR、Azure OpenAI、MCP、Session Pool、ACS Email、Kubernetes Secret 或角色授权。

这样设计的原因是：重资源由讲师统一预置和维护，学员仍能学习 Container Apps、HTTPS 入口、托管身份拉镜像，以及前端反向代理的完整交付路径，同时避免课堂中的配额、成本和等待问题。

## 部署前检查

### 1. 进入正确目录

所有 Web-only 部署命令都从脚本目录运行：

```bash
cd /Users/<your-user>/.../IQs/code/cloud/scripts
```

不要在 `code/` 目录下继续执行 `cd code/cloud/scripts`。这会尝试进入不存在的 `code/code/cloud/scripts`。

### 2. 获取讲师配置

讲师应提供已填写的 `workshop-web.env`，把它放到：

```text
code/cloud/scripts/workshop-web.env
```

先检查正式文件和模板都存在：

```bash
ls -la workshop-web.env workshop-web.env.example
```

`workshop-web.env` 需要以下共享资源标识：

```dotenv
AZURE_SUBSCRIPTION_ID="<subscription-id>"
AZURE_TENANT_ID="<tenant-id>"
AZURE_CLIENT_ID="<workshop-service-principal-client-id>"
AZURE_RESOURCE_GROUP="<resource-group>"
ACA_ENV_NAME="<container-apps-environment>"
ACR_LOGIN_SERVER="<registry>.azurecr.io"
WEB_IMAGE_TAG=workshop
REGISTRY_IDENTITY_NAME="<managed-identity-name>"
AGENTS_BACKEND_URL="http://<shared-aks-external-ip>"
```

这个文件不应包含以下内容：

- `AZURE_OPENAI_API_KEY`
- `AZURE_COMMUNICATION_SERVICE_CONNECTION_STRING`
- Azure 服务主体的客户端密码

Lab 05-1 的 Web App 不使用模型 Key 或 ACS 连接字符串；这些秘密只应由共享后端管理。若任何 Key 或连接字符串被贴到聊天、文档、终端历史或公开频道，应立即由资源管理员撤销并重新生成。

### 3. 理解 `az` 与 `azd` 登录并不相同

`deploy-web-only.sh` 调用的是 Azure CLI，即 `az`，而不是 Azure Developer CLI，即 `azd`。因此：

```text
azd auth login 成功，不代表 az 已登录。
```

脚本会优先检查当前 `az` 是否已经位于讲师配置的订阅；若不在目标订阅，它会以交互方式要求输入讲师提供的服务主体客户端密码。密码输入不显示字符，这是预期行为。

可以用以下命令确认当前 `az` 的上下文，不会显示客户端密码：

```bash
az account show \
  --query "{subscription:id,tenant:tenantId,user:user.name,type:user.type}" \
  -o json

az account list --all \
  --query "[].{subscription:name,id:id,tenant:tenantId,state:state}" \
  -o table
```

验收条件：当前订阅 ID 等于 `workshop-web.env` 的 `AZURE_SUBSCRIPTION_ID`，且状态为 `Enabled`。

## 选择应用名

每位学员必须选择资源组内唯一的应用名。推荐格式：

```text
姓名缩写-web
```

例如 `tw-web`、`stu078-web`。

脚本的规则如下：

- 长度为 3 到 32 个字符。
- 只允许小写字母、数字和连字符 `-`。
- 必须以字母开头。
- 必须以字母或数字结尾。

`Tarry-Web`、`tarry_web`、`-tarry`、`tarry-` 均不合规。

## 先执行预览

部署前必须先运行 Azure `what-if` 预览。它会验证登录、订阅、资源组、共享 ACA 环境和托管身份，但不会创建或修改资源：

```bash
bash deploy-web-only.sh <your-app-name> --preview
```

成功时应看到以下阶段：

```text
已登录目标订阅，跳过
资源组 <resource-group> 可访问
Container Apps 环境 <aca-environment>
拉取身份 <managed-identity>
预览（what-if）—— 不会改动任何资源
```

如果脚本提示输入 `Client secret`，粘贴讲师提供的服务主体密码后按 Enter。不要把密码写入 `workshop-web.env`、命令行参数或截图。

## 正式部署

预览通过后，去掉 `--preview`：

```bash
bash deploy-web-only.sh <your-app-name>
```

脚本会以 Bicep 模板 [web-only.bicep](../code/cloud/web-only.bicep) 创建或原地更新一个 Container App，并完成以下配置：

- 用讲师预构建的 `opc-app:<tag>` 镜像创建 Web App。
- 使用共享的用户分配托管身份从 ACR 拉取镜像，身份已由讲师授予 `AcrPull`。
- 开启公网 HTTPS ingress，目标端口为 `80`。
- 设置 `AGENTS_BACKEND_URL`，供 nginx 将 `/ask`、`/charts` 和 `/send-email` 转发到共享 AKS API。
- 将扩缩容边界固定为 `minReplicas: 0`、`maxReplicas: 1`。

部署结束时，脚本会打印应用 HTTPS 地址。请记录这个地址，但不要记录或分享任何服务主体密码、模型 Key、ACS 连接字符串或 Kubernetes Secret。

## 验收部署

### 1. 查询应用状态和域名

```bash
az containerapp show \
  -g <resource-group> \
  -n <your-app-name> \
  --query "{name:name,state:properties.provisioningState,fqdn:properties.configuration.ingress.fqdn,scale:properties.template.scale,image:properties.template.containers[0].image}" \
  -o json
```

预期关键字段：

```json
{
  "state": "Succeeded",
  "scale": {
    "minReplicas": 0,
    "maxReplicas": 1
  },
  "image": "<registry>.azurecr.io/opc-app:workshop"
}
```

本次实操验证已得到 `Succeeded` 状态，并确认镜像为讲师预构建的 `opc-app:workshop`、扩缩容边界为 `0` 到 `1`。

### 2. 在浏览器中验证业务路径

打开：

```text
https://<your-container-app-fqdn>/
```

依次提问：

```text
ACC-001 这个账户在给哪些项目付钱？
```

```text
按项目状态汇总总预算，并画一张柱状图。
```

确认以下结果：

- 浏览器地址栏始终是自己的 Container App HTTPS 域名，而不是共享 AKS IP。
- 第一个问题获得来自共享 Agent API 的文字答案。
- 第二个问题返回文字答案和图表。
- 邮件按钮可以出现；邮件实际送达依赖讲师维护的共享 ACS Email 配置。

首次访问可能需要几十秒，因为 `minReplicas=0` 会在空闲时缩容至零。这是 Container Apps 的冷启动，不是部署故障；稍等后刷新即可。

## 常见问题与处理

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `cd: no such file or directory: code/...` | 已经位于 `code/` 或子目录，却再次写了 `cd code/...` | 先用 `pwd` 确认当前位置，再使用相对路径或本文给出的完整路径。 |
| `azd auth login` 成功但脚本仍要求登录 | 脚本使用 `az`，而不是 `azd` | 让脚本使用讲师服务主体登录，或用 `az account show` 确认当前 Azure CLI 上下文。 |
| `无法切换到订阅 ...` | `AZURE_SUBSCRIPTION_ID` 可能配置错误，或服务主体没有目标订阅访问权 | 对比 `az account list --all` 与配置文件。若目标订阅不可见，请讲师检查服务主体的资源组级 `Contributor` 授权。 |
| `看不到资源组` 或 HTTP 403 | 服务主体未被授权访问共享资源组，或订阅选错 | 不要切换到个人账号或自行修改 RBAC，联系讲师修复共享服务主体权限。 |
| 缺少 `ACA_ENV_NAME`、`ACR_LOGIN_SERVER` 等 | 使用了模板文件，或正式配置未填写 | 向讲师索取完整的 `workshop-web.env`；不要从本地 `agents/.env` 拼凑。 |
| 应用名不合规或名称已存在 | 名称格式不符合约束，或与其他学员重复 | 使用新的唯一小写名称，例如 `姓名缩写-web`。 |
| 共享资源预检失败 | ACA 环境、托管身份或共享 API 出现问题 | 不要修改脚本或删除资源，联系讲师恢复共享资源。 |
| 首次打开页面很慢 | `minReplicas=0` 触发冷启动 | 等待几十秒，刷新同一 HTTPS 地址。 |

## 安全与清理

- `workshop-web.env` 应被 Git 忽略；只存放共享资源标识，不存放客户端密码或服务 Key。
- 学员应用通过托管身份拉取镜像，避免使用 ACR 管理员用户名和密码。
- 学员不应获得 Azure OpenAI Key、ACS connection string 或 Kubernetes Secret。
- 不要在共享资源组执行删除命令。课后由讲师按应用名统一清理学员的 Web App。

## 完成标准

完成本实验时，应当能够说明：

1. 为什么只部署 Web App 仍能提供完整的 AI Company 体验。
2. 为什么 `az` 与 `azd` 的认证状态不能混用。
3. Bicep 如何复用共享 ACA 环境、ACR 和托管身份，同时只创建一个 Container App。
4. nginx 如何让浏览器通过自己的 HTTPS URL 使用共享 Agent API。
5. 为什么 `minReplicas=0` 会导致第一次请求变慢。
6. 为什么模型、邮件和 Kubernetes 凭据不应被放入学员前端或共享配置文件。
