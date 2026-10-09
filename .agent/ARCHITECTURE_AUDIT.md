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
