"""Prepare the pinned 136-file CLI workdir offline. Never contacts Supabase."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    destination = args.destination.resolve()
    if destination.exists():
        raise SystemExit('Destination must be a new task-owned directory')
    root = Path(__file__).resolve().parents[3]
    package = json.loads(Path(__file__).with_name('PACKAGE.json').read_text())
    source_commit = package['implementation_commit']
    proof = json.loads((root / package['baseline_source_proof']).read_text())
    entries = [(Path(row['source_file']).name, row['source_file_sha256'])
               for row in proof['entries']]
    entries.append((Path(package['migration']).name, package['migration_sha256']))
    if len(entries) != 136 or len({name for name, _ in entries}) != 136:
        raise SystemExit('Expected exactly 136 distinct migration files')
    contents = {}
    for name, expected_hash in entries:
        if name == package['excluded_migration']:
            raise SystemExit('Deferred HYROX producer must be excluded')
        data = subprocess.check_output(
            ['git', 'show', f'{source_commit}:supabase/migrations/{name}'], cwd=root)
        if hashlib.sha256(data).hexdigest() != expected_hash:
            raise SystemExit(f'Migration source hash mismatch for {name}')
        contents[name] = data
    migrations = destination / 'supabase/migrations'
    migrations.mkdir(parents=True)
    for name, data in sorted(contents.items()):
        (migrations / name).write_bytes(data)
    (destination / 'supabase/config.toml').write_text(
        'project_id = "cohort-m12-end-release"\n'
        '[db]\nmajor_version = 17\n'
        '[db.migrations]\nenabled = true\nschema_paths = []\n')
    print(json.dumps({'workdir': str(destination), 'migration_files': len(contents),
                      'source_commit': source_commit, 'hosted_contact': False}))


if __name__ == '__main__':
    main()
