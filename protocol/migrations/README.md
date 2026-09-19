# Migrations

Empty at `0.1.0` — there is nothing to migrate from. This directory exists so that the
obligation is visible rather than remembered.

Per [SPEC.md §2.3](../SPEC.md):

- Every **minor** bump before 1.0 MUST add `<from>-to-<to>.md` here, describing every
  changed field and how to convert an existing document.
- Every **major** bump MUST ship either an automated converter or a documented rollback
  path kept available for at least one release cycle.
- A version bump proposed without its migration artefact is not a valid proposal.

This is the technical form of the constitutional principle *Protection of existing work*.
