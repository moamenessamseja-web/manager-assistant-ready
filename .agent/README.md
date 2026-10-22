# .agent/ — start here (every session, human or AI)

All working documents live in this folder. **Read in this order; update the marked ones after every green build.**

| # | File | Purpose | Update when |
|---|---|---|---|
| 1 | `Implementation_Plan_and_Development_Instructions.md` | Owner's standing brief (verbatim — do not edit) | never (owner only) |
| 2 | `ENGINEERING_RULES.md` | How to work: definition of done (UI-only vs real), reuse map, notifications/Android facts, testing gotchas, CI/process | when a lesson is learned |
| 3 | `IMPLEMENTATION_STATE.md` | Current checkpoint: baselines, latest build, device-test checklist, next steps | **every green build** |
| 4 | `HANDOFF.md` | 60-second pointer: what to test, what not to do | **every green build** |
| 5 | `implementation.md` | Inventory: each feature + honest status + verification log | **every green build** |
| 6 | `ARCHITECTURE.md` | Current architecture & data flow | when structure changes |
| 7 | `CHANGELOG.md` | What actually changed (completed work only) | **every green build** |
| 8 | `mission_2026-10-16.md` | Historical 12-phase mission (executed; banner explains status) | never |
| 9 | `archive/` | Superseded docs kept for their diagnostic trail | never |

Non-negotiables: never claim a device test that was not run · `main` only gets builds the owner tested · no package-id/signing/Play change without the owner ·
secrets never in the repo · a screen that does not persist/schedule/show real data is **not** a finished feature.
