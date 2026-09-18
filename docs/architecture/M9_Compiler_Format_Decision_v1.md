# M9 compiler-format decision

**Keep Plan Package schema v1 frozen.** Apollo’s published `package_content_hash` must not change.

M9 Content Graph manifest format v1 is a **parallel** canonical JSON:

- `format_version: 1`
- programme id (not version UUID)
- ordered placements by week/day/slot
- session-template-version IDs + source hashes
- block positions, `EX-*`, prescriptions
- SHA-256 lowercase hex
- no timestamps, no generated row UUIDs, no environment values

Unresolved or ambiguous references fail publication. Identical structural hashes reject redundant publish.

If Plan Package later gains exercise identities, that is **schema v2** with an adapter — never a silent reinterpretation of v1 hashes.
