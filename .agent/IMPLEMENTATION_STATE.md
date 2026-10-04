# Implementation State

Last completed phase: Closed the 3 known open items from Phase 4 checkpoint (brief_screen.dart, memory_screen.dart, reminder_service.dart + main.dart). code commit: 7dc9fb4
Current phase: verified green on CI (build-18)
Build #18: GREEN on GitHub Actions. APK: https://github.com/moamenessamseja-web/manager-assistant-ready/releases/tag/build-18 (not yet manually tested by user as of this checkpoint).
Next phase: WAIT FOR ARCHITECT'S NEXT TASK — do not start a new feature.

## Resolution of the 3 open items

- **Weekly Brief archived handling = RESOLVED.** brief_screen.dart: active totals (counts, advances, supplier balance, pending deliveries) already excluded archived employees/suppliers (since Phase 1) — confirmed still correct. Also fixed a real correctness bug found while verifying this: the "متأخرات عند العملاء" total was summing ALL overdue commitment types (debt_to_collect, supplier, rule, task...) instead of just debt_to_collect — now filtered correctly. Added a new, clearly-labeled "مؤرشفين وعليهم مستحقات قديمة" section showing archived suppliers/employees that still have an outstanding balance, so historical data is surfaced rather than silently dropped, without distorting the active summary. No records deleted or mutated.

- **Memory archived indication = RESOLVED.** memory_screen.dart: archived employees/suppliers in search results now show an explicit `AppBadge('مؤرشف', kind: warning)` trailing widget, using the existing design system, RTL-correct by default (ListTile.trailing). Active records unaffected. Commitments have no archived concept (unchanged, correct — only Employee/Supplier are archivable).

- **Boot Receiver / reminder rescheduling after reboot = PARTIAL — NOT fully resolved, documented blocker.** Implemented `ReminderService.rescheduleAllActive()`, called on every app launch (main.dart), which re-arms every enabled+status=='scheduled' Reminder whose dueAt is still in the future, through the existing `NotificationService.scheduleAt` (same code path, idempotent — same reminder id replaces its own prior OS-level alarm, does not duplicate). This recovers from reboot/alarm-clearing *if the user reopens the app before the reminder's due time*. It is explicitly NOT a true native BOOT_COMPLETED receiver and does NOT guarantee delivery for a reminder whose due time passes while the app has not been reopened after a reboot.
  **Architectural blocker (documented, not worked around):**
  1. `android/` is not committed to this repo — it is regenerated fresh by `flutter create` in the CI workflow on every build, so there is no persistent location in source control for a custom native Android receiver class without either committing the android/ folder (a real architecture change) or injecting native source via the CI workflow script.
  2. Even if a native Kotlin `BroadcastReceiver` for `BOOT_COMPLETED` were added, it cannot call back into the Dart `ReminderService`/`NotificationService` without a headless Flutter execution mechanism (e.g. `android_alarm_manager_plus`'s callback-dispatcher pattern), which would introduce a second, parallel scheduling architecture — explicitly disallowed by this task's constraints ("do not create a second reminder architecture", "do not duplicate reminder scheduling logic").
  3. Re-arming alarms purely natively (without Dart) would require reverse-engineering `flutter_local_notifications`' private, undocumented native `PendingIntent`/`ScheduledNotificationReceiver` internals — unsupported and fragile, and would itself be "inventing a workaround architecture."
  Per this task's own contingency instruction, this was treated as a genuine architectural blocker: documented here, the safe partial mitigation was shipped, no workaround architecture was invented, and the other two tasks were completed.

## Notification issue reported by product owner
**OPEN / DEFERRED.** Not investigated, not touched, not redesigned in this task, per explicit instruction.

Last successful commit: 7dc9fb4 (build-18 APK)
Last successful build: run 18
Current known issues: none blocking beyond the documented Task 3 partial scope and the deferred notification issue above.
Database migration status: unchanged since Phase 1 (SharedPreferences JSON; archived field; reminders key).
AI pipeline status: unchanged — NOT modified in this task per explicit instruction.
Reminder pipeline status: unchanged architecture; added one new read-path consumer (rescheduleAllActive) that reuses NotificationService.scheduleAt — no duplication.
Notification status: unchanged core logic — NOT modified in this task per explicit instruction; the reported notification issue remains open/deferred.
Recovery instructions: git log; fix CI errors from the run log (debug-N release)
