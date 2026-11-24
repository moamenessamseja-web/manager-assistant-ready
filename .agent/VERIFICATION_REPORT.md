# Independent Verification Report — prior "Priority A–E" fixes

- **Baseline:** `main @ 2189cad` (user-designated baseline = build #56)
- **Method:** read-only inspection of commit objects + the actual code at `2189cad`.
  Every prior claim was re-checked against the code, not against any report.
- **Legend:** ✅ confirmed · ⚠️ partial · ❌ not present · ❓ needs a device/API to test

---

## 0) Baseline (real)

| Item | Value |
|---|---|
| Branch / commit | `main` @ `2189cad` |
| Flutter (CI) | stable `3.47.7` (local sandbox verified with the same) |
| Dart SDK constraint | `>=3.4.0 <4.0.0` |
| Persistence | `shared_preferences` JSON lists: `commitments`, `employees`, `suppliers`, `rules`, `reminders` |
| State | single `AppState extends ChangeNotifier` |
| AI | Gemini REST `gemini-3.5-flash-lite`, JSON `responseSchema`, temperature 0.1 |
| Notifications | `flutter_local_notifications ^17.2.3` + `timezone`, `zonedSchedule` |
| APK | produced by GitHub Actions only (no Android SDK in the agent sandbox) |
| Tests | `test/model_test.dart` — 1 test |
| `flutter analyze` | 0 errors (9 info/warnings) |

---

## 1) Priority A — `207cbaa` (notifications / ProGuard) — ✅ CONFIRMED

Commit exists and is an ancestor of `2189cad`; touches only `.github/workflows/build-apk.yml` (+37/−1).
Verified in the workflow at baseline:
- `proguard-rules.pro` written with `-keep class com.dexterous.flutterlocalnotifications.** { *; }`
  and `-keep class com.google.gson.** { *; }`
- `minifyEnabled true` + `shrinkResources` + `proguardFiles(...)`
- `ScheduledNotificationBootReceiver` / `ScheduledNotificationReceiver` registered.

**Confirmed cause** of the original `Missing type parameter` crash: R8 stripping Gson's generic
metadata used by `flutter_local_notifications`. The fix is present and is the correct class of fix.

**Not tested (❓):** actual delivery after reboot / app-kill / update on a physical device.

## 2) Priority B — `1348252` (Arabic entity resolution) — ✅ CONFIRMED

- `normalizeArabic()` exists (`storage_service.dart`): strips tashkeel/tatweel, unifies
  أ/إ/آ→ا, ة→ه, ى→ي, removes ZWSP.
- Used by `findEmployee`, `employeesMatching`, `findSupplier`, `suppliersMatching`.
- `AssistantController` distinguishes *no match* vs *ambiguous* and asks for clarification
  instead of guessing.
- **`deleteSupplier()` is correct**: `suppliers()..removeWhere((s) => s.id == id)` — it does **not**
  delete all suppliers. `deleteEmployee()` is correct by the same pattern.

**Side-effect sweep:** no other call site re-introduces the "delete everything" bug.

## 3) Priority C — `fbd38fd` (live state) — ✅ CONFIRMED

`ListenableBuilder(listenable: AppState.instance)` present in `staff_screen`, `suppliers_screen`,
`today_screen`, `brief_screen`, `memory_screen` (+ `main.dart` rebuilds `MaterialApp`).
`StorageService` calls `AppState.instance.notify()` after every write. The commit is an ancestor of baseline.

**Not tested (❓):** live propagation across *all* screens in one session on a device.

## 4) Priority D — `fbd38fd` (Weekly Brief actionable) — ✅ CONFIRMED

`brief_screen.dart` has `onTap` on the stat rows plus `_showAbsentDialog(context, absent)` and
`_showDebtorsDialog(context, debtors)`; data comes from `StorageService` (not hard-coded).

## 5) Priority E — `8e669cf` (Memory as business overview) — ✅ CONFIRMED

`memory_screen.dart` has: an interactive search `TextField` (filtering across entities),
`ListenableBuilder`, an operational summary when idle, and `_buildActivityTimeline(...)` for
last-activity. Commit is an ancestor of baseline.

---

## 6) Genuine gaps vs `To Accio.md` (what is actually missing at 2189cad)

These are the only items that require real work — everything above is **already done** and must
**not** be rebuilt.

| Ref | Gap | Evidence at 2189cad |
|---|---|---|
| **§2** | **Goods value vs payments are conflated.** `Supplier.totalOwed` is one scalar; `Delivery` has **no price field**; there is no per-supply record. Cannot list supplies with qty/unit-price/total, nor show what each supply still owes. `_addSupplier` writes `amount`→`totalOwed`; `_markDeliveryReceived` adds `amount`→`totalOwed`. | `models/supplier.dart`, `assistant_controller.dart` |
| **§3** | Employee file cannot represent: photo, phone/address/ID, checkout time, salary payments, deductions, bonuses, notes. | `models/employee.dart`, `employee_details_screen.dart` |
| **§5** | `Employee.attendance` stores **day strings only** → no time of day anywhere for attendance; supplier records have dates but no times on legacy entries. | `models/employee.dart` |
| **§6** | Settings screen holds only the Gemini key. No theme (light/dark/system), no notification preferences, no language setting persisted. | `screens/settings_screen.dart` |
| **§8** | Diagnostics show permission + pending count + reminder statuses, but **not**: channel enabled/importance, next reminder time, last scheduling result, notification IDs. No exact-alarm/duplicate-ID hardening beyond ProGuard. | `screens/notification_debug_screen.dart` |
| **§9** | Entity resolution handles one person per command; a sentence naming **several** people is not split and resolved per name. | `assistant_controller.dart` |
| **§13** | No audit log for financial edits / archive / delete. | no such model |
| **§1** | Timezone is device-local (`tz.initializeTimeZones()`); `Africa/Cairo` is **not** explicitly applied/verified. | `main.dart`, `notification_service.dart` |

## 7) Recommended order (respecting "don't rebuild what exists")
1. **§2** supplier goods-vs-payments (**top priority, explicitly stated**).
2. **§3 + §5** employee file + real times (they share the model).
3. **§8** notification hardening + honest diagnostics.
4. **§6** settings (theme/notifications) and **§9** multi-person resolution.
5. **§13** audit log.

**Explicit non-goals:** re-adding `ListenableBuilder`, re-doing `normalizeArabic`, re-doing the
ProGuard rules, re-writing Memory/Weekly Brief — all verified as already working.

## Session 5 (2026-11-21) — verification of the commercial-readiness branch

- **Local (sandbox, plain Dart 3.14.1, no Flutter SDK):** baseline parser suite 28/28 before edits and after;
  `customer_parser_test` 33/33; `employee_pay_test` 9/9; `dart analyze` clean on models, parser, choice builder.
  The controller was analysed best-effort only (Flutter/uuid packages unavailable) — CI is the real check.
- **CI (feature branch, workflow_dispatch):** first run failed on 2 tests (my duplicate-guard test and an
  instructions widget test that the new section pushed out of the lazy list) — both test issues, fixed. Next run:
  analyze ✅, **190 tests passed** ✅, then failed in Gradle because `java.util.Properties` does not resolve inside a
  `.kts` script — fixed (Kotlin stdlib). Final `release-selftest` run **44937906901**: all steps ✅
  (id guard, signing setup, analyze, tests, build, real-APK verification, signer == the throwaway key).
- **Not independently re-checked:** I could not download the artifact from the sandbox (redirect blocked), so
  versionName/versionCode/fingerprints were asserted by the workflow's own steps, not re-read by me.
- **NOT verified:** real release signing with the owner's private key (no secrets exist), installation on a device,
  any UI on a device, Arabic speech on a device, iOS on a device.
- **iOS (macOS runner, run 44938657368, commit 47cf1b9):** scaffold generated, `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` injected and read back by PlistBuddy, `flutter build ios --release
  --no-codesign` ✅. This is a **compile check only** — no device, no Arabic speech test, no notifications test,
  no App Store readiness claim.

## Field-driven branch verification — 2026-11-24

- Branch base verified: `feature/field-driven-v2` at `052c96cad8127a90f60cda4f33778a75c6089924`; implementation branch created from that ref.
- Static source audit confirmed SharedPreferences persistence and existing implementations for backup/restore, shift/day closing, shortages, café identity, terminology, and audit records.
- Run #99: `flutter analyze` passed; test suite reported 256 passed / 8 failed. Failure causes included `pumpAndSettle` timeouts, lazy `ListView` sections asserted before scrolling, and an obsolete test expectation that settings had no text field despite the required café-name field.
- Follow-up commits stabilize those tests and add daily shift-breakdown coverage. Run #100 checked out commit `eeb764b`, earlier than the final follow-up test commits; it cannot certify the latest HEAD.
- Latest branch verification: PENDING. No APK is claimed as produced or verified from the final branch state. Physical device verification is also pending.
