#!/usr/bin/env bash
# Compare committed content-graph artifacts to hosted Field Manual rows.
# Secrets are supplied externally (Supabase CLI keychain). Do not run in CI.
# Usage: M9_VERIFY_HOSTED=1 ./tool/content_graph/verify_hosted_published_artifacts.sh
set -euo pipefail
if [[ "${M9_VERIFY_HOSTED:-}" != "1" ]]; then
  echo "Refusing: set M9_VERIFY_HOSTED=1 to run this operational check." >&2
  echo "CI must not invoke this script." >&2
  exit 2
fi
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - "$REPO" <<'PY'
import json, subprocess, sys, urllib.request
from pathlib import Path

repo = Path(sys.argv[1])
ref = "otnhhdxstdnwccehacku"
root = repo / "content/content_graph/v1"
idx = json.loads((root / "index.json").read_text())
token = subprocess.check_output(
    ["security", "find-generic-password", "-s", "Supabase CLI", "-w"],
    text=True,
).strip()
if not token or "service_role" in token.lower():
    raise SystemExit("missing or invalid operational token")

def query(sql):
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{ref}/database/query",
        data=json.dumps({"query": sql}).encode(),
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.loads(resp.read().decode())

expected = {
    "apollo": {
        "manifest_id": "46940d28-9ed0-4287-ab18-e2c321b599a5",
        "require_full_resolution": False,
    },
    "spartan_v3": {
        "manifest_id": "ef94597b-8ac4-4ef5-9672-8c76b6255197",
        "require_full_resolution": True,
    },
}
failures = []
for cand in idx["candidates"]:
    label = cand["label"]
    if label not in expected:
        failures.append(f"unapproved candidate {label}")
        continue
    man = (root / cand["manifest_path"]).read_text()
    pub = json.loads((root / cand["publication_path"]).read_text())
    mid = expected[label]["manifest_id"]
    sql = f"""
    SELECT jsonb_build_object(
      'count', (SELECT count(*) FROM public.content_graph_manifests),
      'jobs', (SELECT count(*) FROM public.content_graph_reconstruction_jobs),
      'row', (
        SELECT jsonb_build_object(
          'programme_version_id', programme_version_id,
          'publisher_id', publisher_id,
          'compiler_version', compiler_version,
          'graph_format_version', graph_format_version,
          'source_package_hash', source_package_hash,
          'supplemental_relationship_hash', supplemental_relationship_hash,
          'graph_structural_hash', graph_structural_hash,
          'composite_identity', composite_identity,
          'publication_state', publication_state,
          'payload_eq', canonical_payload = $m9m${man}$m9m$::jsonb,
          'unresolved_eq', unresolved = $m9u${json.dumps(pub["unresolved"])}$m9u$::jsonb
        ) FROM public.content_graph_manifests WHERE id = '{mid}'
      )
    ) AS v;
    """
    row = query(sql)[0]["v"]
    hosted = row["row"]
    if row["count"] != 2 or row["jobs"] != 0:
        failures.append(f"{label} graph counts {row}")
    checks = {
        "programme_version_id": hosted["programme_version_id"] == cand["programme_version_id"] == pub["programme_version_id"],
        "publisher_id": hosted["publisher_id"] == pub["publisher_id"] == idx["publisher_id"],
        "source": hosted["source_package_hash"] == cand["source_package_hash"],
        "supplemental": hosted["supplemental_relationship_hash"] == cand["supplemental_relationship_hash"],
        "graph": hosted["graph_structural_hash"] == cand["graph_structural_hash"],
        "composite": hosted["composite_identity"] == cand["composite_identity"],
        "state": hosted["publication_state"] == "published",
        "payload": hosted["payload_eq"] is True,
        "unresolved": hosted["unresolved_eq"] is True,
        "rfr": pub["require_full_resolution"] is expected[label]["require_full_resolution"],
    }
    bad = [k for k, ok in checks.items() if not ok]
    if bad:
        failures.append(f"{label} mismatch {bad}")
    print(label, "OK" if not bad else f"FAIL {bad}")
if failures:
    raise SystemExit("HOSTED_ARTIFACT_MISMATCH: " + "; ".join(failures))
print("HOSTED_ARTIFACT_VERIFICATION_OK manifests=2 jobs=0")
PY
