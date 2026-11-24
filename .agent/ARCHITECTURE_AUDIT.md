# Architecture Audit — commit 7325737

## Framework & Language
- Flutter 3.24.0, Dart 3.5.0
- SharedPreferences-based persistence (no SQLite/Drift)
- No Riverpod/Bloc/Provider — simple ChangeNotifier (AppState)

## Key Dependencies
- flutter_local_notifications: ^17.2.3
- timezone: ^0.9.4
- http: ^1.2.2
- shared_preferences: ^2.3.2
- speech_to_text: ^7.0.0
- uuid: ^4.5.1

## Data Model
- Employee, Supplier, Commitment, Reminder, Rule — all flat JSON in SharedPreferences
- No formal migrations (all flat JSON, additive changes only)
- Reminder is a standalone entity, decoupled from Commitment

## AI Pipeline
- Gemini Flash-Lite via REST API (gemini-3.5-flash-lite)
- Structured JSON output via `responseMimeType: application/json`
- Intent → AssistantController action switch → StorageService writes
- Entity resolution: exact substring match (vulnerable to diacritics/variants)

## Notification Pipeline
- flutter_local_notifications: zonedSchedule with inexactAllowWhileIdle
- AndroidScheduleMode: inexactAllowWhileIdle
- Timezone initialized via timezone package before scheduling
- Boot recovery: ScheduledNotificationBootReceiver (native plugin receiver, injected via CI)
- Core library desugaring: enabled in CI workflow

## State Management
- AppState (ChangeNotifier) — single global notifier
- All StorageService saveXxx() call AppState.instance.notify()
- ListenableBuilder in main.dart wraps MaterialApp
- Individual screens (StaffScreen, TodayScreen) use setState() — needs to also listen to AppState

## Navigation
- 6 screens: Today, Staff, Suppliers, Brief, Memory, Chat
- Bottom navigation in MainShell
- Navigator.push for detail screens

## Known Issues (pre-fixes)
1. schedule_failed / Missing type parameter — likely R8 stripping Gson generics in release
2. Arabic entity resolution — no normalization in employeesMatching/suppliersMatching
3. StaffScreen doesn't listen to AppState — stale after Chat mutations
4. Weekly Brief — static display, no interactive navigation
5. Memory screen — search only, no business overview on empty query

## Session 5 notes (2026-11-21)
- Receivables truth = `Customer` ledger (sales − payments). Legacy `debt_to_collect` commitments are a separate,
  older concept; they are displayed separately and are never summed with ledger balances.
- Periods are half-open `[from, to)`; weeks start on Saturday; opening balances are excluded from period movement.
- Signing lives in the app's own workflow, not in the shared gateway (which has no secret support). Release builds
  refuse debug signing and refuse an unexpected signer when `EXPECTED_SIGNER_SHA256` is set.
- Risk: the Android project is generated in CI and patched by shell appends; any Flutter template change can break
  the patches. The guard steps and the selftest exist to catch that early.

## Session 6 — field-driven branch audit (2026-11-24)

- Starting ref: `feature/field-driven-v2` @ `052c96c`; work branch created from this exact ref.
- Confirmed actual persistence remains `SharedPreferences` with JSON-serialized entity lists and scalar settings. No database replacement was introduced.
- Confirmed current services/models cover backup snapshot validation + SHA-256, safety backup + rollback, shift snapshots, optional daily closing over shift snapshots, shortages, café profile, and audit log.
- Daily closing detail was improved to expand each shift into its full financial totals breakdown.
- Existing design caveat retained for follow-up: `ShiftTotals` records the financial categories present in the current data model; this is not a full accounting/profit engine. Reports must continue labeling net cash movement as cash movement, not profit.
- Latest CI status is pending; run #99 had 8 widget failures after analyze passed, and run #100 predates the last test fixes. See `VERIFICATION_REPORT.md`.
