# Future external-author boundary (M9)

Not implemented: no coach accounts, invitations, or publishing UI.

Required later:

| Field | Rule |
|-------|------|
| Owner / author | user id at draft create |
| Publisher | namespace (`cohort_global`, coach, org) |
| First-party | `library_scope=cohort_global`, `owner_type=global` |
| External | coach/org namespace only |
| Visibility | catalogue flag ≠ publication |
| Publication | authorized publisher only |
| Moderation | deferred |
| Transfer/export | must preserve immutable attribution |
| Isolation | no private cross-namespace reference without grant |
| Account deletion | must not destroy assigned athlete history |

Sprint 1 fixture `publisher.acme-coach` exists only to prove denial.
