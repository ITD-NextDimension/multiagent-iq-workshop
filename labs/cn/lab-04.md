# Lab 04. 生成应用 app

## 故事

企业员工和管理者需要一个适配手机的统一入口，可以询问“哪些账户正在支持战略项目”“哪些任务会影响交付”“按项目状态统计预算”等问题。团队把 API 封装成 **AI Company** Copilot，并增加将答案和图表发送给业务负责人的邮件操作。

## 架构

```text
app/index.html
app/styles.css
app/app.js
   |
   | POST /ask
   | POST /send-email
   v
agents/api.py
   |
   v
answer + chart_url + 邮件发送状态
```

应用由 [code/agents/api.py](../../code/agents/api.py) 直接托管 [code/app](../../code/app) 静态文件。前端不依赖构建工具，适合在本地快速验证，也适合打包进容器后部署到 Azure Container Apps。

## 实验步骤

1. 打开 [code/app/index.html](../../code/app/index.html)，查看适配手机的 AI Company 页面和示例问题。
2. 打开 [code/app/app.js](../../code/app/app.js)，确认页面向 `/ask` 发送问题、渲染 `chart_url`，并在每次回答后提供 `/send-email` 操作。
3. 执行 `cd agents && uvicorn api:app --port 8000`，启动 API 和静态网页。
4. 打开 `http://127.0.0.1:8000/`，输入“Which projects does the business account fund?”。
5. 确认页面返回答案和可选图表，然后展开“发送结果到 Email”，填写收件邮箱并检查发送状态。