"""Emit fixture SQL for the caller's checked disposable database only."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
CATALOGUE = ROOT / "docs/checkpoints/m11_callback_a76c7cd_2026_11_05/evidence/AFTER_catalogue.json"
OWNER = "a3200000-0000-4000-8000-000000000001"


def sql_json(data):
    body = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    if "$fixture$" in body:
        raise ValueError("Unexpected SQL delimiter in fixture")
    return f"$fixture${body}$fixture$::jsonb"


def emit(m31_file, m32_file):
    equipment = json.loads(m31_file.read_text())
    time = json.loads(m32_file.read_text())
    bundles = [*equipment, time]
    for bundle in bundles:
        bundle["payload"]["owner_id"] = OWNER
    ids = {
        exercise["exercise_id"]
        for bundle in bundles
        for graph in bundle["payload"]["protocol_graphs"]
        for block in graph["blocks"]
        for exercise in block.get("exercises", [])
    }
    ids.update(bundle["approval"]["replacement_exercise_id"] for bundle in equipment)
    fields = ("exercise_id", "name", "slug", "equipment", "published")
    retained = json.loads(CATALOGUE.read_text())["data"][0]["jsonb_build_object"]["rows"]
    catalogue = [{k: row[k] for k in fields} for row in retained if row["exercise_id"] in ids]
    if {row["exercise_id"] for row in catalogue if row["published"]} != ids:
        raise ValueError("Missing exact published catalogue evidence")
    print(f"""
      INSERT INTO public.exercises_v2(exercise_id,name,slug,equipment,published)
      SELECT exercise_id,name,slug,equipment,published
      FROM jsonb_to_recordset({sql_json(catalogue)})
        AS x(exercise_id text,name text,slug text,equipment text,published boolean)
      ON CONFLICT (exercise_id) DO NOTHING;
      DO $$
      BEGIN
        IF EXISTS (
          SELECT FROM jsonb_to_recordset({sql_json(catalogue)})
            AS x(exercise_id text,name text,slug text,equipment text,published boolean)
          LEFT JOIN public.exercises_v2 e USING(exercise_id)
          WHERE (e.name,e.slug,e.equipment,e.published)
            IS DISTINCT FROM (x.name,x.slug,x.equipment,x.published)
        ) THEN RAISE EXCEPTION 'Disposable catalogue differs from retained pins'; END IF;
      END $$;
      CREATE TEMP TABLE m31_fixtures(payload jsonb, approval jsonb);
      INSERT INTO m31_fixtures SELECT * FROM jsonb_to_recordset({sql_json(equipment)})
        AS x(payload jsonb,approval jsonb);
      CREATE TEMP TABLE m32_fixture(payload jsonb, approval jsonb);
      INSERT INTO m32_fixture VALUES ({sql_json(time['payload'])}, {sql_json(time['approval'])});
    """)


if __name__ == "__main__":
    emit(*(Path(path) for path in sys.argv[1:]))
