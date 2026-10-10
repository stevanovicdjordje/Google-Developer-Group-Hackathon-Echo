"""Validates contracts/echo/examples/*.json against their schemas in openapi.yaml.

Usage: python3 contracts/echo/scripts/validate_examples.py   (needs pyyaml, jsonschema)
"""
import json
import pathlib
import sys

import jsonschema
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = yaml.safe_load((ROOT / "openapi.yaml").read_text())

EXAMPLES = {
    "ask.request.json": "#/components/schemas/AskRequest",
    "ask.response.json": "#/components/schemas/AiText",
    "catch-up.response.json": "#/components/schemas/AiText",
    "summary.response.json": "#/components/schemas/AiText",
    "translate.request.json": "#/components/schemas/TranslateRequest",
    "translate.response.json": "#/components/schemas/Translation",
    "questions.response.json": "#/paths/~1v1~1events~1{eventId}~1sessions~1{sessionId}~1questions/get/responses/200/content/application~1json/schema",
    "submit-question.request.json": "#/components/schemas/QuestionInput",
    "submit-question-merged.response.json": "#/components/schemas/Question",
    "validation-error.response.json": "#/components/schemas/Error",
    "transcript-line.firestore.json": "#/components/schemas/TranscriptLine",
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
