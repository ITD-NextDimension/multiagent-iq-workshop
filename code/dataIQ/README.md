# Enterprise Knowledge Ontology + Microsoft Fabric IQ

A compact enterprise knowledge ontology and mock dataset, built on the
concepts of [Microsoft Ontology Playground](https://microsoft.github.io/Ontology-Playground/#/learn)
and [Fabric IQ Ontology](https://learn.microsoft.com/en-us/fabric/iq/ontology/overview).

Reduced to **3 entities**: **Project**, **BankAccount**, **Task**.

## Mapping to Fabric IQ concepts

| Fabric IQ concept | Implementation here |
|---|---|
| Entity Type | `owl:Class` in `ontology/opc.rdf` |
| Property | `owl:DatatypeProperty` (with `isIdentifier`, `unit`, `propertyType`) |
| Relationship | `owl:ObjectProperty` (with `cardinality`, `fromEntityId`, `toEntityId`) |
| Data Binding | `bindings/data-bindings.json` (maps to OneLake tables; mock source is `data/*.json`) |
| Entity Instance | each row in `data/*.json` |
| NL2Ontology | `queries/sample-queries.json` |

## Directory layout

```
dataIQ/
├── ontology/
│   ├── opc.rdf            # Fabric IQ-compatible RDF/XML ontology (3 entities · 2 relationships)
│   └── metadata.json      # catalogue metadata
├── bindings/
│   └── data-bindings.json # entity/relationship -> OneLake data source bindings
├── data/                  # mock instance data (JSON)
│   ├── bank_account.json  # finance
│   ├── project.json       # work (includes project status)
│   └── task.json          # work
└── queries/
    └── sample-queries.json # NL2Ontology example Q&A
```

## Entity types (3)

| Entity | Domain | Key properties |
|---|---|---|
| Project | work | projectId, name, **status**, budget, startDate, dueDate |
| BankAccount | finance | accountId, bankName, accountType, balance, currency |
| Task | work | taskId, title, priority, status, estimateHours |

## Relationships (2)

```
BankAccount ─funds→ Project ─has_task→ Task
```

- `funds` (one-to-many): a bank account funds many projects (foreign key `project.accountId`)
- `has_task` (one-to-many): a project contains many tasks (foreign key `task.projectId`)

## How to use

1. **Preview in Ontology Playground**: open
   [Ontology Playground → Designer](https://microsoft.github.io/Ontology-Playground/#/designer)
   and import `ontology/opc.rdf` to explore the ontology graph interactively.
2. **Land in Microsoft Fabric IQ**: load `data/*.json` as OneLake Lakehouse tables,
   define entity bindings and relationship key mappings per `bindings/data-bindings.json`,
   refresh the graph, and ask questions with NL2Ontology (see `queries/sample-queries.json`).

> Note: `data/*.json` is mock data; primary/foreign keys (`accountId`, `projectId`) are kept
> consistent so relationship edges can be derived from the key mappings in `bindings`.
> All monetary amounts are in CNY.
