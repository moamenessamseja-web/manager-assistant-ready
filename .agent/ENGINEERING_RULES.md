# ENGINEERING_RULES.md — how to work on Manager Assistant (read before coding)

Audience: any engineer or AI agent. The owner is **not a programmer**: explain results in plain Arabic, never ask for
routine technical decisions, never claim what was not verified.

## 1. What "done" means — UI-only vs a real feature
A screen that *looks* right is **not** a feature. This project already lost time to controls that rendered but did nothing
(e.g. the "Rules & Notifications" screen saved a rule record, but nothing scheduled a notification, created a reminder
record, or showed it in Memory). A feature is DONE only if **all** are true:
1. **Persisted**: written through `StorageService` (survives restart). Prove it with a test that re-calls `StorageService.init()`
   and re-reads the data.
2. **Consumed**: something actually reads it (a list, Today, Memory, a scheduler). A record nobody reads is a UI-only feature.
3. **Same pipeline as chat**: manual UI and chat must write the *same* records (`Commitment`, `Reminder`, `FollowUpRule`,
   `Supplier`, `Customer`...). Never create a parallel store "for the UI".
4. **Visible where the owner looks**: the relevant list + Today/Memory when applicable.
5. **Real effect**: e.g. an Android notification is really scheduled (assert on the `NotificationBackend` fake), not just a status string.
6. **Honest errors**: failures surface as a status the user can see (`permission_required`, `schedule_failed`, `inexact`),
   never "✅" for something that did not happen.
7. **Tested**: pure logic unit tests + at least one widget/flow test + a restart-persistence test. CI green (analyze + tests + APK).
8. **Verification level stated**: *CI-green* ≠ *device-verified*. Only the owner's manual install counts as device verification.

## 2. Reuse map — do NOT duplicate these
| Need | Use (file) |
|---|---|
| Save/read business data | `services/storage_service.dart` (SharedPreferences JSON lists, serialized write gate, corruption-tolerant) |
| Reminder/notification for anything | `ReminderService.createAndSchedule` / `syncRule` / `removeForEntity` → `NotificationService` |
| UI-facing reminder CRUD | `ReminderManager` (one-off = `Commitment(type:'task')` + `Reminder`; rule = `FollowUpRule` + synced series) |
| Recurrence / time math (12h↔24h, next occurrence) | `services/recurrence.dart` (pure) |
| Chat command execution | `AssistantController.handle` (local parser → validated dispatch). Chips: `ChoiceBuilder` + `handleChoice`. Replies to questions: `extractSlots` |
| Duplicate protection | `IdempotencyService` (message id / `receive:<id>` keys) |
| Notification toggles/lead time | `NotificationPrefs` |
| Money/date formatting | `design/format.dart` (`money`, `arabicDate`, `clockTime`, `clockTime12`, `arabicDateTime12`) — check it before writing a helper (a name clash with `money` once broke CI) |
| Lists/cards/empty states | `design/widgets.dart` (`AppCard`, `AppEmptyState`, `AppSectionHeader`) + `design/tokens.dart` |
Before adding a model/service/screen: `grep` for an existing one. Prefer extending over creating.

## 3. Notifications, reminders, scheduling, Android (verified facts)
- Plugin: `flutter_local_notifications 17.2.4` (`zonedSchedule`; needs `uiLocalNotificationDateInterpretation`). Flutter is **pinned 3.47.7** in CI.
- **Past times are never scheduled** (`scheduleSeries` skips them and reports `scheduled` with a "past" message). So any logic that creates
  a reminder *after* the due time delivers nothing — schedule **ahead of time**. (This was the original rules bug.)
- **Exact vs inexact**: inexact alarms can be delayed minutes+ under Doze. Exact needs `SCHEDULE_EXACT_ALARM` (CI injects it) *and* the
  user's "Alarms & reminders" special access on Android 14+. We use exact when `canScheduleExactNotifications()` is true, else fall back to
  inexact and report `message:'inexact'` → surfaced in the UI (`ReminderOutcome.inexact`, notification settings row with a "السماح" button).
  We deliberately do **not** use `USE_EXACT_ALARM` (Google Play restricts it to alarm/calendar apps).
- **Recurring reminders** = a pre-scheduled **series** of future one-off notifications (30 daily / 26 weekly / 12 monthly), ids from
  `NotificationService.seriesId(base,i)`; refreshed on every app open (`main.dart`: `rescheduleAllActive` then `RulesService.checkAndTrigger` → `syncRule`).
  Reason: `tz.local` is **UTC** in this app (`setLocalLocation` is never called) so `matchDateTimeComponents` (time-of-day repeats) would fire at the
  wrong hour. One-off absolute instants (`TZDateTime.from(dt, tz.local)`) are unaffected. Do not "fix" this with a hard-coded zone without owner approval.
- **Reboot**: CI registers `ScheduledNotificationReceiver` + `ScheduledNotificationBootReceiver` and `RECEIVE_BOOT_COMPLETED` (plugin re-arms stored
  alarms). `rescheduleAllActive` is a second layer at app open. Not device-verified after reboot yet — never claim it is.
- `android/` is **not committed**; CI regenerates it (`flutter create`) and patches manifest/gradle with shell. Manifest permissions live in
  `.github/workflows/build-apk.yml`. The applicationId is still `com.example.manager_assistant` (Play will reject it) — package id/signing change is the
  owner's explicit LAST step. Debug-signed APKs differ per run (installing over an old build can be refused; uninstall wipes data).
- Channel `manager_reminders`: importance/sound are fixed once the channel exists on a device (custom sound needs a new channel id + `res/raw`). Not implemented.
- Notification toggles (`NotificationPrefs`) only affect **new** reminders; categories: reminders / suppliers / rules.
- Status vocabulary for `Reminder.status`: `created → scheduled`, or `permission_required | channel_disabled | schedule_failed | cancelled`.
  Never invent new ones without updating `ReminderOutcome`, the bell badge, and `RulesScreen._status`.

## 4. Storage rules
- `StorageService` = SharedPreferences, lists of JSON strings, **all writes through `_serialize`** (a static gate). `init()` resets the gate.
- Additive JSON only (new fields need defaults in `fromJson`; see `Reminder.anchor`). Never wipe on a corrupt record. Never break old data.
- Keys in use: `commitments reminders rules employees suppliers customers` (+ `chat_history_v1 ctx_pending ctx_last_people idem_v1 notif_* notif_diag*`).
- SQLite is **deferred** by owner decision. If a limit needs it, document and propose; don't migrate.

## 5. Chat / language understanding rules
- Local, deterministic, **no external AI, no API key** (Gemini removed). Never guess a missing amount/date/hour/person: ask (chips preferred).
- Quantity ≠ money (`٢٠ كيلو` is a quantity). Day + explicit hour are required for reminders and expected deliveries; `الساعة ٥` without ص/م must ask.
- New phrasing → add to the parser **with a regression test**; do not scatter regexes in UI code. A bigger NLU effort (synonym registry or a library) needs a
  separate evidence-based proposal first (see the owner's plan §4/§7).
- The chat must not be the only way to do something. Every chat capability needs a manual path (sidebar/screens), sharing the same services.

## 6. Testing and regression (hard-won)
- **No Flutter/Dart SDK in the sandbox.** Verify only via CI: push branch → `workflow_dispatch` → poll → on failure download `debug-N` release
  `build_log_tail.txt` (decode as UTF-8 with `errors='replace'`, strip ANSI/control chars; piping Arabic through `cut`/`head -c` can break the tool).
- **Analyzer *warnings* are fatal; infos are not** (`--no-fatal-infos`). Unused imports/private functions, missing `await` in `try`, undefined names all fail the build.
- **`testWidgets` + storage** (this explained the unresolved hang of builds #70-73): inside `testWidgets` the body runs under FakeAsync. Storage writes need the
  real event loop. (a) seed data with `await tester.runAsync(() => StorageService.save…())`; (b) after a UI action that writes, run
  `for 6×: await tester.runAsync(delay 30ms); await tester.pump();` then `pumpAndSettle()` (helper `settleStorage` / `settle`); (c) a stuck write poisons the static gate for
  later tests (symptoms: 10-min timeout, "Reentrant call to runAsync") — `StorageService.init()` resets it.
- Plain `test()` is fine for service/storage logic. Inject `NotificationService.backend = FakeBackend()` for anything that schedules (restore it in `tearDown`).
- `ListTile` inside a decorated container needs a `Material` ancestor (assertion otherwise).
- Static state (`NotificationPrefs`, `IdempotencyService`, `AssistantController._last*`) leaks across tests: reset in `setUp`.
- Add a regression test for **every** bug fixed. A bug fixed without a test is not fixed.
- Pre-push checklist: bracket balance of edited Dart; imports used; no name clashes with `design/format.dart`; tests for the change; docs updated.

## 7. Process and communication
- Start every session: read `README.md`, `IMPLEMENTATION_STATE.md`, `HANDOFF.md`; inspect `git status/log` and the latest CI run. Trust code over docs; fix the docs when they lie.
- Work on a branch; `main` only receives builds the owner has tested (merge via `git merge -s ours`-style safe merge or fast-forward; never force-push; tag the old `main` first).
- After **every green build** update: `IMPLEMENTATION_STATE.md`, `implementation.md` (status per item), `CHANGELOG.md`, `HANDOFF.md`. Archive, don't delete, history.
- Final report to the owner: Arabic, plain language: what changed · what was **verified (CI)** · what needs **device testing** · what was deliberately not done · decisions needed.
- Secrets: the owner sometimes pastes a GitHub token in chat. Use it only via a transient `http.extraheader`; never write it to a file/remote URL/log; tell the owner to revoke it.

## 8. Owner-frozen / out of scope unless the owner says so
Package id & signing & Play publishing (LAST) · SQLite migration · reports/PDF · on-device LLM · external AI APIs · timezone behaviour · logo/visual redesign/login
(owner will do them) · iOS builds (no macOS CI).
