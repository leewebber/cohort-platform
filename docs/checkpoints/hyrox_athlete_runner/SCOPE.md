# Bounded athlete application milestone

Implements the already resolved authoritative contract through existing production app paths.
No new prescription calculator, session creator, synthetic operational fallback, benchmark
attestation, automatic selection, prescription progression, export provider or content package.

| Surface | Representation and refusal boundary |
|---|---|
| Review | Server-issued exact programme review; readable values/dates/source and target projection; edits/account change invalidate |
| Consent | Existing append-only assignment/version CAS; explicit replacement/withdrawal; prior accepted consent serves future unstarted sessions |
| Start | Existing fixed canonical RPC; exact programme/occurrence/source/session checks; missing v3 capability never downgrades |
| Run/row | Existing intervals TimerConfiguration + ordinal IntervalWorkResult; flat positive work/recovery; exact step IDs/doses; explicit unit; no final recovery |
| Squat | Existing StrengthExercisePrescription sets/reps/fixed load or authored RIR; actual loads remain independent |
| Resume | Canonical server-frozen packet wins; exact performance snapshot comparison; saved generic timer phase resumes safely paused |
| Save/completion/History | Full immutable server packet alongside separate actuals; server checks root equality and bound interval unit/dose; corrections retain targets |
| Unsupported | Distance/open/manual-lap/nested/circuit target shapes, conflicting capture modes, unresolvable source/step/exercise, malformed cursors and v3 adaptations refuse |

The interval result's historical `paceSecondsPerKm` JSON field is reused with its explicit
`paceUnit`; `sec_per_500m` therefore means seconds per 500 m, never an implicit per-km value.
Existing per-km inputs/outputs remain unchanged. SQL canonicalisation adds that dimensional
unit in a new migration; older migrations, B2 functions/policy and all package hashes/goldens
remain untouched. No C1/C2/C3 prescription eligibility or new observational contract is added.

Fresh/repeat local fixture publication is an administrative test operation on disposable
resources, not a real publication producer. App authentication uses genuine loopback signed
JWT requests for reserved synthetic users; no real athlete data is contacted. UI tests use
injected transports, while the independent local E2E test uses actual default repositories,
loader, server, persistence and completion. No installed interactive walkthrough is claimed.
