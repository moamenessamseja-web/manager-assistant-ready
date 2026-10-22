# implementation.md — Manager Assistant: current implementation inventory

> Living document. **Statuses** (never promote without evidence): Verified complete · Implemented, not yet verified ·
> Partially implemented · Not started · Blocked · Deferred by product decision.
> Last updated: 2026-10-22 (branch `phase-b/from-32df13f`, latest green = Build 93). Owner-confirmed on device: build 92 (branch), build 87 (`main`).
> Evidence levels: *CI* = analyze + `flutter test` + APK build on GitHub Actions; *Device* = owner ran the APK.
> No Dart/Flutter SDK is available to the engineering sessions, so nothing is "run locally".

## 1. Chat command pipeline (Phase B)
Flow: text/voice → `AssistantController.handle` → pending-clarification resume → `LocalCommandParser.parse`
→ (optional) Gemini → `_runLocal` (ambiguity → missing-fields → dispatch) → existing business operations.

| Item | Status | Notes |
|---|---|---|
| Quantity is not money (`٢٠ كيلو سكر`) | Implemented, not yet verified (CI) | quantity token excluded from amount candidates; Gemini single-number fallback now uses `extractSlots` too; Gemini prompt updated |
| Asks for value/day/hour instead of guessing | Implemented, not yet verified | `_missingFor` returns `amount` / `due_date` / `time`; past dates are re-asked |
| Short replies to a question (`٣٠٠`, `بكرة الساعة ٥ العصر`, `مساء`) | Implemented, not yet verified | `LocalCommandParser.extractSlots(raw, expect:, hourHint:)` merged in `_tryResumePending` |
| Dates: بكرة / بعد بكرة / بعد N يوم / يوم ٢٠ أكتوبر / ٢٠/١٠ / weekday | Implemented, not yet verified | local timezone, DST-safe (`DateTime(y,m,d+k)`) |
| Time: الساعة N + صباحا/مساء/العصر/الظهر/بالليل, ونص/وربع | Implemented, not yet verified | 1–12 without period → asks "صباحًا ولا مساءً" |
| Expected delivery (`هيجيب/هيسلم/هيورد/متوقع…`) | Implemented, not yet verified | item/qty/unit/total captured; creates Delivery + Commitment(type supplier); **no** purchase/inventory/payable until receipt |
| Reminder (`فكرني/افتكر`) | Implemented, not yet verified | person=`عام`; requires day + time; no default "tomorrow 09:00" |
| Attached waw (`محمود وخالد`) | Implemented, not yet verified | `وليد/وائل…` kept via `_waNames` allowlist |
| Duplicate-send guard | Implemented, not yet verified | identical normalized text within 8 s after a ✅ reply is not re-executed (in-memory only) |
| Tappable clarification choices (Priority 3) | Implemented, not yet verified (CI #84) | `ChoiceBuilder` + `handleChoice` + chat `_ChoiceBar`; bound to `PendingOperation.id`; stale/double taps rejected |
| Money-vs-quantity chips ("الرقم 500 تقصد بيه إيه؟") | Not started | parser currently decides by units/markers; ambiguous bare numbers ask for the amount instead |
| Today cards actions + tappable metrics | Implemented, not yet verified (CI #86) | metrics/alert open lists; per-tile "اسأل المساعد"; supplier ✔ = confirm-receipt dialog |
| "اسأل المساعد" on Today and Brief | Implemented, not yet verified | shared `AskAssistantBar` + sheet; reuses controller, choices, chat history |
| Instructions page | Implemented, not yet verified | drawer item after Settings; 8 practical sections, no claim of full phrasing coverage |
| Persistent duplicate prevention | Implemented, not yet verified | `IdempotencyService`; chat message ids + `receive:<id>`; not on other direct forms |
| Persisted message state / idempotency keys across restarts | Partially implemented | see above; keys are not stored on the transaction records themselves | 
| Confirm-before-post when expected delivery notification fires | Not started | notification only; `mark_delivery_received` is a typed command |
| Gemini / external AI | **Removed** (CI #92, not device-verified) | no API key, no `http`; legacy key purged at startup; `INTERNET` permission kept pending a voice test |
| Receivables tab (customers, credit sales, payments) | Implemented, not yet verified (CI #92) | replaces main Brief tab; Brief still in drawer; manual UI only |
| Chat commands for customers (credit sale / payment) | Not started | next step |
| Backup / restore | Not started | |
| Unknown supplier name auto-creates a supplier (delivery/purchase) | Partially implemented (pre-existing) | archived-supplier names are refused, never duplicated |

## 2. Data & navigation (Phase C)
| Item | Status | Notes |
|---|---|---|
| Supplier archive | Implemented, not yet verified | root cause: default `active` filter returned *all*. Now `filterSuppliers()` (models/supplier.dart); `suppliersMatching` excludes archived; chat refuses archived names |
| Memory cards Reminders / Commitments | Implemented, not yet verified | read-only `RemindersListScreen` / `CommitmentsListScreen` (`screens/memory_lists.dart`), empty states, widget tests |
| Notification settings | Implemented (owner confirmed screen works in 92) | `NotificationPrefs` (3 categories + lead time) wired into `ReminderService`; screen reached from AppBar of "القواعد والتنبيهات". Applies to **new** reminders only |
| Notification sound selection | Not started / limitation | Android channel sound is immutable after creation; needs a new channel id + `res/raw` sound — native work, not done |
| Bell vs settings | Documented | Bell → `NotificationDebugScreen` (status/diagnostics of reminders). Side menu "القواعد والتنبيهات" → `RulesScreen` (+ settings via AppBar `tune`). Intentionally different screens |
| Rule→category mapping | Partially | rules → `rules`, supplier deliveries → `suppliers`, rest → `reminders`; stored reminders don't keep their category, so `rescheduleAllActive` ignores the toggles (only lead time) |

## 2b. Reminders & notifications — sidebar as the primary manager (Build 93)
| Item | Status | Notes |
|---|---|---|
| Rules & Notifications screen = real manager (create/view/edit/delete) | Implemented, not yet verified on device (CI #93) | 2 tabs; `ReminderManager` → same `Commitment`/`Reminder`/`FollowUpRule` records as chat |
| One-off reminders persist, appear in Today + Memory lists | Implemented, not yet verified | `Commitment(type:'task')` + `Reminder`; restart-persistence unit tests pass |
| Alarm-style time field (hour / minute / ص-م) + date picker on the alarm FAB dialog | Implemented, not yet verified | `AlarmTimeField`, `ReminderEditorDialog` |
| Real scheduling at the chosen time | Implemented (CI via fake backend); device: **not verified** | exact alarms when permitted, otherwise inexact + warning |
| Recurring rules notify with the app closed | Implemented (series of future notifications), device: **not verified** | refreshed at app open |
| Survives device reboot | Partially implemented / **not verified** | plugin boot receiver (CI manifest) + re-arm at app open |
| Exact-alarm permission handling | Implemented, not yet verified | settings row + "السماح" |
| Rules previously never notified (bug) | Fixed (root cause documented) | see `IMPLEMENTATION_STATE.md` |
| Dues page heading + time beside day/date | Implemented, not yet verified | title was hard-coded in `main_shell` |
| Chat understanding of colloquial reminder phrasing | Not started (owner item 4) | sidebar no longer depends on it |

## 3. Brief — roadmap only (Phase D) — Deferred by product decision
Current Brief (side menu + main screen) is **unchanged and functional**; nothing in this session implements reporting.
Future design (do not claim done): side-menu Brief → historical weekly/monthly **business statement** from stored records
(income/expenses, supplier purchases/payments/outstanding, employee advances/deductions/bonuses, attendance, commitments &
overdue) with date-range selection, subtotals and account-level detail; totals computed deterministically (AI may only explain);
main-screen Brief stays a concise overview/entry point. PDF export/printing is a later phase, explicitly out of scope now.

## 4. Platform / CI audit (Phase E)
Findings (verified by reading repo + workflow + APK analysis):
1. `android/` and `ios/` are **not committed**; CI runs `flutter create --platforms=android --org com.example` every build and patches
   manifest/gradle/proguard with `sed`/`cat >>`. ⇒ application id is `com.example.manager_assistant` (**Google Play rejects `com.example`**).
2. Release APK is signed with the per-runner **debug key** ⇒ every build has a different signature; installing over a previous build can be refused.
3. Flutter `stable` is unpinned. APK 75 vs 76/77 proved dependency/toolchain drift (plugin 2.5.0 JNI) despite `pubspec.lock`; mitigated by
   `dependency_overrides` + CI guard. Why the lock was not honoured is still unknown.
4. No `ios/`; iOS can't be built on this CI (needs macOS/Xcode). Never claim an iOS build.
5. CI now records `flutter --version` + resolved plugin version in each release's notes and targets the release at the built commit.
6. Analyzer: `--no-fatal-infos`; warnings **are** fatal (an unused private function broke build #79).
Decisions needed from the owner (not done on purpose): final application id (changing it installs as a *different* app with empty data),
and a fixed upload keystore (as a GitHub secret) before Google Play. See `استراتيجية نشر…` doc.
Statuses: reproducible platform scaffolding — Not started · fixed signing — Not started · Flutter pin — Not started (needs the version from release notes) ·
toolchain fingerprint — Implemented, not yet verified.

## 5. Verification log
| Build | Commit | CI | Device |
|---|---|---|---|
| 75 | 32df13f | green | owner baseline |
| 76 | 25dbffe | green | **black screen** (plugin drift, not parser) |
| 78 | 16e09ec | green | opens (owner confirmed) |
| 79 | 3c8a886 | **red** (unused `_relativeDate`) | – |
| 80 | 04a2849 | **red** (1 old test: `mark_attendance` mis-grouped in `_isConfident`; 66 others passed) | – |
| 81 | 6134afd | green (analyze, 67 tests, APK) — Flutter 3.47.7 / Dart 3.13.5 | not yet |
| 82 | fea404f | green (Flutter pinned 3.47.7) | owner-confirmed baseline per new vision doc |
| 83 | 8ee9a5a | red (lint warning) | – |
| 84 | 92e42e5 | green (chat choices) | owner tested: works |
| 85 | 4f6e1c8 | red (missing import) | – |
| 86 | cb5f5e7 | green (Today/Brief/instructions/idempotency) | merged → main |
| 87 | 667ebc7 (main) | green | owner confirmed |
| 88-91 | – | red (widget-test/storage-gate/name-clash/ListTile issues, see state file) | – |
| 92 | 1565f25 | green (Gemini removed + Receivables tab, 101 tests) | owner confirmed |
| 93 | d2a17ef | green (reminders/notifications rebuild) | not yet |
