# Implementation State

Last completed phase: **Phase 3 — Employee management**
Current phase: Phase 4 — Today dashboard (not started)
Next phase: Phase 4 — Today operational dashboard
Last successful commit: `df46175` (feat: redesign employee management)
Last successful build: GitHub Actions run **#57 → SUCCESS** (commit `a28822f`), release `build-57` (app-release.apk 53.6 MB)
Last successful test: `flutter test` → **14/14 pass** (model/supplier/employee) on Flutter 3.47.7

## Files changed (this session)
- `.agent/ARCHITECTURE_AUDIT.md` — rewritten for current HEAD (9 defects documented)
- `.agent/IMPLEMENTATION_STATE.md` — this file
- `lib/design/format.dart` — NEW: Arabic money/date-time formatting
- `lib/design/widgets.dart` — NEW shared components: AppAvatar, AppSearchBar, AppFilterChips,
  AppSegmented, AppEntityRow, AppStatTile, AppInfoRow, AppTimelineItem, AppStatusIndicator, showAppSnack
- `lib/models/supplier.dart` — NEW `SupplierPurchase`, `PurchaseBalance`, `SupplierEvent`;
  `goodsTotal` / `allocatePayments()` / `timeline` / `hasHistory`
- `lib/models/employee.dart` — extended: contact/ID fields, photoPath, attendanceLog,
  payments/deductions/bonuses/notes, timeline, markAttendance/markCheckout
- `lib/services/assistant_controller.dart` — new `record_purchase`; goods value no longer booked as payment
- `lib/services/gemini_service.dart` — purchase_* args + goods-vs-payment rule
- `lib/screens/supplier_forms.dart` — NEW (record supply / record payment / add + edit / archive / safe delete)
- `lib/screens/supplier_report_screen.dart` — NEW (drill-down reports: purchases / payments / balance, with filters)
- `lib/screens/suppliers_screen.dart` — rebuilt list (search, filters, entity rows, contextual overflow, FAB)
- `lib/screens/supplier_details_screen.dart` — rebuilt (tappable finance summary, quick actions, timeline, tabs)
- `lib/screens/employee_forms.dart` — NEW (attendance/advance/payment/deduction/bonus/note/edit + photo)
- `lib/screens/employee_details_screen.dart` — rebuilt (photo header, summary, quick actions, 4 tabs)
- `pubspec.yaml` — added `image_picker`, `path_provider` (employee photo)
- `test/supplier_test.dart` — NEW (8 tests, incl. the 6 mandatory acceptance cases)
- `test/employee_test.dart` — NEW (5 tests, incl. back-compat)

## Current known issues (non-blocking)
- `flutter analyze`: 0 errors; 8 info/warnings (pre-existing STT deprecations, unused imports/elements,
  one `value:`→`initialValue:` in rules_screen). To be cleaned in Phase 11 (UX polish).
- Physical-device verification still pending for: notification delivery after reboot,
  attendance via Chat, Brief navigation, and the new employee photo picker on a real device.
- Chat/AI flows were updated but only unit-verified; end-to-end AI test needs a live Gemini key (Phase 9).

## Blocked items
- None. (Agent sandbox has no Android SDK, so the release APK is produced by GitHub Actions.)

## Database migration status
Additive JSON only — no destructive migration.
- Supplier: `purchases[]` added; legacy `totalOwed` kept and shown as a clearly-labelled
  "رصيد قديم (بدون تفاصيل)" line. `goodsTotal = totalOwed + Σpurchases.total`; `balanceDue = goodsTotal − totalPaid`.
- Employee: new optional fields default when absent; `attendance` (day strings) unchanged for
  today/brief/memory compatibility. Old records without timestamps show "وقت غير متوفر".
- Old data continues to work — covered by back-compat tests.

## AI pipeline status
Working. `record_purchase` added; goods price is no longer written as a payment;
`mark_delivery_received` records supply value as a purchase; `supplier_balance` returns a breakdown.
Gemini prompt + responseSchema updated (purchase_item/quantity/unit/unit_price/total).
**Not yet verified end-to-end against the live API (needs a key).**

## Reminder pipeline status
Unchanged this session — `Reminder` entity is independent; `ReminderService.createAndSchedule()`
writes the real scheduler status back and returns an honest warning suffix on failure.

## Notification status
Unchanged this session (ProGuard + boot receiver injected by CI; R8 enabled).
Physical-device verification pending.

## APK/artifact status
- Last green: run **#57** → release tag `build-57`, asset `app-release.apk` (53.6 MB)
- Pending: build for HEAD (`df46175`) after push

## Recovery instructions
1. Read `.agent/IMPLEMENTATION_STATE.md` + `.agent/ARCHITECTURE_AUDIT.md`.
2. `git log --oneline -10` and `git status`.
3. Local check: `flutter pub get && flutter analyze && flutter test`.
4. Push to `main` → GitHub Actions builds → release `build-<run_number>`.
5. Continue from **Next phase: Phase 4 — Today dashboard**.

## Next action
Monitor CI for the build from this commit. If green, proceed to **Phase 4 — Today Dashboard**
(operational dashboard: greeting, "يحتاج انتباه", daily summary, tasks, due payments,
attendance issues, quick actions, AI entry point), then Phase 5 (Weekly Brief actionable).

## Session note
Phases 0–3 completed with commits `7ec61c7`, `a89d4bf`, `a28822f`, `df46175`.
Remaining phases 4–13 (Today, Weekly Brief, Reminder architecture, Android notification
reliability, AI action layer, AI+reminder integration, live queries, UX polish, regression,
release artifact) are **not** done yet — this is a deliberate, honest pause point, not a completion.
