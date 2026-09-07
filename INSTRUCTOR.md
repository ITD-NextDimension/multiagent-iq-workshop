# 讲师手册 · 企业 AI 化转型 Lab

> 这个仓库有 31 份文档，但你只需要按这一份的顺序走。
> **学员不看这份**，他们看 [scripts/pre-request-check/00-学员环境清单.md](scripts/pre-request-check/00-学员环境清单.md)。

## 30 秒决策

先定一件事，它决定你课前要做多少准备：

| | **Lab 05 完整版** | **Lab 05-1 资源受限版** |
|---|---|---|
| 每人建 | AKS + ACR + 会话池 + ACS | 只建一个 Web Container App |
| 时长 | 30 分钟 | 15 分钟 |
| 学员需要 | `az` + `kubectl` + 自己的订阅权限 | 只要 `az`，用讲师发的服务主体 |
| 你课前要做 | 确保每人有独立资源组 | **预置一整套共享环境**（见下） |
| 适合 | 人少、每人有自己的订阅 | 人多、共用一个订阅、配额紧张 |

> ⚠️ 走完整版时注意：`deploy.sh` 的 `RG` / `AKS_NAME` 是常量，`ACR_NAME` 由订阅 ID 派生。
> **同一订阅下所有学员会互相覆盖。** 让每人带上自己的名字：
> `RG=rg-<你> PREFIX=<你> AKS_NAME=aks-<你> bash scripts/deploy.sh`

---

## T-7 天 · 确认三件只有你能推动的事

1. **GitHub Copilot 的组织策略**。Lab 02–04 全程依赖 Agent 模式。
   企业组织默认可能是关闭的，**开通要走审批，当天绝对来不及**。
   让学员提前一天自测：Copilot Chat 里能否切到 Agent 模式。
2. **Azure 订阅与配额**。走完整版的话，每人一套 AKS 会撞配额；
   不确定就直接走 Lab 05-1。
3. **网络**。场地网络慢或有代理时，走离线包路线（见 T-3）。

---

## T-3 天 · 打离线包（可选，但网络差就必须做）

在你自己的 mac 上跑一次，三个包（含 Windows 的）都能打出来：

```bash
bash scripts/bundle/build-bundle.sh
```

产出在 `scripts/bundle/dist/`，约 1.4GB，**已被 .gitignore 排除**：

| 包 | 大小 | 给谁 |
|---|---|---|
| `workshop-bundle-mac-arm64.zip` | ~471MB | Apple Silicon |
| `workshop-bundle-mac-intel.zip` | ~505MB | Intel Mac |
| `workshop-bundle-windows.zip` | ~479MB | Windows（装进 WSL） |

传网盘或 U 盘，**让学员按自己的电脑只下一个**。下错了脚本第一步就会告诉他。

细节见 [scripts/bundle/README.md](scripts/bundle/README.md)。

> **两项无法离线，务必课前告知**：
> macOS 的 Azure CLI（微软只提供 Homebrew 渠道）；
> Windows 的 WSL2 + Ubuntu（约 500MB，**需要重启一次**）。

---

## T-1 天 · 发给学员，收回执

> **预检脚本的职责只有一个：让学员的电脑能上课。**
> 它不部署任何东西、不碰你的共享资源、不需要任何凭据 —— 单个文件就能跑。
> 你自己的准备工作在上一节和下一节，不要指望预检替你做。

发这两样：

- `scripts/pre-request-check.zip`（48KB，含双平台脚本和可勾选的 HTML 清单）
- 或者离线包三选一（如果走离线路线）

学员跑完会得到一行回执，让他们发到班级群：

```text
[precheck] READY | macos | Python 3.12.10 | FAIL=0 WARN=0
```

**看到 `READY` 才算准备完毕。** 收不齐就一个个催 —— 当天补装会吃掉整节课。

学员端命令：

```bash
bash workshop-precheck-mac.sh --yes          # macOS，全自动
powershell -ExecutionPolicy Bypass -File .\workshop-precheck-windows.ps1
```

---

## T-1 天 · 走 Lab 05-1 的话，预置共享环境

只有选了资源受限版才需要这一段。

1. 跑一次完整 `deploy.sh`，建出共享的资源组、ACR、Container Apps 环境、
   拉取身份和 AKS 上的 Agent API。
2. 用学员会用的标签推一次 Web 镜像（默认 `workshop`）。
3. 建一个**实验服务主体**，只授予那个资源组的 Contributor。
4. 填配置并发给学员：

```bash
cp code/cloud/scripts/workshop-web.env.example code/cloud/scripts/workshop-web.env
# 填入共享资源标识，然后把这个文件发给学员
```

> ⚠️ **这个文件会发给全班，只能放资源标识。**
> 不要从 `agents/.env` 拷贝 `AZURE_OPENAI_API_KEY` 或 ACS 连接串进去 ——
> Lab 05-1 一个都用不到，脚本检测到会直接拒绝运行。
> 服务主体密码**不写进文件**，课上口头/私信给，运行时隐藏输入。

完整走查见 [docs/deployment.md](docs/deployment.md)。

---

## 当天 · 180 分钟

| 时间 | 段落 | 讲义 |
|---|---|---|
| 15 min | 开场：场景 + 成品演示 | 先看结果，再拆过程 |
| 25 min | Lab 01 让系统读得懂业务 | [labs/cn/lab-01.md](labs/cn/lab-01.md) |
| 30 min | Lab 02 把本体变成可调用的工具 | [labs/cn/lab-02.md](labs/cn/lab-02.md) |
| 10 min | 休息 | |
| 35 min | Lab 03 两个智能体分工协作 | [labs/cn/lab-03.md](labs/cn/lab-03.md) |
| 20 min | Lab 04 做成 Copilot 应用 | [labs/cn/lab-04.md](labs/cn/lab-04.md) |
| 30 min | Lab 05 上云 **或** Lab 05-1 | [lab-05.md](labs/cn/lab-05.md) / [lab-05-1.md](labs/cn/lab-05-1.md) |
| 15 min | 收尾：架构回顾 + Q&A | |

**Lab 01 有一份逐步走查脚本**（含 Copilot 提示词、对答案、9 个截图点）：
[docs/walkthrough/lab-01.md](docs/walkthrough/lab-01.md)

**讲课用 PPT**：`docs/AKS-MultiAgentIQ_教学PPT_MSSolutionsDay_美化版v2.pptx`（43 页，留了截图位）

### 每节课下课前的硬指标

不用问"懂了吗"，让他们给你这三行：

```bash
pip list --format=freeze | wc -l           # Lab 01 → 64
python mcp/server.py --selftest | tail -1  # Lab 01 → {"active": 105000.0, ...}
python test_workflow.py | tail -1          # Lab 03 → All offline tests passed
```

---

## 现场排障速查

| 现象 | 真实原因 | 处理 |
|---|---|---|
| Copilot 切不到 Agent 模式 | 组织策略关闭 | **现场解决不了**，走 Claude Code / Cursor 备选 |
| `ModuleNotFoundError: mcp` | 新终端没激活虚拟环境 | `source .venv/bin/activate` |
| 一堆 `IncompleteFieldDefinitionWarning` | **正常现象**，不是报错 | 提前说，否则一半人举手 |
| `import mcp` 在 `code/` 下拿到本地目录 | `code/mcp/` 遮蔽了同名包 | 用脚本路径 `python mcp/server.py`，别 `cd` 进去 import |
| WSL 里依赖装不上 | Ubuntu 22.04 自带 3.10，离线包是 cp312 | 装 Ubuntu 24.04，或 deadsnakes 装 3.12 |
| Lab 05 在第 4 步失败 | 缺 `az` 的 `communication` 扩展 | `az extension add -n communication`（预检已会装） |
| 部署很快就 403 | 服务主体授权没做完 | 联系你自己，别让学员改 RBAC |
| 页面第一次打开很慢 | `minReplicas=0` 冷启动 | 等几十秒刷新，不是故障 |

---

## 课后

**走完整版**：让学员各自 `bash scripts/teardown.sh`（会创建计费资源，务必清）。

**走 05-1**：**学员不执行任何删除命令** —— 资源组是共享的。你按应用名统一清理。

---

## 对外发布仓库

活动前保持私有，结束后再考虑公开：

```bash
DRY_RUN=1 scripts/publish-workshop.sh <git-url>   # 先干跑，过密钥门
scripts/publish-workshop.sh <git-url>
```

脚本会导出**单个 squash 提交**并扫描密钥（GUID、真实域名、连接串）。

> ⚠️ 公开前还有一件事没解决：上游 `kinfey/AKS_MultiAgentIQ` 是 private + license NONE。
> 对外培训或转公开之前需要拿到书面许可。

---

## 文档地图

| 我要… | 看这个 |
|---|---|
| 让学员准备环境 | [00-学员环境清单.md](scripts/pre-request-check/00-学员环境清单.md) |
| 打离线包 | [scripts/bundle/README.md](scripts/bundle/README.md) |
| 讲 Lab 01 | [docs/walkthrough/lab-01.md](docs/walkthrough/lab-01.md) |
| 部署 Lab 05-1 | [docs/deployment.md](docs/deployment.md) |
| 理解代码架构 | [code/README.zh.md](code/README.zh.md) |
| 理解云端架构 | [code/cloud/README.md](code/cloud/README.md) |
| 让 Copilot 懂这个项目 | [.github/copilot-instructions.md](.github/copilot-instructions.md) |
