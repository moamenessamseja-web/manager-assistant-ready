# Architecture Audit — Manager Assistant

- **Repository:** moamenessamseja-web/manager-assistant-ready (public)
- **Audited HEAD:** `2189cad` (design-system + build-fix commit)
- **Audit date:** 2026-10-12
- **Toolchain:** Flutter stable `3.47.7` / Dart SDK constraint `>=3.4.0 <4.0.0`
- **Build path:** GitHub Actions only (`ubuntu-latest`); no local Android toolchain in the agent sandbox.

---

## 1. Project structure

```
lib/
  main.dart                     # entrypoint: init storage+tz+notifications, reschedule, rules, runApp
  design/
    tokens.dart                 # AppColors / AppSpace / AppRadius / AppTouch / AppIconSize / AppShadow
    app_theme.dart              # AppTheme.light() + AppText type scale
    widgets.dart                # shared components (badge, card, list tile, metric card, sheet, states)
  models/                       # commitment, employee, reminder, rule, supplier  (flat JSON)
  screens/                      # 13 screens (today, staff, suppliers + details, memory, chat,
                                #  brief, rules, settings, notification_debug, main_shell)
  services/
    app_state.dart              # AppState extends ChangeNotifier (single global notifier)
    storage_service.dart        # SharedPreferences JSON lists + Arabic normalization + entity lookup
    assistant_controller.dart   # intent dispatch → entity resolution → mutation → save
    gemini_service.dart         # Gemini REST structured-output parser
    reminder_service.dart       # Reminder entity lifecycle + scheduling
    notification_service.dart   # flutter_local_notifications wrapper
    rules_service.dart          # recurring follow-up rules tick
test/model_test.dart            # 1 test (employee salary math)
```

## 2. Framework, state & persistence

- **State management:** none of Provider/Riverpod/Bloc. One global `AppState extends ChangeNotifier`;
  `StorageService` calls `AppState.instance.notify()` after every write, and screens wrap content in
  `ListenableBuilder`. `main.dart` rebuilds `MaterialApp` on notify.
- **Persistence:** `shared_preferences` only (no SQLite/Drift). One JSON-string-list per entity type:
  `commitments`, `employees`, `suppliers`, `rules`, `reminders` (+ scalar `gemini_api_key`).
- **Migrations:** no formal migration layer. All changes are *additive JSON*; new fields must default
  when absent in `fromJson`. Old records with unknown dates must not be given invented timestamps.

## 3. Data model (current)

| Entity | Fields (key) | Notes |
|---|---|---|
| `Commitment` | id, textOriginal, person, type, amount?, dueDate, remindAt, status, followUpRule | generic commitment/task; `type` = debt_to_collect / debt_to_pay / task / rent / supplier |
| `Employee` | id, name, role, startDate, salaryMonthly, advances[], attendance[] (day strings), archived | no phone/address/photo/notes; no checkout; no payments/deductions/bonuses |
| `Advance` | id, amount, date, note | |
| `Supplier` | id, name, itemType, phone, **totalOwed (scalar)**, payments[], deliveries[], note, archived | `balanceDue = totalOwed − totalPaid` |
| `SupplierPayment` | id, amount, date, note | actual cash paid |
| `Delivery` | id, item, quantity?, unit, expectedDate, received, receivedDate?, note | **no price field at all** |
| `Reminder` | id, title, body, dueAt, recurrence, relatedEntityId/Type, status, enabled, createdAt/UpdatedAt | independent entity — good |
| `FollowUpRule` | id, text, frequency, anchor, amount?, nextDue, active | |

## 4. AI pipeline

```
Chat text → GeminiService.parse()  (REST, model gemini-3.5-flash-lite, temperature 0.1,
                                    responseMimeType application/json + responseSchema)
          → intent + flat args
          → AssistantController.handle() switch(intent)
          → _resolveEmployee/_resolveSupplier (ambiguous → ask, never guess)
          → mutate model → StorageService.save* → AppState.notify()
          → Arabic confirmation string (+ ReminderOutcome.warningSuffix on schedule failure)
```

- Entity resolution uses `normalizeArabic()` (diacritics, أ/إ/آ→ا, ة→ه, ى→ي, ZWSP) — Priority B fix present.
- **Weakness:** the Gemini argument list has no notion of unit price / quantity×price / purchase vs payment,
  so goods value and cash paid are conflated at the intent level (see Defect D2).

## 5. Notification pipeline

```
ReminderService.createAndSchedule()
  → save Reminder (status=created)
  → NotificationService.scheduleAt(id.hashCode, ...)  (zonedSchedule, inexactAllowWhileIdle)
  → write the REAL scheduler status back (scheduled / schedule_failed / permission_required)
  → ReminderOutcome (suffix warns user honestly if scheduling failed)
```
- `ReminderService.rescheduleAllActive()` re-arms `scheduled`+`enabled`+future reminders on every app start (idempotent by id).
- CI injects: `POST_NOTIFICATIONS`/`RECORD_AUDIO`/`INTERNET`/`RECEIVE_BOOT_COMPLETED`, the
  `ScheduledNotificationBootReceiver` + `ScheduledNotificationReceiver`, ProGuard keep-rules for
  `flutter_local_notifications` + Gson, `isMinifyEnabled`/`isShrinkResources`, and core-library desugaring.
- Timezone: `timezone/data/latest_all` initialised before scheduling; schedule uses device-local time.

## 6. CI / artifact

`.github/workflows/build-apk.yml` — on push to `main` / manual dispatch: checkout → flutter stable →
generate `android/` scaffold if missing → inject permissions → inject boot receiver → write proguard →
enable R8 + desugaring → `flutter pub get` → `flutter build apk --release` → create release tag
`build-<run_number>` with `app-release.apk`. On failure it creates `debug-<run_number>` carrying the
tail of `build_log.txt`.

## 7. Tests

Only `test/model_test.dart` (1 test: employee salary math). No supplier/AI/reminder tests.
`flutter analyze` is clean (0 errors) as of HEAD.

---

## 8. Defects identified (with evidence)

| ID | Severity | Defect | Evidence |
|---|---|---|---|
| **D1** | **P0** | **Goods value is not stored as records.** `Supplier.totalOwed` is one scalar and `Delivery` has no price, so the app cannot list "كل توريد" (item/qty/unit price/total/date) nor show what each supply still owes. | `models/supplier.dart` |
| **D2** | **P0** | **AI conflates supply value with payment.** `_addSupplier` writes `amount`→`totalOwed`; `_markDeliveryReceived` adds `amount`→`totalOwed`; there is no `record_purchase`. A spoken goods price can therefore be booked as a debt with no per-supply record, and "دفعة" has no unit-price model. | `assistant_controller.dart:114-196`, `gemini_service.dart:25-26` |
| **D3** | P1 | `Employee` cannot represent checkout, payments, deductions, bonuses, notes, phone, address or photo. | `models/employee.dart` |
| **D4** | P1 | No activity/audit log entity → no unified Timeline, no edit/delete audit trail. | no such model |
| **D5** | P1 | Settings screen only stores the Gemini key; no theme (light/dark/system), no notification prefs, no business settings. | `screens/settings_screen.dart` |
| **D6** | P2 | Dates rendered with `DateTime.toString().substring(0,10)` — not Arabic-formatted, no explicit timezone/business-timezone handling. | multiple screens |
| **D7** | P2 | `_markAttendance` only records "today" with no checkout or back-dating. | `assistant_controller.dart:102-110` |
| **D8** | ok | `deleteSupplier` hard-deletes a supplier including history — no archive-first guard, no safe-delete for suppliers with transactions. | `storage_service.dart:119-123` |
| **D9** | ok | `normalizeArabic()` ends with a no-op `replaceAll('ه','ه')` and `.replaceAll('ة','ه')` maps ة→ه; harmless but redundant. | `storage_service.dart:14-31` |

**Verified as genuinely fixed (Priority B claim):** `deleteSupplier` now matches on `s.id == id`
(no longer "delete everything" bug).

---

## 9. Baseline capability (this environment)

- ✅ `flutter pub get` — works
- ✅ `flutter analyze` — 0 errors
- ✅ `flutter build bundle` — Dart kernel compiles
- ✅ `flutter test` — test harness runs
- ✅ GitHub Actions release APK — green as of run #56
- ❌ No local Android SDK/Gradle → full APK must be produced by CI
