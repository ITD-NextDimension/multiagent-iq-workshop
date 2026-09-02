# Lab 02. 数据架构

## 故事

企业数据团队发现，“战略项目由哪个账户提供资金”“哪些交付任务依赖这个项目”这类问题无法通过割裂的表格可靠回答。于是团队使用 Fabric IQ 的思想建立相互关联的企业知识层，把项目、账户和任务转化为可被 Copilot 理解的业务上下文。

## 架构

```text
dataIQ/
  ontology/opc.rdf             -> 企业实体、属性、关系
  bindings/data-bindings.json  -> 实体和关系到数据源的映射
  data/*.json                  -> Project、BankAccount、Task 实例
  queries/sample-queries.json  -> 自然语言到本体查询示例
```

核心模型：

```text
BankAccount ─funds→ Project ─has_task→ Task
```

如果你有 Microsoft Fabric 环境，可以把 [code/dataIQ/data](../../code/dataIQ/data) 中的 JSON 作为 Lakehouse 表，把 [code/dataIQ/ontology/opc.rdf](../../code/dataIQ/ontology/opc.rdf) 的实体和关系落到 Fabric IQ；没有 Fabric 环境时，仓库中的本地 `dataIQ` 就是可运行的轻量实现。

## 实验步骤

1. 打开 [code/dataIQ/ontology/opc.rdf](../../code/dataIQ/ontology/opc.rdf)，识别 `Project`、`BankAccount`、`Task` 三类实体。
2. 打开 [code/dataIQ/bindings/data-bindings.json](../../code/dataIQ/bindings/data-bindings.json)，查看实体主键和关系外键映射。
3. 打开 [code/dataIQ/data/project.json](../../code/dataIQ/data/project.json)，确认项目预算、状态和账户字段。
4. 打开 [code/dataIQ/queries/sample-queries.json](../../code/dataIQ/queries/sample-queries.json)，选择一个问题作为后续智能体测试问题。
5. 再次执行 `python mcp/server.py --selftest`，确认本体、绑定和实例数据可以一起被解析。