# Focused verification

Before credential issuance, current 0431d08 package inputs matched [the published pins](../live_attempt_8618697_2026_11_04/PACKAGE_SHA256.json). The two current Python tests passed:

```
PYTHONPATH=tool/catalogue M11_LOCAL_DB=1 M11_REHEARSAL_OUT=/private/tmp/m11_live_0431d08_20261104/offline_rehearsal PYTHONDONTWRITEBYTECODE=1 python3 -m unittest m11_setup_operation_test.Guards.test_canonical_manifest_roundtrip_preserves_exact_generated_seed m11_setup_operation_test.RetainedInventory.test_retained_169_insert_retain_replay_reuse_preserves_duplicate_rows_and_consumers -v
```

[Actual output](evidence/OFFLINE_READY_TESTS.txt), [fixture summary](evidence/offline_rehearsal/SUMMARY.json) and [frozen command/input hashes](evidence/OFFLINE_READY.json) retain prepare CLI -> canonical serialized manifest -> regenerated exact SQL -> pinned apply -> readback/retain -> exact replay/reuse. This is synthetic proof only; the genuine bundle is separate.

The already committed 24-test guard/negative suite at 0431d08 remains unchanged evidence, including ambiguity of proposed identities/dependencies, conflicting IDs/slugs, consumer/schema/row drift, writer locks, rollback/replay and receipt tampering. No broad unrelated repeat was necessary for this evidence/documentation task.

Exact live orchestration commands were frozen before credentials:

```
PYTHONDONTWRITEBYTECODE=1 python3 /private/tmp/m11_live_0431d08_20261104/preflight.py
PYTHONDONTWRITEBYTECODE=1 python3 /private/tmp/m11_live_0431d08_20261104/live.py
```

[preflight.py](evidence/preflight.py), [live.py](evidence/live.py), [APPLY_REVIEW](evidence/APPLY_REVIEW.json) and the exact [manifest](evidence/prepared/manifest.json)/[transaction](evidence/prepared/seed.sql) retain the commands and values. Only the one documented run was authorised; those historical commands must not be rerun as credential/application authority. The login clock ran with no script/package repair and preserved the fixed 90-second minimum reserve.

After supported credential revocation, the focused actual-evidence check passed:

```
flutter test --no-pub --reporter expanded /private/tmp/m11_live_0431d08_20261104/genuine_admission_test.dart
```

[Final output](evidence/ADMISSION_TESTS.txt) and [results](evidence/ADMISSION.json): 20 complete strength graphs; 28 exact missing IDs resolved; 77 prior IDs/105 prescriptions preserved; 60 old revisions/40 running bodies unchanged; 60-session review, editable exact roundtrip, actual archive readback and reopened archive review pass. The first probe included rest entries in a selected-session lookup; [that failure](evidence/ADMISSION_INITIAL_PROBE.json) is retained and corrected in the final probe. Credentials were already revoked throughout offline admission.

No application/runtime/schema code changed. Prior architecture, UI and negative-suite evidence is reused with its original checkpoint attribution. No browser/desktop or installed-device check ran. SHA256.json covers retained checkpoint artifacts; Git history and an external final publication receipt establish the checkpoint commit.
