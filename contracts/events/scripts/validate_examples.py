"""Validates contracts/events/examples/*.json against their schemas in openapi.yaml.

Usage: python3 contracts/events/scripts/validate_examples.py   (needs pyyaml, jsonschema)
"""
import json
import pathlib
import sys

import jsonschema
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = yaml.safe_load((ROOT / "openapi.yaml").read_text())

EXAMPLES = {
    "public-event.response.json": {"$ref": "#/components/schemas/PublicEvent"},
    "my-events.response.json": {
        "type": "object",
        "required": ["events"],
        "properties": {"events": {"type": "array", "items": {"$ref": "#/components/schemas/MyEvent"}}},
    },
    "agenda.response.json": {"$ref": "#/components/schemas/Agenda"},
    "draft.response.json": {"$ref": "#/components/schemas/Draft"},
    "publish.request.json": {"type": "object", "additionalProperties": False, "properties": {"eventId": {"type": "string"}}},
    "publish.response.json": {"$ref": "#/components/schemas/PublishResult"},
    "validation-error.response.json": {"$ref": "#/components/schemas/Error"},
}

failed = False
for name, root in EXAMPLES.items():
    schema = {**spec, **root}
    validator = jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker())
    errors = list(validator.iter_errors(json.loads((ROOT / "examples" / name).read_text())))
    for e in errors:
        print(f"{name}: {e.message} at {list(e.absolute_path)}")
    failed |= bool(errors)
    print(f"{name}: {'FAIL' if errors else 'ok'}")
missing = {p.name for p in (ROOT / "examples").glob("*.json")} - EXAMPLES.keys()
if missing:
    print("examples without a schema mapping:", missing)
    failed = True
sys.exit(1 if failed else 0)
