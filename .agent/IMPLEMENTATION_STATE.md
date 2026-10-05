# Implementation State

## Branch: agent/sonnet/product-progress — Today Dashboard product-progress slice

code commit: d869042 ("feat: redesign today dashboard — greeting + AI quick-capture entry point")
Branch: agent/sonnet/product-progress (main untouched, per instruction)
Build #22: GREEN — triggered manually via workflow_dispatch against this branch (the workflow only auto-triggers on push to main, so a manual dispatch was used to verify without touching main). APK: https://github.com/moamenessamseja-web/manager-assistant-ready/releases/tag/build-22

### Why this slice
Inspected the Master Brief V2 Phase 4 checklist (greeting / needs attention / daily summary / tasks / due payments / attendance issues / alerts / quick actions / AI entry point) against the Today screen as it stood after the earlier Phase 4 pass. Found: needs attention, daily summary (badges), tasks, due payments, attendance issues, alerts, and quick actions (done/postpone) were already implemented and wired to real data/ReminderService. Two items were genuinely absent: **greeting** and **AI entry point**. Chose this as the smallest coherent vertical slice because it closes a real gap against the product's own stated philosophy (chat-first input) without touching anything already working.

### What changed
Only `lib/screens/today_screen.dart`.
1. Time-aware Arabic greeting ("صباح الخير" / "مساء الخير" / etc.) + Arabic date line (hand-rolled weekday/month name arrays — no `intl` locale initialization added, to avoid a runtime locale-data risk with zero existing `ar` locale setup in the project).
2. A quick-capture input card at the top of the dashboard, wired directly to the **existing** `AssistantController.handle(text)` — the exact same entry point the Chat tab uses. No new AI/NLU logic. Lets the owner log a debt/task/supplier/employee item without leaving Today. Result surfaced via `SnackBar` (same confirmation pattern already used in `settings_screen.dart`); the dashboard recomputes from `StorageService` afterward so the new item appears immediately in the correct section (overdue/today/upcoming) — no new data path, same read-after-write pattern used elsewhere in the app.
3. Voice input deliberately NOT added to this quick-capture bar (kept text-only) — speech-to-text remains on the dedicated Chat tab. Explicit scope boundary to keep this a small, low-risk slice; not a capability gap, since voice is already available one tab away.

### Verification performed
- Full-repo brace/paren/bracket balance check (no local Dart SDK available in this environment — unchanged constraint from all prior tasks).
- `git diff --stat` confirmed only `lib/screens/today_screen.dart` changed — no business logic, storage, Reminder, notification, AI pipeline, or other-screen files touched.
- Pushed to `agent/sonnet/product-progress` (main untouched) and manually dispatched the existing CI workflow against that branch ref — build #22 completed with conclusion `success`.
- Not performed: on-device/manual UX testing of this specific slice (product owner has build-22 available to test, same as prior builds).

### Known limitation / explicit scope boundary
Voice input not wired into the Today quick-capture bar (text-only). Greeting/date are locale-independent hand-rolled strings, not using `intl`'s Arabic locale data (acceptable for this scope; would need `initializeDateFormatting('ar')` if the project later adopts `intl`-based Arabic date formatting elsewhere).

---

## Task 3 — True Android BOOT_COMPLETED / reboot resilience: RESOLVED

code commit: 6e32717 ("fix: harden reminder rescheduling across reboot")
Build #20: GREEN on GitHub Actions. APK: https://github.com/moamenessamseja-web/manager-assistant-ready/releases/tag/build-20

### What changed
Only `.github/workflows/build-apk.yml` — no Dart files, no new pubspec dependency, no custom native source files.

1. Added `android.permission.RECEIVE_BOOT_COMPLETED` to the existing, already-proven `<manifest>`-level permission injection loop (same mechanism used since Phase 1 for RECORD_AUDIO/POST_NOTIFICATIONS/INTERNET — no new injection mechanism invented).
2. Added a new CI step "Register flutter_local_notifications boot receiver" that injects two `<receiver>` elements as children of `<application>`:
   - `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`
   - `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver` (intent-filter: BOOT_COMPLETED, MY_PACKAGE_REPLACED, QUICKBOOT_POWERON)

### Why this is a genuine native boot mechanism, not app-launch rescheduling
`flutter_local_notifications` (already a pubspec dependency, no new package added) ships these two receiver classes inside its own Android library. `ScheduledNotificationBootReceiver` is a real `BroadcastReceiver` registered for `android.intent.action.BOOT_COMPLETED` at the OS level. On boot, Android itself invokes it — no app process, no Dart/Flutter engine, no app having been opened. It re-arms the plugin's own natively-persisted pending notification requests (persisted by the plugin itself, natively, when `zonedSchedule` was originally called from Dart) directly through `AlarmManager`. This does not require headless Dart execution and therefore does not introduce a second/parallel scheduling architecture — it reuses the exact same underlying plugin that `NotificationService.scheduleAt` already calls.

### Why this survives CI regenerating android/ every build
`android/` is not committed to this repo; it is generated fresh by `flutter create` in CI on every run (established fact, unchanged). The fix is therefore in the CI workflow itself (the one piece of this project that IS persistent and version-controlled), using the exact same injection pattern already proven stable across builds 9–20 for permissions and Gradle desugaring: idempotent `grep -q` guard + `sed -i` insertion anchored on a literal line verified against Flutter's actual current AndroidManifest.xml.tmpl source (fetched directly from `github.com/flutter/flutter` to confirm exact structure before writing the sed anchor — not guessed).

### Idempotency
Guarded by `grep -q "ScheduledNotificationBootReceiver" "$MANIFEST"` before inserting — re-running the step (e.g. workflow re-run) does not duplicate the receiver block. The receivers themselves only re-arm the plugin's own already-persisted pending requests on boot; they do not create new Reminder entities, so no duplicate reminders are produced.

### Verification actually performed
- Fetched the real, current `AndroidManifest.xml.tmpl` from `flutter/flutter` on GitHub (not assumed) to confirm `<manifest>` is single-line (existing anchor still valid) and `<application ...>` is multi-line, closing at the literal line `android:icon="@mipmap/ic_launcher">` — used that exact line as the receiver-insertion anchor.
- Ran the exact sed commands used in the workflow locally against that real fetched template and confirmed the result is well-formed XML (`xml.dom.minidom` parse succeeded) with `<uses-permission>` correctly placed as a child of `<manifest>` and both `<receiver>` elements correctly placed as children of `<application>`.
- Tested idempotency locally: running the injection twice does not duplicate the receiver block.
- Pushed to CI: build #20 completed with conclusion `success` (GitHub Actions). A malformed manifest (wrong XML nesting, broken syntax) would have failed `flutter build apk` at the manifest-merge/aapt2 step, so this is corroborating evidence the real CI-generated manifest was valid.
- **Not performed / not possible in this environment:** could not fetch the raw CI job log text directly (GitHub Actions log storage redirects to an Azure Blob Storage domain not reachable from this sandbox's network allowlist, and the sandbox's web_fetch tool only permits URLs sourced from a prior search/fetch, not from a bash/curl result) — so the exact printed CI-generated manifest was not visually re-inspected line-by-line; local verification used the identical real upstream template fetched directly from GitHub as a substitute.
- **Physical reboot verification unavailable in this environment.** No Android device or emulator exists in this sandbox to actually reboot and observe notification delivery. This was NOT verified end-to-end on a real device. The user (product owner) is the only one who can perform that physical test on the next APK they install.

### Known limitation
This resolves the *mechanism* (a genuine, OS-level, native boot receiver bundled in the already-used plugin, correctly registered via a CI path proven durable across regeneration). It has not been physically device-tested through an actual reboot cycle. `ReminderService.rescheduleAllActive()` (added in the prior task, called on app launch) remains in place as an additional defense-in-depth safety net and was not removed.

## Task 1 — Weekly Brief archived handling: RESOLVED (unchanged from prior checkpoint — not touched in this task)
## Task 2 — Memory archived indication: RESOLVED (unchanged from prior checkpoint — not touched in this task)

## Notification issue reported by product owner
**OPEN / DEFERRED.** Not investigated, not touched in this task, per explicit instruction.

Last successful commit: 6e32717 (build-20 APK)
Last successful build: run 20
Current known issues: none blocking. Physical reboot behavior not yet confirmed by the product owner on a real device.
Database migration status: unchanged.
AI pipeline status: unchanged — NOT modified.
Reminder pipeline status: unchanged Dart architecture; the only addition is the native boot receiver registration at the CI/Android-manifest level, which reuses the existing flutter_local_notifications scheduling path with zero Dart-side changes.
Notification status: core scheduling logic unchanged — NOT modified; the reported notification issue remains open/deferred.
Recovery instructions: git log; fix CI errors from the run log (debug-N release)

Next action: WAIT FOR ARCHITECT'S NEXT COMMAND.
