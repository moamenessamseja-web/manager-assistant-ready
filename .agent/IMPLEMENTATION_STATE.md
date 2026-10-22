# IMPLEMENTATION_STATE.md — current checkpoint (2026-10-22)

Older sessions' detailed log: `archive/IMPLEMENTATION_STATE_history_sessions_1-4.md` (diagnostic trail; partly superseded). Rules for working: `ENGINEERING_RULES.md`.
Architecture: `ARCHITECTURE.md`. Per-item statuses: `implementation.md`.

## Baselines and branches
- `main` = `667ebc7` (Build 87) — **last owner-confirmed on device**. Rollback tag for the old broken main: `main-before-merge-build76`.
- Branch `phase-b/from-32df13f`: owner-confirmed **`1565f25` (Build 92: Gemini removed + Receivables tab)**; latest CI-green = **Build 93** (reminders/notifications rebuild) — **not yet device-tested, not merged**.
- Rule: merge branch → `main` only after the owner tests the newest build.

## What Build 93 changed (CI-green, not device-verified)
Owner priority #1 (sidebar must be a real, chat-independent reminder manager):
- **Root causes found**: `RulesService` ran only at app open and created reminders for *already past* occurrences (never scheduled) → rules never notified;
  scheduling was inexact-only; recurrence ignored; the Rules screen only wrote a rule record (no Commitment/Reminder, nothing in Memory).
- **Fix**: `NotificationService` (testable backend, exact alarms when allowed, series for recurring), `ReminderService.syncRule/removeForEntity/delete`,
  `RulesService` rebuilt, `ReminderManager` facade (create/edit/delete/done for one-off; create/edit/toggle/delete for rules), `Recurrence` (pure).
- **UI**: Rules & Notifications = 2 tabs (تذكيرات / قواعد متكررة) with real status per item; editor dialog on the existing alarm FAB with **date picker + hour/minute/ص-م**;
  exact-alarm status + "السماح" button in notification settings; CI adds `SCHEDULE_EXACT_ALARM`.
- **Dues (المستحقات)**: AppBar title was hard-coded "بريف الأسبوع" in `main_shell` → now "المستحقات"; page had no date line → added day/date + live 12h time (ص/م).
  (Note: 12h ص/م was used to match the alarm editor; existing screens still show 24h `clockTime`. Central helpers: `clockTime12` / `clockTime`.)
- **.agent review (priority #3)**: this folder restructured — see `README.md`.
Tests: `test/reminders_test.dart` (recurrence math, scheduling backend, one-off CRUD + restart persistence, rule series, app-open catch-up, editor widgets).

## Needs owner device test (not verifiable in CI)
1. Create a one-off reminder 2-3 min ahead from the sidebar → notification arrives on time; appears in Memory → Reminders/Commitments and Today.
2. Edit its time → old one cancelled, new arrives. Delete → no notification.
3. Weekly/daily rule → arrives at the chosen hour **with the app closed**. Check "المنبهات الدقيقة" row in notification settings (grant if off).
4. Reboot the phone, then see whether a pending reminder still fires (plugin boot receiver — never verified).
5. Dues page title + date/time line.

## Open items / next
- Chat NLU improvement (owner's item 4): later; must not block sidebar reminders. Candidates: synonym/phrase registry with fixtures, or a vetted library (needs evidence per plan §7).
- Customer chat intents (credit sale / payment), backup/restore, money-vs-quantity chips, repository layer, remove `INTERNET` after a voice test.
- LAST: package id (`com.example…` is rejected by Play) + fixed signing key — owner decision. Owner's own later work: logo, internal design, start page + password login.
- Known limits: `tz.local`=UTC (series approach avoids it), notification toggles affect new reminders only, idempotency covers chat + Today receipts only, 12h vs 24h inconsistency noted above.

## Build log (this branch)
75 baseline · 76 black screen (plugin drift) · 78 fix · 82 pin · 84 chips (owner OK) · 86 Today/Brief/instructions/idempotency · 87 main (owner OK) · 88-91 red (test-zone/name-clash/ListTile) · 92 Gemini removed + Receivables (owner OK) · 93 reminders rebuild (green, untested on device).
