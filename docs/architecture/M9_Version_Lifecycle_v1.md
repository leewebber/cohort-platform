# M9 version lifecycle

```mermaid
stateDiagram-v2
  [*] --> draft: create / clone
  draft --> draft: edit / validate / compile / diff
  draft --> published: publish (hash, immutable)
  published --> retired: retire (hide from new enrolment)
  published --> published: catalogue default / visibility only
  retired --> retired: remain readable for pins
  draft --> [*]: delete if unreferenced
```

Legal: draft edits; draft→published; published→retired; catalogue visibility toggles that do not mutate hashed content.

Illegal: published content edit; published→draft; hard-delete while assignments exist; dynamic “follow latest” at execution.

Authorization: first-party publisher for `cohort_global`; external publisher only inside own namespace; readers have no mutations.
