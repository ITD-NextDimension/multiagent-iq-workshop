#!/usr/bin/env bash
# =============================================================================
# Lab 05-1 · 资源受限路线：只部署学员自己的 Web Container App
#
#   bash deploy-web-only.sh <你的应用名>
#   bash deploy-web-only.sh <你的应用名> --preview   # 只看会改什么，不实际部署
#
# 与 deploy.sh 的区别：deploy.sh 建一整套云环境（AKS、ACR、会话池、ACS）；
# 这个脚本只建一个 Container App，其余全部复用讲师预置的共享资源。
# 学员不需要 kubectl，也不接触任何模型 Key 或 Kubernetes Secret。
#
# 共享资源的地址写在 workshop-web.env 里，由讲师课前发放。
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLOUD_DIR="$(dirname "$HERE")"
TEMPLATE="$CLOUD_DIR/web-only.bicep"
ENV_FILE="${WORKSHOP_WEB_ENV:-$HERE/workshop-web.env}"

if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; N=$'\033[0m'
else R=''; G=''; Y=''; B=''; D=''; N=''; fi
step() { echo; echo "${B}==>${N} $1"; }
ok()   { echo "  ${G}✔${N} $1"; }
die()  { echo; echo "  ${R}✘ $1${N}" >&2; [[ -n "${2:-}" ]] && echo "     ${D}$2${N}" >&2; exit 1; }

APP_NAME="${1:-}"
PREVIEW=0
[[ "${2:-}" == "--preview" ]] && PREVIEW=1

# ---- 参数与前置检查 ---------------------------------------------------------
[[ -n "$APP_NAME" ]] || die "缺少应用名。" "用法：bash deploy-web-only.sh <你的应用名>"

# Container App 名称规则：3–32 位，小写字母/数字/连字符，字母开头，不能以连字符结尾。
if [[ ! "$APP_NAME" =~ ^[a-z][a-z0-9-]{1,30}[a-z0-9]$ ]]; then
  die "应用名 '$APP_NAME' 不合规。" \
      "要求：3–32 个字符，只能用小写字母、数字和连字符，必须字母开头、字母或数字结尾。"
fi

command -v az >/dev/null 2>&1 || die "找不到 az 命令。" "先装 Azure CLI，或重跑课前的环境安装脚本。"
[[ -f "$TEMPLATE" ]] || die "找不到模板 $TEMPLATE"

if [[ ! -f "$ENV_FILE" ]]; then
  die "找不到共享资源配置 workshop-web.env。" \
      "讲师会在课前发这个文件，把它放到 $HERE/ 下面再重跑。"
fi

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

# 这个文件会发给全班，里面不该有任何凭据。发现就拒绝运行 —— 与其让 30 份
# 密钥流出去，不如让讲师当场发现自己拷错了文件。
LEAKED=""
for v in AZURE_OPENAI_API_KEY AZURE_COMMUNICATION_SERVICE_CONNECTION_STRING \
         AZURE_CLIENT_SECRET AZURE_OPENAI_KEY; do
  [[ -z "${!v:-}" ]] || LEAKED="$LEAKED $v"
done
if [[ -n "$LEAKED" ]]; then
  die "workshop-web.env 里含有不该分发的凭据：${LEAKED}" \
      "这个文件会发给全班。删掉这些行再重跑 —— 本实验一个都用不到。"
fi

MISSING=""
for v in AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_RESOURCE_GROUP \
         ACA_ENV_NAME ACR_LOGIN_SERVER REGISTRY_IDENTITY_NAME AGENTS_BACKEND_URL; do
  # 值为空、或里面还留着 <占位符>，都算没填。
  [[ -n "${!v:-}" && "${!v}" != *"<"*">"* ]] || MISSING="$MISSING $v"
done
[[ -z "$MISSING" ]] || die "workshop-web.env 里这些值还没填：$MISSING" "找讲师要完整的配置文件。"

WEB_IMAGE_TAG="${WEB_IMAGE_TAG:-workshop}"

echo "${B}Lab 05-1 · 部署你自己的 Web 应用${N}"
echo "  ${D}应用名：${APP_NAME}    资源组：${AZURE_RESOURCE_GROUP}${N}"

# ---- 登录 -------------------------------------------------------------------
step "登录实验服务主体"
CURRENT="$(az account show --query id -o tsv 2>/dev/null || true)"
if [[ "$CURRENT" == "$AZURE_SUBSCRIPTION_ID" ]]; then
  ok "已登录目标订阅，跳过"
else
  echo "  ${D}请粘贴讲师发的客户端密码（输入不会显示）${N}"
  read -rs -p "  Client secret: " SP_SECRET; echo
  [[ -n "$SP_SECRET" ]] || die "没有输入密码。"
  # 密码只经 stdin 传给 az，不写进命令行，避免留在 shell 历史里。
  if ! az login --service-principal \
        --username "$AZURE_CLIENT_ID" \
        --password "$SP_SECRET" \
        --tenant "$AZURE_TENANT_ID" \
        --only-show-errors >/dev/null 2>&1; then
    unset SP_SECRET
    die "登录失败。" "确认密码没有多余空格；仍失败就找讲师检查服务主体是否已授权。"
  fi
  unset SP_SECRET
  ok "登录成功"
fi

az account set --subscription "$AZURE_SUBSCRIPTION_ID" --only-show-errors 2>/dev/null \
  || die "无法切换到订阅 $AZURE_SUBSCRIPTION_ID" "找讲师确认服务主体的订阅可见性。"

if ! az group show --name "$AZURE_RESOURCE_GROUP" --only-show-errors >/dev/null 2>&1; then
  die "看不到资源组 ${AZURE_RESOURCE_GROUP}。" \
      "讲师还没给实验服务主体授权，或订阅选错了。不要改用个人账号，找讲师。"
fi
ok "资源组 $AZURE_RESOURCE_GROUP 可访问"

# ---- 共享资源预检（先失败在这里，比部署到一半失败好排查）-------------------
step "检查讲师预置的共享资源"
check_shared() {  # $1=类型描述  $2=az 命令...
  local label="$1"; shift
  if "$@" --only-show-errors >/dev/null 2>&1; then ok "$label"; else
    die "共享资源不可用：$label" "不要改脚本，直接联系讲师恢复共享服务。"
  fi
}
# 不依赖可选的 `containerapp` CLI 扩展；预检只需确认 ARM 资源可访问。
check_shared "Container Apps 环境 $ACA_ENV_NAME" \
  az resource show -g "$AZURE_RESOURCE_GROUP" \
    --resource-type Microsoft.App/managedEnvironments -n "$ACA_ENV_NAME"
check_shared "拉取身份 $REGISTRY_IDENTITY_NAME" \
  az identity show -g "$AZURE_RESOURCE_GROUP" -n "$REGISTRY_IDENTITY_NAME"

# ---- 部署 -------------------------------------------------------------------
PARAMS=(
  webAppName="$APP_NAME"
  containerAppsEnvironmentName="$ACA_ENV_NAME"
  acrLoginServer="$ACR_LOGIN_SERVER"
  registryIdentityName="$REGISTRY_IDENTITY_NAME"
  webImageTag="$WEB_IMAGE_TAG"
  agentsBackendUrl="$AGENTS_BACKEND_URL"
)

if [[ $PREVIEW -eq 1 ]]; then
  step "预览（what-if）—— 不会改动任何资源"
  az deployment group what-if \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --template-file "$TEMPLATE" \
    --parameters "${PARAMS[@]}" \
    --only-show-errors
  echo; echo "${Y}这是预览，什么都没有部署。${N}去掉 --preview 再跑一次即可正式部署。"
  exit 0
fi

step "部署 ${APP_NAME}（约 1–2 分钟）"
if ! az deployment group create \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --name "weblab-$APP_NAME" \
      --template-file "$TEMPLATE" \
      --parameters "${PARAMS[@]}" \
      --only-show-errors >/tmp/weblab.$$.json 2>/tmp/weblab.$$.err; then
  echo
  sed 's/^/     /' /tmp/weblab.$$.err | tail -12
  rm -f /tmp/weblab.$$.json /tmp/weblab.$$.err
  die "部署失败（原因见上）。" \
      "名称冲突就换一个应用名重跑；403/看不到资源就联系讲师。"
fi

URL="$(python3 -c "
import json,sys
d=json.load(open('/tmp/weblab.$$.json'))
print(d.get('properties',{}).get('outputs',{}).get('WEB_APP_URL',{}).get('value',''))
" 2>/dev/null)"
rm -f /tmp/weblab.$$.json /tmp/weblab.$$.err
ok "部署完成"

# ---- 回执 -------------------------------------------------------------------
echo
echo "${B}================ 你的应用 ================${N}"
if [[ -n "$URL" ]]; then
  echo "  ${G}${URL}${N}"
else
  echo "  ${Y}没取到 URL，用这条命令查：${N}"
  echo "  ${D}az containerapp show -g $AZURE_RESOURCE_GROUP -n $APP_NAME --query properties.configuration.ingress.fqdn -o tsv${N}"
fi
echo
echo "  ${D}第一次打开会慢几十秒 —— minReplicas=0，正在冷启动，属于正常。${N}"
echo "  ${D}课后不要自己删除任何资源，讲师会按应用名统一清理。${N}"
