# Next decision: existing duplicate and operation guard

**Proposal only. No guard, catalogue record or credential changed by this proposal.**

The connection dependency is resolved. The current validate_snapshot() requires
every non-null catalogue slug to be globally unique. Actual schema has only the
exercise-ID primary key/index; no unique slug constraint exists. The full inventory
has published EX-029 and EX-141 sharing bulgarian-split-squat, with different
equipment and unknown setup/execution. Neither is one of the three approved setups.
Their incomplete fields do not prove interchangeable meanings.

The committed 20260821120000_apollo_build_week1_executable_protocols.sql explicitly
seeds EX-141 with that slug and references its ID. This is local historical source,
not proof of the original hosted actor/time. Altering or merging these two rows
would need a separate identity/consumer decision; no such mutation is proposed.

Recommended next authority: **a bounded local compatibility review/correction of
the global slug-uniqueness assumption**, preserving both legacy rows and consumers.
Review the specification and code together; do not relax the live safeguard ad hoc.

Reviewable acceptance contract for that separately authorised slice:

- Retain every existing duplicate group as immutable protected pre-state.
- Review exact target setup candidates across the complete inventory. Ambiguous
  target reuse remains refused; names/slugs never become identity authority.
- Require every new planned ID/slug to be distinct and absent from every existing
  row, including duplicate groups. Protect EX-026/037/090 without enrichment.
- Preserve exact full-inventory/schema/consumer checks under the existing holds,
  whole-transaction refusal, exact replay and same-ID unknown-outcome recovery.
- Prove the real EX-029/EX-141 baseline stays unchanged through prepare, transaction,
  replay and independent readback. Test target collision/ambiguity, changed duplicate
  membership, partial/mismatched state and a competing insert.
- Keep the three source semantics, write-set/source pins and genuine receipt/audit
  rules. Do not invent definition versions/events.
- Document/test normal explicit session SET ROLE postgres over the existing
  authorised membership; service startup role options alone were ignored here.
- Finish local verification before asking for one newly authorised live login.
  The original single login was consumed and revoked; no replacement is authorised.

Founder action if continuing: authorise that specific local guard-compatibility
slice. This authorises neither hosted duplicate repair nor another credential.
D8, publication and the installed real-programme journey remain separate.
