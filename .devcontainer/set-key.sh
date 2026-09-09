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

[[ -f "$EXAMPLE" ]] || die "找不到模板 $EXAMPLE"
[[ -f "$ENV_FILE" ]] || cp "$EXAMPLE" "$ENV_FILE"
chmod 600 "$ENV_FILE"

# 读某个变量的现值（忽略被注释掉的行）。
value_of() { sed -nE "s/^[[:space:]]*$1=[[:space:]]*//p" "$2" | tail -1; }
current()  { value_of "$1" "$ENV_FILE"; }
example()  { value_of "$1" "$EXAMPLE"; }

# 删除一个变量的所有行（含被注释的）。用 grep 过滤而不是 sed 替换 ——
# Key 里可能有 / 和 & 这类会破坏 sed 的字符。
# 临时文件会短暂持有整份 .env（含 Key）。用脚本级 EXIT trap 兜底：
# RETURN trap 在没有 functrace 时不是函数局部的，会在后续每个函数返回时
# 重复触发，那时局部变量已出作用域，set -u 直接报 unbound variable。
TMPF=""
cleanup() { [[ -n "$TMPF" ]] && rm -f "$TMPF"; return 0; }
trap cleanup EXIT INT TERM

_filter_out() {
  local key="$1"
  TMPF="$(mktemp)"
  grep -vE "^[[:space:]]*#*[[:space:]]*${key}=" "$ENV_FILE" > "$TMPF" || true
  cat "$TMPF" > "$ENV_FILE"
  rm -f "$TMPF"; TMPF=""
}
set_var()   { _filter_out "$1"; printf '%s=%s\n' "$1" "$2" >> "$ENV_FILE"; chmod 600 "$ENV_FILE"; }
unset_var() { _filter_out "$1"; chmod 600 "$ENV_FILE"; }

# read 在遇到 EOF（Ctrl-D）时返回非零，set -e 会让脚本一声不吭地退出。
# 包一层，把中断变成一句人话。
ask()        { read -r  -p "$1" "${@:2}" || die "输入中断，什么都没改。"; }
ask_hidden() { read -rs -p "$1" "${@:2}" || die "输入中断，什么都没改。"; echo; }

# 去掉首尾空白 —— 从聊天窗口复制粘贴时经常带上，也能顺手清掉 \r。
trim() { printf '%s' "$1" | tr -d '[:space:]'; }

# 环境变量优先于 .env：code/agents/opc_agents/config.py 用的是
# load_dotenv(...)，默认不覆盖已存在的环境变量。
if [[ -n "${AZURE_OPENAI_API_KEY:-}" && -n "${AZURE_OPENAI_ENDPOINT:-}" ]]; then
  echo
  echo "${Y}!${N} 检测到环境变量里已经有 Azure OpenAI 凭证。"
  echo "${D}  代码会优先用环境变量，你不需要跑这个脚本。仍要写进 .env 的话，继续即可。${N}"
fi

echo
echo "${B}填写 Azure OpenAI 凭证${N} ${D}· 直接回车 = 保留方括号里的当前值${N}"
echo

CUR_ENDPOINT="$(current AZURE_OPENAI_ENDPOINT)"
CUR_MODEL="$(current AZURE_OPENAI_MODEL)"

ask "Endpoint  [${CUR_ENDPOINT}]: " IN_ENDPOINT
ENDPOINT="$(trim "${IN_ENDPOINT:-$CUR_ENDPOINT}")"

ask "部署名     [${CUR_MODEL}]: " IN_MODEL
MODEL="$(trim "${IN_MODEL:-$CUR_MODEL}")"

ask_hidden "API Key    (输入时不显示，回车=不改动，输 - 表示清空): " IN_KEY
KEY="$(trim "$IN_KEY")"

# ---- 校验 -------------------------------------------------------------------
[[ -n "$ENDPOINT" ]] || die "Endpoint 不能为空。"
[[ -n "$MODEL" ]]    || die "部署名不能为空。"
[[ "$ENDPOINT" != *"<"*">"* ]] || die "Endpoint 还是占位符，请填讲师发的真实地址。"
[[ "$ENDPOINT" == https://* ]] || die "Endpoint 应该以 https:// 开头，你填的是：$ENDPOINT"

# .env.example 里的值是「长得像真的」的示例（比如 my-ai-foundry / gpt-5.5）。
# 一路回车会把它们当成真配置写进去，然后在 Lab 03 变成一个看起来像密钥错误
# 的 401/404。原样照抄就是没填。
if [[ "$ENDPOINT" == "$(trim "$(example AZURE_OPENAI_ENDPOINT)")" ]]; then
  die "Endpoint 还是 .env.example 里的示例值，不是讲师发的地址。" 
fi
if [[ "$MODEL" == "$(trim "$(example AZURE_OPENAI_MODEL)")" ]]; then
  die "部署名还是 .env.example 里的示例值，请填讲师发的部署名。"
fi

# ---- 写入 -------------------------------------------------------------------
set_var AZURE_OPENAI_ENDPOINT "$ENDPOINT"
set_var AZURE_OPENAI_MODEL    "$MODEL"

CUR_KEY="$(current AZURE_OPENAI_API_KEY)"
if [[ "$KEY" == "-" ]]; then
  unset_var AZURE_OPENAI_API_KEY
  KEY_NOTE="已清空 —— 将改用 az login 的身份认证，记得先跑 az login"
elif [[ -n "$KEY" ]]; then
  set_var AZURE_OPENAI_API_KEY "$KEY"
  KEY_NOTE="已更新"
elif [[ -n "$CUR_KEY" ]]; then
  KEY_NOTE="保留原有的 Key（没有改动）"
else
  KEY_NOTE="未设置 —— 将使用 az login 的身份认证，记得先跑 az login"
fi

echo
echo "  ${G}✔${N} 已写入 code/agents/.env ${D}(权限 600，已被 .gitignore 忽略)${N}"
echo "    ${D}Endpoint : ${ENDPOINT}${N}"
echo "    ${D}部署名   : ${MODEL}${N}"
echo "    ${D}API Key  : ${KEY_NOTE}${N}"

# ---- 可选：邮件功能 ----------------------------------------------------------
# Lab 04 最后一步「发送结果到 Email」用的是 Azure Communication Services。
# 不配也不影响 Lab 03 和 Lab 04 的问答部分，所以放在最后并且可跳过。
echo
echo "${B}可选 · Lab 04 的邮件功能${N} ${D}· 不需要就一路回车跳过${N}"
ask "ACS 连接串   [回车跳过]: " IN_ACS_CONN
ACS_CONN="$(printf '%s' "$IN_ACS_CONN" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
if [[ -n "$ACS_CONN" ]]; then
  ask "发件地址     [回车跳过]: " IN_ACS_FROM
  ACS_FROM="$(trim "$IN_ACS_FROM")"
  set_var AZURE_COMMUNICATION_SERVICE_CONNECTION_STRING "$ACS_CONN"
  [[ -n "$ACS_FROM" ]] && set_var AZURE_COMMUNICATION_SERVICE_SENDER_ADDRESS "$ACS_FROM"
  echo "  ${G}✔${N} 邮件凭证已写入"
else
  echo "  ${D}已跳过 —— Lab 04 的问答和图表不受影响，只有「发送到 Email」用不了。${N}"
fi

echo
echo "${B}验证：${N}"
echo "  cd /workspaces/*/code/agents && python test_workflow.py --live \"What is the total budget by project status? Draw a bar chart.\""
echo
