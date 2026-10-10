"""Validates contracts/maps/examples/*.json against their schemas in openapi.yaml.

Usage: python3 contracts/maps/scripts/validate_examples.py   (needs pyyaml, jsonschema)
"""
import json
import pathlib
import sys

import jsonschema
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = yaml.safe_load((ROOT / "openapi.yaml").read_text())

# example file -> schema pointer
EXAMPLES = {
    "create-event.request.json": "#/components/schemas/EventInput",
    "create-stand.request.json": "#/components/schemas/FeatureInput",
    "validation-error.response.json": "#/components/schemas/Error",
    "publish.response.json": "#/paths/~1v1~1events~1{eventId}~1publish/post/responses/200/content/application~1json/schema",
}

failed = False
for name, ptr in EXAMPLES.items():
    schema = {"$ref": ptr, **spec}  # resolve refs against the whole spec
    validator = jsonschema.Draft202012Validator(schema)
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
