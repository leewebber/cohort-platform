"""Offline only: construct the reviewed five-file deployment's exact source copy.
Does not link, authenticate, contact Supabase, apply SQL, or copy any .temp/fixtures.
"""
import argparse
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
MANIFEST=ROOT/'docs/checkpoints/m11_release_candidate_2026_11_04/MIGRATIONS.json'
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',required=True)
    args=parser.parse_args()
    out=Path(args.out).resolve()
    assert not out.is_relative_to(ROOT),'Deployment copy must be separate from the repository'
    assert not out.exists(),'Preserve existing output; choose a new task-owned directory'
    manifest=json.loads(MANIFEST.read_text())
    assert manifest['target_ref']=='otnhhdxstdnwccehacku'
    assert len(manifest['migrations'])==5 and len(manifest['deployment_copy_files'])==135
    sources={}
    for name,digest in manifest['deployment_copy_files'].items():
        assert name.startswith('supabase/migrations/') and Path(name).name==name.split('/')[-1]
        assert 'durable_publication_approval_events' not in name and 'fixture' not in name and 'witness' not in name
        raw=(ROOT/name).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==digest,name
        sources[name]=raw
    out.mkdir(mode=0o700)
    (out/'supabase/migrations').mkdir(parents=True)
    for name,raw in sources.items():(out/name).write_bytes(raw)
    (out/'supabase/config.toml').write_text('project_id = "m11releasecandidate"\n[db]\nmajor_version = 17\n[db.seed]\nenabled = false\nsql_paths = []\n')
    receipt={'classification':'OFFLINE_PREPARATION_NO_LOGIN_LINK_OR_APPLY','target_ref':manifest['target_ref'],'files_sha256':manifest['deployment_copy_files'],'expected_missing_versions_after_fresh_recheck':[m['version'] for m in manifest['migrations']],'source_manifest_sha256':hashlib.sha256(MANIFEST.read_bytes()).hexdigest(),'contains_repository_temp':False,'contains_fixtures':False,'producer_included':False}
    (out/'COPY_MANIFEST.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('Prepared exact offline copy: 130 verified baseline files + 5 proposed files; no hosted operation')
if __name__=='__main__':main()
