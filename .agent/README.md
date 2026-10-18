# .agent/ — start here (every session, human or AI)

All working documents live in this folder. **Read in this order, update them after every green build:**

1. `Implementation_Plan_and_Development_Instructions.md` — the owner's standing brief (the target). Source of truth for *what to build and in what order*.
2. `IMPLEMENTATION_STATE.md` — operational checkpoint: verified baseline, latest build, blockers. Newest "Session" section wins over older text.
3. `HANDOFF.md` — short pointer to the current branch/build to test and the rules not to break.
4. `implementation.md` — inventory of what exists in code now, each item with an honest status.
5. `CHANGELOG.md` — what was actually changed (completed work only).
6. `mission_2026-10-16.md` — the earlier 12-phase mission (Phases B–F done on branch `phase-b/from-32df13f`; see state file).
7. `ARCHITECTURE_AUDIT.md`, `VERIFICATION_REPORT.md` — older audits (historical).

Rules: never claim a device test that was not run · baseline = Build 82 `fea404f` (owner-confirmed) · no merge to `main`, package-id,
signing or Play change without the owner's explicit say-so · secrets never in the repo.
