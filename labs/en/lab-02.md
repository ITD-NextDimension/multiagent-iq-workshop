# Lab 02. Data Architecture

## Story

The data team realizes that questions such as “Which account funds this strategic project?” and
“Which delivery tasks depend on this project?” cannot be answered reliably from disconnected
tables. It applies Fabric IQ-style modeling to create a connected enterprise knowledge layer.

## Architecture

```text
dataIQ/
  ontology/opc.rdf             -> enterprise entities, properties, relationships
  bindings/data-bindings.json  -> entity and relationship mappings to data sources
  data/*.json                  -> Project, BankAccount, Task instances
  queries/sample-queries.json  -> natural-language-to-ontology examples
```

Core model:

```text
BankAccount ─funds→ Project ─has_task→ Task
```

If you have Microsoft Fabric, you can load the JSON files in [code/dataIQ/data](../../code/dataIQ/data) as Lakehouse tables and use [code/dataIQ/ontology/opc.rdf](../../code/dataIQ/ontology/opc.rdf) as the ontology design reference for Fabric IQ. Without Fabric, the local `dataIQ` folder is the runnable lightweight implementation.

## Lab Steps

1. Open [code/dataIQ/ontology/opc.rdf](../../code/dataIQ/ontology/opc.rdf) and identify the `Project`, `BankAccount`, and `Task` entity types.
2. Open [code/dataIQ/bindings/data-bindings.json](../../code/dataIQ/bindings/data-bindings.json) and inspect primary-key and relationship-key mappings.
3. Open [code/dataIQ/data/project.json](../../code/dataIQ/data/project.json) and verify project budget, status, and account fields.
4. Open [code/dataIQ/queries/sample-queries.json](../../code/dataIQ/queries/sample-queries.json) and choose one question for later agent testing.
5. Run `python mcp/server.py --selftest` again to confirm that ontology, bindings, and instances are parsed together.