# HANDOFF.md — 60-second start

1. Read `README.md` (index) → `ENGINEERING_RULES.md` (how to work, definition of done) → `IMPLEMENTATION_STATE.md` (where we are).
2. **Test target for the owner now: `build-93`** (branch `phase-b/from-32df13f`). Last owner-confirmed on device: build 92 (branch) and build 87 (`main`).
3. Owner's current task list (priority order): (1) sidebar reminders/notifications that really work, with alarm-style time picker — **implemented in build 93, awaiting device test**;
   (2) Dues page heading + time beside day/date — **implemented**; (3) review `.agent` files — **done 2026-10-22**; (4) chat NLU — **later**.
4. Do not: merge to `main` before the owner's OK · change package id/signing · re-add external AI · claim device verification you did not get · commit secrets.
5. Environment: no Flutter SDK in the sandbox; everything is verified through GitHub Actions (see `ENGINEERING_RULES.md` §6). Access token is supplied by the owner in chat each session; never persist it.
