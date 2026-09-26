# Private programme publication and activation — handoff

**Recorded:** 2026-09-26
**Status:** Implemented locally. Dedicated publication/activation path
added. Hosted apply and Lee’s tap remain operational follow-through.
**Branch:** `feat/private-programme-publication-activation-v1`
**Base:** `origin/main` `d7172391bc901f6d58511f26a0295679297dd69e`
**Contract:**
[`../architecture/Private_Programme_Publication_and_Activation_v1.md`](../architecture/Private_Programme_Publication_and_Activation_v1.md)

```text
LEE_BALI_HYBRID_BASE=PRIVATE_PUBLICATION_ACTIVATION_IN_PROGRESS
LEE_BALI_HYBRID_BASE_PRIVATE=true
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false
BALI_HOSTED_PRIVATE_PUBLICATION=false
PRIVATE_PROGRAMME_INFRASTRUCTURE=HOSTED_APPLIED
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

---

## What shipped

- `publish_private_exact_programme_version(jsonb)` — service_role only
- `list_my_private_programme_versions()` — authenticated, ownership-scoped
- `enrol_athlete_in_private_programme_version(uuid, text, date, boolean)`
  — explicit civil start date; three-argument RPC unchanged
- CLI `tool/programmes/bin/publish_private_exact_version.dart`
- Programmes → My private programmes + confirmation review
- Isolated preview `lib/main_private_activation_preview.dart`
- Gate BC + `supabase/tests/run_private_publication_gate.sh`

Migration:
`supabase/migrations/20260926140000_private_exact_version_publication.sql`

Owner IDs are operational `--owner-id` arguments. None are committed.

---

## Preview

```bash
flutter run -d chrome --web-port 4196 -t lib/main_private_activation_preview.dart
```

---

## Non-actions until gates pass

No hosted apply, no CLI publication, no assignment change, no B2.
