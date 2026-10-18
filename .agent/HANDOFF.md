# Handoff — start here

Read this first. For full detail on any claim below, see `.agent/IMPLEMENTATION_STATE.md`
(the authoritative, continuously-updated engineering log). The current mission's original text
is preserved at `.agent/mission_2026-10-16.md`.

## Where things stand right now

> **UPDATE 2026-10-17 (Session 4):** the owner's starting point is now commit **`32df13f` = Build 75**
> (tag `baseline-build-75-user-confirmed`). `main` HEAD `25dbffe` = Build 76 is **untrusted** (owner
> reported wrong behavior; tag `build-76-untrusted`). Work continues on branch `phase-b/from-32df13f`.
> See "Session 4" in `.agent/IMPLEMENTATION_STATE.md` for the review findings and next steps.
> Black-screen cause + fix: see "Build 76 black screen" in the state file. Test the newest green branch build (**`build-82`**, else `build-81`) first. Build 78 was the black-screen fix and opens fine; 81/82 add Phases B+C. Do NOT merge to `main` before the owner confirms on device.
> The text below predates this and is kept for history.

- **User-confirmed working baseline:** commit `9f904c6`, tag `baseline-build-66`, GitHub release
  `build-66`. The user manually installed this exact APK and confirmed it works. Never
  force-push or rewrite history over this commit.
- **Current recommended starting point:** commit `003d8cb`, tag `baseline-build-74-ci-verified`,
  GitHub release `build-74`. Identical application behavior to build #66 — the only difference
  is CI now actually runs `flutter analyze` + `flutter test` before building (it never did
  before this was fixed; see "Gotchas" below). Build #74 is genuinely green: analyzer clean
  (0 errors/warnings), 46/46 tests pass, APK built successfully.
- `main` is currently at `003d8cb`, same as the tag above.

## The active mission

`.agent/mission_2026-10-16.md` — 12-phase brief covering: fixing chat command understanding
(highest priority), automatic reminders/commitments being over-eager, supplier archiving,
notification settings vs. notification center confusion, the Memory screen's Reminders/
Commitments cards not navigating, documenting (not yet building) the Brief feature's future
report roadmap, confirming offline+API-key both work, auditing Android/iOS build scaffolding,
and fixing CI test reliability.

**Only Phase A (baseline verification, safety references, this documentation) is done.**
Phases B-F — the actual feature and bug-fix work (items 1-5, 8's fixes if any are warranted,
and 9's new tests) — **have not been started.** `.agent/IMPLEMENTATION_STATE.md`'s "Future /
deferred roadmap" section has the per-item breakdown and what little Phase-A investigation
already happened (mainly item 8: confirmed `android/` was never committed on purpose, and `ios/`
has simply never existed — neither is an accidental deletion).

## Gotchas learned this session — read before you re-debug these

1. **`android/` and `analysis_options.yaml` are never committed** — CI regenerates them every
   run via `flutter create --platforms=android ...`. This used to silently regenerate a default
   `test/widget_test.dart` too, which referenced a nonexistent `MyApp` class (the real root
   widget is `ManagerApp`) and would fail `flutter analyze`. Fixed: that step now deletes
   `test/widget_test.dart` right after `flutter create` runs, every build.
2. **`flutter analyze` runs with `--no-fatal-infos`** — there are 55 pre-existing style-only
   lints (`prefer_const_constructors` etc.) from before analyze was ever enforced. Fixing those
   is a legitimate future cleanup, but it's a broad, unrelated refactor for any single feature
   task — don't let it block an unrelated change. Real errors/warnings still fail the build.
3. **An unresolved oddity**: a `StorageService.setApiKey` call (goes through a static
   `_serialize`/`_gate` write-queue) did not appear to execute at all when invoked from inside a
   `testWidgets` callback — not just slow, genuinely never resumed even after 20 real 100ms
   pumps. The identical call works reliably from plain `test()` functions in the same file. Full
   diagnostic trail is in `.agent/IMPLEMENTATION_STATE.md` under "CI gap closed", builds #70-73.
   Never got to the bottom of it with print-statement debugging alone; needs real Dart tooling
   (debugger/DevTools). The regression guard it was going to strengthen was narrowed to avoid
   that path instead (`test/storage_and_error_test.dart`, the Gemini-key `testWidgets` test) —
   it still catches the actual regression (the Settings field being deleted) without depending
   on the unresolved interaction.
4. **No Flutter/Dart SDK in a plain `bash_tool` sandbox** — `flutter`/`dart` both report "not
   found". All verification has to go through pushing to `main` and polling the GitHub Actions
   API / downloading `build_log_tail.txt` from the `debug-N` release GitHub Actions publishes on
   failure (`if: failure()` step in the workflow). Budget real wall-clock time for this — each
   round trip is roughly 1.5-3 minutes.
5. **A failed `flutter analyze`/`flutter test` step correctly skips the later `Build APK` step**
   (no `if:` conditions on any step) — so a red build genuinely produces no APK, only a
   `debug-N` log release. Don't assume an APK exists just because a workflow run shows up;
   check the run's `conclusion` and, for an actual artifact, that a matching `build-N` release
   (not `debug-N`) has an `app-release.apk` asset.

## Access

GitHub classic PAT used this session for clone/push/Actions-API access was supplied inline in
chat. **Rotate/revoke it** once you no longer need it from this exact token — it was never
written into any file in this repo, only used directly against the GitHub API/git remote URL.
