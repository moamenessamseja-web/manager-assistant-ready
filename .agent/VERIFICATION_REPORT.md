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
