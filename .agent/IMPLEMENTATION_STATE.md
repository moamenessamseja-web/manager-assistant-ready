# Implementation State

- **Baseline (fixed):** `main @ 2189cad` — the user-designated starting point (= build #56)
- **Last completed work:** To Accio §3 + §5 + §6 + §9 (plus §2 before it)
- **Last successful commit:** `fac9d58`
- **Last successful build:** GitHub Actions run **#62 → SUCCESS** (`build-62`, app-release.apk 54.7 MB)
- **Last successful test:** `flutter test` → **15/15 offline pass** + **3/3 live end-to-end pass**
- **Remaining:** §13 audit log (nothing else from the brief is open; §1 Cairo and §8 notifications are
  **explicitly out of scope by user instruction**)

## Source of truth
- `To Accio.md` is the only brief. `masaad_el_edara_master_implementation_brief_v2.md` is **dropped**.
- Builds **#57/#58 are disregarded**; their work lives on `backup/phases-0-3` and must not be trusted
  without re-verification.
- **User instruction (current):** do NOT touch the Cairo/timezone handling and do NOT change
  notifications — both work and are frozen.

## Verified as already done — must NOT be rebuilt
See `.agent/VERIFICATION_REPORT.md`: ProGuard/R8 keep-rules (`207cbaa`), Arabic normalization +
`deleteSupplier` id-match (`1348252`), live state via `ListenableBuilder` (`fbd38fd`), Weekly Brief
drill-downs (`fbd38fd`), Memory overview + search + timeline (`8e669cf`).

## Work delivered

### §2 Supplier goods value vs cash payments — `2e4835f`
`SupplierPurchase` (item/qty/unit/unitPrice/total/date), `goodsTotal`, `balanceDue = goodsTotal − paid`,
FIFO `allocatePayments()`, additive migration with the legacy balance shown as
"رصيد قديم (بدون تفاصيل)", `supplier_records.dart` (separate supply/payment sheets + drill-down
reports), AI `record_purchase`, `supplier_balance` breakdown.

### §3 Real editable employee file — `fac9d58`
- Model (additive): `phone`, `address`, `idNumber`, `photoPath`, `attendanceLog`
  (`AttendanceEntry` with real check-in/out), `payments`, `deductions`, `bonuses`, `notes`,
  `EmployeeEvent` timeline.
- **Original salary rules untouched**: `workingDays`, `absenceDays`, `salaryDue`, `remainingSalary`
  are byte-for-byte the same; new figures added separately (`attendancePay`, `netPayable`,
  `totalPayments/Deductions/Bonuses`).
- Notes never auto-deduct. Deduction is an explicit financial action.
- `employee_details_screen.dart` rebuilt as a real file: photo slot (pick/replace, long-press to
  remove, copied into the app documents dir), full edit form incl. start date, 8 quick actions
  (حضور/انصراف/سلفة/دفعة/خصم/مكافأة/ملاحظة/تعديل), tabs (النشاط/الحضور/المالية/البيانات),
  archive-first, safe delete only when `!hasHistory`.

### §9 Commands naming several people — `fac9d58`
Gemini schema gains a `people` array + prompt rules/examples; `AssistantController.handle` expands one
command across every resolved name and aggregates the results (previously only one name was acted on).

### §5 Time next to date in records — `fac9d58`
Attendance stores real check-in/out times; legacy day-only rows render "الوقت غير متوفر" (no invented
times). `arabicDate`/`arabicDateTime` replace the old `toString().substring(...)` hacks in supplier
deliveries/payments, rules next-run, memory, brief, today, and the assistant's replies.

### §6 Theme + language settings — `fac9d58`
`SettingsService` persists `theme_mode` (light/dark/system) and `pref_language` (ar/en).
`AppTheme.dark()` added; shared widgets (`AppCard`, `AppListTile`, quick action, bottom sheet) read the
theme instead of fixed colours, and the explicit `AppColors.background` scaffolds were removed so dark
mode actually applies. `L` (strings) localises the shell, nav and settings and flips RTL/LTR.
Settings screen rebuilt: appearance, language, Gemini key, notification diagnostics.
**Known limitation:** the language switch covers the UI chrome (nav, titles, settings); screen body
copy and data remain Arabic.

## Reliability work found by live API testing (important)
Testing against the real Gemini API exposed genuine model flakiness on money fields. Fixed in `fac9d58`:
1. A previous prompt tweak made the model drop amounts entirely — reverted and rewritten.
2. `AssistantController.resolvePurchaseTotal` is now a public, unit-tested rule:
   explicit total → `amount` → qty × unit price (the model often returns a unit price instead of a total).
3. One automatic re-parse when an amount-needing intent comes back with no amount.
4. Last-resort **safe** fallback: if the sentence contains exactly one number, that is the amount;
   with two or more numbers the app asks instead of guessing. No number is ever invented.

## Tests
- `test/model_test.dart` (1), `test/supplier_test.dart` (8, incl. the 6 mandatory §2 cases),
  `test/employee_test.dart` (6, incl. salary back-compat and attendance times).
- `test/gemini_live_test.dart` (3, tagged `live`): real end-to-end against Gemini — creates data, runs
  Arabic commands through the app path, then asserts the database. Reads the key from
  `GEMINI_API_KEY`; **skipped automatically when absent**, and the key is never stored in the repo.
  Latest run: 3/3 pass (goods purchase 2000 / no payment; payment 500 → balance 1500; two names both
  marked present).

## Database migration safety
Additive JSON only, no destructive migration:
- Supplier `purchases[]`; legacy `totalOwed` kept as a labelled opening line.
- Employee: all new lists default to empty; old records parse unchanged and their salary figures are
  numerically identical (covered by a back-compat test).
- Rollback: older app versions ignore unknown JSON keys, so reverting the APK is safe.

## Frozen / out of scope (by user instruction)
- **Timezone / Africa-Cairo:** untouched — works.
- **Notifications:** untouched — works. (`notification_debug_screen.dart` deliberately not edited.)

## APK / artifact
- Latest: run **#62** → release `build-62`, `app-release.apk` (54.7 MB).

## Recovery instructions
1. Read this file, then `.agent/VERIFICATION_REPORT.md`.
2. `git log --oneline -5` — expect `fac9d58` on top of `2189cad`.
3. `flutter pub get && flutter analyze && flutter test`.
4. Live AI check: `GEMINI_API_KEY=... flutter test test/gemini_live_test.dart`.
5. Push to `main` → GitHub Actions builds → release `build-<run_number>`.

## Next action
Only **§13 (audit log for financial edits / archive / delete)** remains from the brief. Then optional
polish: extend the language switch beyond UI chrome, and physical-device checks (notifications,
photo picker, chat→attendance).

## Honest status
§2, §3, §5, §6, §9 are done and verified (offline + live tests, green CI). §13 is not started.
Device-level behaviour (photo picker, notification delivery after reboot) is still **untested on a
real phone** — CI only proves it compiles and packages.
