"""Validates contracts/find/examples/*.json against their schemas in openapi.yaml.

Usage: python3 contracts/find/scripts/validate_examples.py   (needs pyyaml, jsonschema)
"""
import json
import pathlib
import sys

import jsonschema
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = yaml.safe_load((ROOT / "openapi.yaml").read_text())

EXAMPLES = {
    "profile.json": "#/components/schemas/Profile",
    "recommendations.response.json": "#/components/schemas/Matches",
    "search.request.json": "#/components/schemas/SearchRequest",
    "search.response.json": "#/components/schemas/Matches",
    "person.response.json": "#/components/schemas/PersonDetail",
    "contact.request.json": "#/components/schemas/ContactRequest",
    "contact.response.json": "#/components/schemas/Contact",
    "meeting-spot.request.json": "#/components/schemas/MeetingSpotRequest",
    "meeting-spot.response.json": "#/components/schemas/Contact",
    "validation-error.response.json": "#/components/schemas/Error",
}

failed = False
for name, ptr in EXAMPLES.items():
    schema = {"$ref": ptr, **spec}
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
