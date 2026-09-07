#!/usr/bin/env bash
# =============================================================================
# 填写 Azure OpenAI 凭证（Lab 03 开始需要）
#
#   bash .devcontainer/set-key.sh
#
# 讲师课上会发一套共享的 Endpoint / 部署名 / Key。这个脚本把它们写进
# code/agents/.env —— 该文件已被 .gitignore 忽略，不会进版本库。
#
# Key 用隐藏输入读取，不作为命令行参数传入，所以不会留在 shell 历史里。
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/code/agents/.env"
EXAMPLE="$REPO_ROOT/code/agents/.env.example"

if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; N=$'\033[0m'
else R=''; G=''; Y=''; B=''; D=''; N=''; fi
die() { echo; echo "  ${R}✘ $1${N}" >&2; exit 1; }

[[ -f "$ENV_FILE" ]] || cp "$EXAMPLE" "$ENV_FILE" 2>/dev/null || die "找不到 $EXAMPLE"

# 读 .env 里某个变量的现值（忽略被注释掉的行）。
current() {
  sed -nE "s/^[[:space:]]*$1=[[:space:]]*//p" "$ENV_FILE" | tail -1
}

# 覆写一个变量：先删掉所有同名行（含被注释的），再追加。
# 用 grep 过滤而不是 sed 替换 —— Key 里可能有 / 和 & 这类会破坏 sed 的字符。
set_var() {
  local key="$1" val="$2" tmp
  tmp="$(mktemp)"
  grep -vE "^[[:space:]]*#?[[:space:]]*${key}=" "$ENV_FILE" > "$tmp" || true
  printf '%s=%s\n' "$key" "$val" >> "$tmp"
  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

# 环境变量优先于 .env：code/agents/opc_agents/config.py 用的是
# load_dotenv(...)，默认不覆盖已存在的环境变量。所以如果凭证已经通过
# Codespaces Secrets 注入，这个脚本就是多余的。
if [[ -n "${AZURE_OPENAI_API_KEY:-}" && -n "${AZURE_OPENAI_ENDPOINT:-}" ]]; then
  echo
  echo "${Y}!${N} 检测到环境变量里已经有 Azure OpenAI 凭证（可能来自 Codespaces Secrets）。"
  echo "${D}  代码会优先用环境变量，你不需要跑这个脚本。${N}"
  echo "${D}  仍要写进 .env 的话，继续即可。${N}"
fi

echo
echo "${B}填写 Azure OpenAI 凭证${N} ${D}· 直接回车 = 保留方括号里的当前值${N}"
echo

CUR_ENDPOINT="$(current AZURE_OPENAI_ENDPOINT)"
CUR_MODEL="$(current AZURE_OPENAI_MODEL)"

read -r -p "Endpoint  [${CUR_ENDPOINT}]: " IN_ENDPOINT
ENDPOINT="${IN_ENDPOINT:-$CUR_ENDPOINT}"

read -r -p "部署名     [${CUR_MODEL}]: " IN_MODEL
MODEL="${IN_MODEL:-$CUR_MODEL}"

# 隐藏输入：不回显，也不会进 shell 历史。
read -rs -p "API Key    (输入时不显示): " KEY
echo

# 去掉首尾空白 —— 从聊天窗口复制粘贴时经常会带上。
ENDPOINT="$(printf '%s' "$ENDPOINT" | tr -d '[:space:]')"
MODEL="$(printf '%s' "$MODEL" | tr -d '[:space:]')"
KEY="$(printf '%s' "$KEY" | tr -d '[:space:]')"

[[ -n "$ENDPOINT" ]] || die "Endpoint 不能为空。"
[[ -n "$MODEL" ]]    || die "部署名不能为空。"
[[ "$ENDPOINT" != *"<"*">"* ]] || die "Endpoint 还是占位符，请填讲师发的真实地址。"
[[ "$ENDPOINT" == https://* ]] || die "Endpoint 应该以 https:// 开头，你填的是：$ENDPOINT"

set_var AZURE_OPENAI_ENDPOINT "$ENDPOINT"
set_var AZURE_OPENAI_MODEL    "$MODEL"
if [[ -n "$KEY" ]]; then
  set_var AZURE_OPENAI_API_KEY "$KEY"
else
  # 留空是合法选择：config.py 会退回 AzureCliCredential（即 az login）。
  echo "  ${Y}!${N} Key 为空 —— 将使用 az login 的身份认证，记得先跑 ${D}az login${N}"
fi

echo
echo "  ${G}✔${N} 已写入 code/agents/.env ${D}(权限 600，已被 .gitignore 忽略)${N}"
echo
echo "${B}验证：${N}"
echo "  cd code/agents && python test_workflow.py --live \"What is the total budget by project status? Draw a bar chart.\""
echo
