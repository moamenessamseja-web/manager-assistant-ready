# ARCHITECTURE.md — current architecture (2026-10-22, branch `phase-b/from-32df13f`)

Flutter (3.47.7 pinned) Arabic-first, offline-first app. No backend, no external AI. Data in SharedPreferences. Android only in CI.

## Layers
- `lib/main.dart` — startup: init Storage/Error/ChatHistory/Settings/NotificationPrefs/timezones, then guarded notification init, `ReminderService.rescheduleAllActive`,
  `RulesService.checkAndTrigger`, `runApp`. A storage-init failure shows a readable error screen (never a black screen).
- `lib/models/` — `Commitment`, `Reminder`, `FollowUpRule`, `Employee`, `Supplier` (+`Delivery`, `SupplierPurchase`), `Customer` (+`CreditSale`, `CustomerPayment`), `CommandResult`.
- `lib/services/`
  - **Storage**: `storage_service` (+ `app_state` change notifier, `app_error_service`, `idempotency_service`, `chat_history_service`, `conversation_context_service`, `settings_service`).
  - **Understanding**: `local_command_parser` (normalize, intents, entities, dates/times, `extractSlots`) → `assistant_controller` (resume pending → parse → `_runLocal`
    missing/ambiguity → dispatch) ; `choice_builder` (chips from pending state).
  - **Reminders/notifications**: `notification_service` (+`NotificationBackend` seam) · `reminder_service` · `rules_service` · `reminder_manager` (UI facade) · `recurrence` (pure) · `notification_prefs`.
- `lib/screens/` — `main_shell` (6 tabs: Today, Chat, Memory, Receivables, Staff, Suppliers; drawer: Rules & Notifications, Brief, Settings, Instructions), per-feature screens,
  `ask_assistant` (shared mini-chat sheet), `reminder_editor` (alarm-style editor), `memory_lists` (read-only lists).
- `lib/design/` — tokens, theme, widgets, `format.dart`, `strings.dart` (L.t).

## Reminder / commitment data flow
```
 Chat ("فكرني…")  ─┐                         ┌→ Today / Memory lists / Rules screen (read StorageService)
 Sidebar editor   ─┼→ Commitment(type task) ─┤
 Supplier delivery ┘   + Reminder(status) ───┴→ ReminderService → NotificationService.scheduleSeries → Android alarms (exact if allowed)
 Rules screen → FollowUpRule ── syncRule ──→ Reminder(recurrence, anchor) → series of future notifications
 App open: rescheduleAllActive (re-arm) → checkAndTrigger (past occurrences → Commitment(type rule), advance nextDue, syncRule)
```
## Navigation facts
- Tab titles in `main_shell._buildAppBar` are **hard-coded strings** (not `L.t`) — change them there when swapping a tab.
- Bell → `NotificationDebugScreen` (diagnostics/status). Notification *behaviour* settings → `NotificationSettingsScreen` (from Rules screen AppBar).
- Memory cards: Employees/Suppliers → their screens; Reminders/Commitments → `RemindersListScreen` / `CommitmentsListScreen`.

## Known architecture limits (honest)
SharedPreferences holds whole lists (fine for hundreds of records, not years of data) · `tz.local` = UTC · exact alarms depend on user permission ·
reboot persistence relies on the plugin's boot receiver (not device-verified) · idempotency covers chat messages and Today receipts only.
