import copy
import json
import unittest
from pathlib import Path
from enablement_checks import (api_json_value, exact_json, psql_matches_api,
                               require_owned_login_for_revocation, cli_session_pooler)

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'docs/checkpoints/m11_release_candidate_2026_11_04/evidence'


class OperatorBoundaryTests(unittest.TestCase):
    def test_every_retained_inventory_preserves_exact_value_across_boundaries(self):
        for i in range(1, 11):
            response = json.loads((BASE / f'HOSTED_READ_{i:02d}.json').read_text())
            with self.subTest(inventory=i):
                self.assertTrue(psql_matches_api(
                    json.dumps(api_json_value(response)), response))

    def test_original_ledger_failure_reproduces_without_target_drift(self):
        response = json.loads((BASE / 'HOSTED_READ_02.json').read_text())
        psql_value = api_json_value(response)
        self.assertNotEqual(psql_value, response['data'][0])
        self.assertTrue(psql_matches_api(json.dumps(psql_value), response))

    def test_catalogue_mapping_is_not_unwrapped_twice(self):
        response = json.loads((BASE / 'HOSTED_CATALOGUE_STATE.json').read_text())
        value = api_json_value(response)
        self.assertIn('columns', value)
        self.assertNotIn('columns', next(iter(value.values())))
        self.assertTrue(psql_matches_api(json.dumps(value), response))

    def test_wrapped_psql_payload_still_refuses(self):
        response = json.loads((BASE / 'HOSTED_READ_02.json').read_text())
        self.assertFalse(psql_matches_api(json.dumps(response['data'][0]), response))

    def test_real_ledger_drift_still_refuses(self):
        response = json.loads((BASE / 'HOSTED_READ_02.json').read_text())
        value = copy.deepcopy(api_json_value(response))
        value[-1]['statement_array_sha256'] = '0' * 64
        self.assertFalse(psql_matches_api(json.dumps(value), response))

    def test_real_function_body_and_grant_drift_still_refuse(self):
        response = json.loads((BASE / 'HOSTED_READ_03.json').read_text())
        for field, wrong in [('body_sha256', '0' * 64), ('acl', ['=X/postgres'])]:
            value = copy.deepcopy(api_json_value(response)); value[0][field] = wrong
            self.assertFalse(psql_matches_api(json.dumps(value), response))

    def test_catalogue_and_consumer_drift_still_refuse(self):
        response = json.loads((BASE / 'HOSTED_CATALOGUE_STATE.json').read_text())
        for field in ['rows', 'consumer_guard']:
            value = copy.deepcopy(api_json_value(response)); value[field] = []
            self.assertFalse(psql_matches_api(json.dumps(value), response))

    def test_bad_api_cardinality_refuses(self):
        for rows in [[], [{}, {}], [{}], [{'a': [], 'b': []}]]:
            with self.assertRaises(ValueError): api_json_value({'data': rows})

    def test_null_empty_boolean_number_and_array_order_remain_distinct(self):
        for left, right in [(None, []), (False, 0), (True, 1), (1, 1.0),
                            ([1, 2], [2, 1]), ({'a': None}, {})]:
            self.assertFalse(exact_json(left, right))
        self.assertTrue(exact_json({'a': 1, 'b': 2}, {'b': 2, 'a': 1}))

    def test_owned_idle_pooler_backend_can_be_revoked(self):
        state = self.state()
        require_owned_login_for_revocation(state, 'task-owned', self.expiry)
        state['backends'] = []
        require_owned_login_for_revocation(state, 'task-owned', self.expiry)

    expiry = '2026-11-05T02:39:08.329157+00:00'
    def state(self):
        return {'roles': [{'name': 'cli_login_postgres', 'valid_until': self.expiry}],
                'backends': [{'user': 'cli_login_postgres',
                              'application_name': 'task-owned', 'state': 'idle'}]}

    def test_foreign_or_active_backend_refuses(self):
        for field, value in [('application_name', 'other-task'), ('state', 'active'),
                             ('user', 'other-login')]:
            state = self.state(); state['backends'][0][field] = value
            with self.assertRaises(ValueError):
                require_owned_login_for_revocation(state, 'task-owned', self.expiry)

    def test_other_or_reissued_principal_refuses(self):
        for field, value in [('name', 'cli_login_other'),
                             ('valid_until', '2026-11-05T02:40:00+00:00')]:
            state = self.state(); state['roles'][0][field] = value
            with self.assertRaises(ValueError):
                require_owned_login_for_revocation(state, 'task-owned', self.expiry)


class CliPoolerSelectionTests(unittest.TestCase):
    target = 'otnhhdxstdnwccehacku'
    def entry(self, mode='transaction', port=6543):
        return {'db_host': 'aws-0-eu-west-1.pooler.supabase.com', 'db_port': port,
                'pool_mode': mode, 'db_name': 'postgres',
                'database_type': 'PRIMARY', 'identifier': self.target}

    def test_transaction_metadata_selects_same_host_session_listener(self):
        old = self.entry(); result = cli_session_pooler([old], self.target)
        self.assertEqual(result['db_host'], old['db_host'])
        self.assertEqual(result['identifier'], old['identifier'])
        self.assertEqual((result['pool_mode'], result['db_port']), ('session', 5432))
        self.assertEqual(old['db_port'], 6543)  # no provider/config mutation

    def test_existing_session_entry_remains_exact(self):
        result = cli_session_pooler([self.entry('session', 5432)], self.target)
        self.assertEqual(result['db_port'], 5432)

    def test_wrong_target_host_database_or_replica_refuses(self):
        for field, value in [('identifier', 'different'), ('db_host', 'other.example'),
                             ('db_name', 'other'), ('database_type', 'REPLICA')]:
            row = self.entry(); row[field] = value
            with self.assertRaises(ValueError): cli_session_pooler([row], self.target)
        with self.assertRaises(ValueError): cli_session_pooler([self.entry()], 'different')

    def test_unknown_mode_port_or_cardinality_refuses(self):
        for mode, port in [('session', 6543), ('transaction', 5432), ('unknown', 5432)]:
            with self.assertRaises(ValueError):
                cli_session_pooler([self.entry(mode, port)], self.target)
        for rows in [[], [self.entry(), self.entry()]]:
            with self.assertRaises(ValueError): cli_session_pooler(rows, self.target)


if __name__ == '__main__': unittest.main()
