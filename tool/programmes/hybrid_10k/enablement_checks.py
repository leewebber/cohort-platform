"""Exact JSON boundary checks for the reviewed Field Manual enablement operation.

No credentials, network, database mutation or target discovery lives here.
psql -qAt emits a JSON column's value; Management wraps that value in one row.
"""
import json
from datetime import datetime


def api_json_value(response):
    rows = response.get('data')
    if not isinstance(rows, list) or len(rows) != 1:
        raise ValueError('Expected exactly one API row')
    row = rows[0]
    if not isinstance(row, dict) or len(row) != 1:
        raise ValueError('Expected exactly one API JSON column')
    return next(iter(row.values()))


def exact_json(left, right):
    def canonical(value):
        return json.dumps(value, sort_keys=True, ensure_ascii=False,
                          separators=(',', ':'), allow_nan=False)
    return canonical(left) == canonical(right)


def psql_matches_api(raw, response):
    value = json.loads(raw)
    return exact_json(value, api_json_value(response))


def require_owned_login_for_revocation(state, application_name, provider_expiry):
    """Accept only this exact issued login, including its idle pooler backends."""
    roles = state.get('roles')
    if not isinstance(roles, list) or len(roles) != 1:
        raise ValueError('Expected exactly the task-issued CLI principal')
    role = roles[0]
    if role.get('name') != 'cli_login_postgres':
        raise ValueError('Unexpected CLI principal')
    expected = datetime.fromisoformat(provider_expiry)
    actual = datetime.fromisoformat(role['valid_until'])
    if expected.tzinfo is None or actual.tzinfo is None or actual != expected:
        raise ValueError('CLI issuance expiry changed')
    backends = state.get('backends')
    if not isinstance(backends, list) or any(
        b.get('user') != 'cli_login_postgres'
        or b.get('application_name') != application_name
        or b.get('state') != 'idle' for b in backends
    ):
        raise ValueError('Unexpected active or foreign CLI backend')
