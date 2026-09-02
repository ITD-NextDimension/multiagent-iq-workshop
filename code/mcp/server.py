"""OPC Ontology MCP Server.

A Model Context Protocol server that lets you quickly query the OPC (One-Person Company)
ontology and the relationships between its data.

It grounds every answer in three sources produced under ``dataIQ/`` and follows the
Microsoft Fabric IQ ontology concepts (entity types, identifier properties,
typed properties, and relationships with cardinality):

* ``dataIQ/ontology/opc.rdf``        - entity types, properties, relationships (RDF/OWL)
* ``dataIQ/bindings/data-bindings.json`` - entity -> data source + relationship keys
* ``dataIQ/data/*.json``              - the mock entity instances

Run:  python server.py                (stdio transport, for MCP clients)
Test: python server.py --selftest     (prints a quick smoke test, no MCP client)
"""

from __future__ import annotations

import json
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
HERE = Path(__file__).resolve().parent
DATA_IQ = (HERE.parent / "dataIQ").resolve()
ONTOLOGY_FILE = DATA_IQ / "ontology" / "opc.rdf"
BINDINGS_FILE = DATA_IQ / "bindings" / "data-bindings.json"

RDF = "{http://www.w3.org/1999/02/22-rdf-syntax-ns#}"
RDFS = "{http://www.w3.org/2000/01/rdf-schema#}"
OWL = "{http://www.w3.org/2002/07/owl#}"
ONT = "{http://example.org/ontology/opc/}"


# --------------------------------------------------------------------------- #
# Ontology + data loader
# --------------------------------------------------------------------------- #
class OntologyStore:
    """Parses the ontology + bindings and loads the instance data into memory."""

    def __init__(self, ontology_file: Path, bindings_file: Path) -> None:
        self.ontology_file = ontology_file
        self.bindings_file = bindings_file
        self.entities: dict[str, dict[str, Any]] = {}
        self.relationships: list[dict[str, Any]] = []
        self.bindings: dict[str, Any] = {}
        self.rows: dict[str, list[dict[str, Any]]] = {}
        self.load()

    # -- loading ---------------------------------------------------------- #
    def load(self) -> None:
        self._parse_ontology()
        self._load_bindings_and_data()

    def _local(self, uri: str) -> str:
        return uri.rsplit("/", 1)[-1]

    def _parse_ontology(self) -> None:
        root = ET.parse(self.ontology_file).getroot()

        # Entity types (owl:Class)
        for cls in root.findall(f"{OWL}Class"):
            name = self._local(cls.get(f"{RDF}about", ""))
            self.entities[name] = {
                "name": name,
                "label": (cls.findtext(f"{RDFS}label") or name),
                "description": (cls.findtext(f"{RDFS}comment") or ""),
                "icon": (cls.findtext(f"{ONT}icon") or ""),
                "properties": [],
            }

        # Datatype properties -> attach to their domain entity
        for prop in root.findall(f"{OWL}DatatypeProperty"):
            domain_el = prop.find(f"{RDFS}domain")
            range_el = prop.find(f"{RDFS}range")
            domain = self._local(domain_el.get(f"{RDF}resource", "")) if domain_el is not None else ""
            data_type = prop.findtext(f"{ONT}propertyType") or (
                self._local(range_el.get(f"{RDF}resource", "")) if range_el is not None else "string"
            )
            is_id = (prop.findtext(f"{ONT}isIdentifier") or "false").strip().lower() == "true"
            info = {
                "name": prop.findtext(f"{RDFS}label") or "",
                "type": data_type,
                "isIdentifier": is_id,
                "unit": prop.findtext(f"{ONT}unit") or None,
            }
            if domain in self.entities:
                self.entities[domain]["properties"].append(info)

        # Object properties (relationships)
        for prop in root.findall(f"{OWL}ObjectProperty"):
            domain_el = prop.find(f"{RDFS}domain")
            range_el = prop.find(f"{RDFS}range")
            self.relationships.append(
                {
                    "name": prop.findtext(f"{RDFS}label") or "",
                    "from": self._local(domain_el.get(f"{RDF}resource", "")) if domain_el is not None else "",
                    "to": self._local(range_el.get(f"{RDF}resource", "")) if range_el is not None else "",
                    "cardinality": prop.findtext(f"{ONT}cardinality") or "",
                    "description": prop.findtext(f"{RDFS}comment") or "",
                }
            )

    def _load_bindings_and_data(self) -> None:
        self.bindings = json.loads(self.bindings_file.read_text(encoding="utf-8"))
        bindings_dir = self.bindings_file.parent
        for eb in self.bindings.get("entityBindings", []):
            mock = eb.get("source", {}).get("mock")
            if not mock:
                continue
            path = (bindings_dir / mock).resolve()
            self.rows[eb["entityType"]] = json.loads(path.read_text(encoding="utf-8"))

    # -- helpers ---------------------------------------------------------- #
    def identity_field(self, entity_type: str) -> str | None:
        for eb in self.bindings.get("entityBindings", []):
            if eb["entityType"] == entity_type:
                return eb.get("identity")
        return None

    def resolve_entity(self, name: str) -> str | None:
        """Case-insensitive entity-type lookup."""
        for key in self.entities:
            if key.lower() == name.lower():
                return key
        return None

    def get_instance(self, entity_type: str, entity_id: str) -> dict[str, Any] | None:
        id_field = self.identity_field(entity_type)
        for row in self.rows.get(entity_type, []):
            if id_field and str(row.get(id_field)) == str(entity_id):
                return row
        return None

    def related(
        self, entity_type: str, entity_id: str, relationship: str | None = None
    ) -> list[dict[str, Any]]:
        """Traverse relationship bindings in both directions from an instance."""
        instance = self.get_instance(entity_type, entity_id)
        if instance is None:
            return []
        results: list[dict[str, Any]] = []
        for rb in self.bindings.get("relationshipBindings", []):
            if relationship and rb["relationship"] != relationship:
                continue
            # forward: this instance is the "from" side
            if rb["from"] == entity_type:
                key_val = instance.get(rb["fromKey"])
                for row in self.rows.get(rb["to"], []):
                    if key_val is not None and row.get(rb["toForeignKey"]) == key_val:
                        results.append(
                            {"relationship": rb["relationship"], "direction": "outbound",
                             "entityType": rb["to"], "instance": row}
                        )
            # reverse: this instance is the "to" side
            if rb["to"] == entity_type:
                key_val = instance.get(rb["toForeignKey"])
                for row in self.rows.get(rb["from"], []):
                    if key_val is not None and row.get(rb["fromKey"]) == key_val:
                        results.append(
                            {"relationship": rb["relationship"], "direction": "inbound",
                             "entityType": rb["from"], "instance": row}
                        )
        return results


STORE = OntologyStore(ONTOLOGY_FILE, BINDINGS_FILE)

# --------------------------------------------------------------------------- #
# MCP server + tools
# --------------------------------------------------------------------------- #
mcp = FastMCP("opc-ontology")


@mcp.tool()
def describe_ontology() -> dict[str, Any]:
    """Return an overview of the OPC ontology: entity types (with properties and the
    identifier property) and the relationships with their cardinality."""
    return {
        "ontology": STORE.bindings.get("ontology", "opc"),
        "entityTypes": [
            {
                "name": e["name"],
                "label": e["label"],
                "description": e["description"],
                "identifier": next((p["name"] for p in e["properties"] if p["isIdentifier"]), None),
                "properties": e["properties"],
                "instanceCount": len(STORE.rows.get(e["name"], [])),
            }
            for e in STORE.entities.values()
        ],
        "relationships": STORE.relationships,
    }


@mcp.tool()
def list_entity_types() -> list[dict[str, Any]]:
    """List the entity types with their instance counts."""
    return [
        {"name": e["name"], "label": e["label"], "instanceCount": len(STORE.rows.get(e["name"], []))}
        for e in STORE.entities.values()
    ]


@mcp.tool()
def list_instances(entity_type: str, where_field: str | None = None, where_value: str | None = None) -> dict[str, Any]:
    """List instances of an entity type. Optionally filter by ``where_field == where_value``.

    Args:
        entity_type: e.g. "Project", "BankAccount", "Task" (case-insensitive).
        where_field: optional property name to filter on (e.g. "status").
        where_value: optional value the field must equal (e.g. "active").
    """
    resolved = STORE.resolve_entity(entity_type)
    if resolved is None:
        return {"error": f"Unknown entity type '{entity_type}'.", "available": list(STORE.entities)}
    rows = STORE.rows.get(resolved, [])
    if where_field is not None and where_value is not None:
        rows = [r for r in rows if str(r.get(where_field)) == str(where_value)]
    return {"entityType": resolved, "count": len(rows), "instances": rows}


@mcp.tool()
def get_instance(entity_type: str, entity_id: str) -> dict[str, Any]:
    """Fetch a single instance by its identifier value.

    Args:
        entity_type: e.g. "Project" (case-insensitive).
        entity_id: the identifier value, e.g. "PRJ-001".
    """
    resolved = STORE.resolve_entity(entity_type)
    if resolved is None:
        return {"error": f"Unknown entity type '{entity_type}'.", "available": list(STORE.entities)}
    inst = STORE.get_instance(resolved, entity_id)
    if inst is None:
        return {"error": f"No {resolved} with id '{entity_id}'."}
    return {"entityType": resolved, "instance": inst}


@mcp.tool()
def get_related(entity_type: str, entity_id: str, relationship: str | None = None) -> dict[str, Any]:
    """Find instances related to a given instance by traversing relationships
    (both outbound and inbound), e.g. the tasks of a project, or the bank account
    that funds a project.

    Args:
        entity_type: source entity type, e.g. "Project".
        entity_id: source identifier, e.g. "PRJ-001".
        relationship: optional relationship name to restrict to, e.g. "has_task" or "funds".
    """
    resolved = STORE.resolve_entity(entity_type)
    if resolved is None:
        return {"error": f"Unknown entity type '{entity_type}'.", "available": list(STORE.entities)}
    if STORE.get_instance(resolved, entity_id) is None:
        return {"error": f"No {resolved} with id '{entity_id}'."}
    related = STORE.related(resolved, entity_id, relationship)
    return {"source": {"entityType": resolved, "id": entity_id}, "count": len(related), "related": related}


@mcp.tool()
def aggregate(entity_type: str, value_field: str, op: str = "sum", group_by: str | None = None) -> dict[str, Any]:
    """Aggregate a numeric property across an entity type, optionally grouped.

    Args:
        entity_type: e.g. "Project".
        value_field: numeric property to aggregate, e.g. "budget". Use "*" with op="count".
        op: one of "sum", "avg", "min", "max", "count".
        group_by: optional property to group by, e.g. "status".
    """
    resolved = STORE.resolve_entity(entity_type)
    if resolved is None:
        return {"error": f"Unknown entity type '{entity_type}'.", "available": list(STORE.entities)}
    rows = STORE.rows.get(resolved, [])

    def _agg(items: list[dict[str, Any]]) -> float | int:
        if op == "count":
            return len(items)
        vals = [float(r[value_field]) for r in items if isinstance(r.get(value_field), (int, float))]
        if not vals:
            return 0
        if op == "sum":
            return round(sum(vals), 2)
        if op == "avg":
            return round(sum(vals) / len(vals), 2)
        if op == "min":
            return min(vals)
        if op == "max":
            return max(vals)
        raise ValueError(f"Unsupported op '{op}'")

    if group_by:
        groups: dict[str, list[dict[str, Any]]] = {}
        for r in rows:
            groups.setdefault(str(r.get(group_by)), []).append(r)
        return {"entityType": resolved, "op": op, "field": value_field, "groupBy": group_by,
                "result": {k: _agg(v) for k, v in groups.items()}}
    return {"entityType": resolved, "op": op, "field": value_field, "result": _agg(rows)}


def _selftest() -> None:
    print("== describe_ontology ==")
    desc = describe_ontology()
    print(json.dumps({"entities": [e["name"] for e in desc["entityTypes"]],
                      "relationships": [r["name"] for r in desc["relationships"]]},
                     ensure_ascii=False))
    print("\n== list_instances(Project, status=active) ==")
    print(json.dumps(list_instances("Project", "status", "active"), ensure_ascii=False, indent=2))
    print("\n== get_related(BankAccount ACC-001) ==")
    print(json.dumps(get_related("BankAccount", "ACC-001", "funds"), ensure_ascii=False, indent=2))
    print("\n== get_related(Project PRJ-001, has_task) ==")
    print(json.dumps(get_related("Project", "PRJ-001", "has_task"), ensure_ascii=False, indent=2))
    print("\n== aggregate(Project budget sum group_by status) ==")
    print(json.dumps(aggregate("Project", "budget", "sum", "status"), ensure_ascii=False))


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        _selftest()
    else:
        # Default transport is stdio (used by the agents' MCPStdioTool). Set
        # MCP_TRANSPORT=streamable-http (or sse) + PORT to run as a network
        # service, e.g. when hosted on Azure Container Apps.
        transport = os.environ.get("MCP_TRANSPORT", "stdio").lower()
        if transport in ("http", "streamable-http", "sse"):
            try:
                mcp.settings.host = "0.0.0.0"
                mcp.settings.port = int(os.environ.get("PORT", "8080"))
            except Exception:
                pass
            mcp.run(transport="sse" if transport == "sse" else "streamable-http")
        else:
            mcp.run()
