# Implementation State

- **Baseline (fixed):** `main @ 2189cad` — the user-designated starting point (= build #56)
- **Last completed work:** To Accio §2 — Supplier goods value vs cash payments
- **Last successful commit:** `2e4835f`
- **Last successful build:** GitHub Actions run **#60 → SUCCESS** (`build-60`, app-release.apk 53.5 MB)
- **Last successful test:** `flutter test` → **9/9 pass** (1 legacy model + 8 supplier)
- **Current phase:** §3 Employee file (not started)
- **Next phase:** §3 + §5 (employee real file + record times)

## Source of truth
- `To Accio.md` is the only brief. `masaad_el_edara_master_implementation_brief_v2.md` is **dropped**
  and must not be used or relied upon.
- Builds **#57/#58 are to be treated as if they never happened.** The work they contained lives
  in the branch `backup/phases-0-3`; `main` was force-reset to `2189cad`. Do **not** build on,
  cherry-pick from, or trust anything in that branch without re-verifying it against `To Accio.md`.

## Independent verification already done (see `.agent/VERIFICATION_REPORT.md`)
Re-checked the four previously claimed priority fixes against the code at `2189cad`
(not against any report). Result: **all four are genuinely present and working** —
do NOT rebuild them:
| Claim | Commit | Verdict |
|---|---|---|
| A — notifications / ProGuard + R8 keep rules | `207cbaa` | ✅ present & correct class of fix |
| B — Arabic normalization + `deleteSupplier` id-match fix | `1348252` | ✅ present; no "delete all" bug |
| C — live state (`ListenableBuilder` + `AppState`) | `fbd38fd` | ✅ in 5 screens |
| D — Weekly Brief drill-down dialogs | `fbd38fd` | ✅ present |
| E — Memory business overview + search + timeline | `8e669cf` | ✅ present |

## Genuine remaining gaps (from `2189cad`)
| Ref | Gap | Status |
|---|---|---|
| §2 | goods value vs payments separated | ✅ **DONE** (`2e4835f`) |
| §3 | employee real editable file (photo, payments, deductions, bonuses, notes, checkout) | ⬜ not started |
| §5 | record times (attendance times; legacy records have dates without times) | ⬜ not started |
| §6 | settings: theme (light/dark/system), notification prefs, persisted choices | ⬜ not started |
| §8 | notification hardening + honest diagnostics (channel state, next fire time, IDs) | ⬜ not started |
| §9 | resolve several names in one command | ⬜ not started |
| §13 | audit log for financial edits / archive / delete | ⬜ not started |
| §1 | explicit `Africa/Cairo` handling (currently device-local) | ⬜ not started |

## Files changed in this step (`2e4835f`)
- `lib/models/supplier.dart` — `SupplierPurchase`, `PurchaseBalance`, `SupplierEvent`,
  `purchases[]`, `goodsTotal`, `balanceDue` (= goodsTotal − paid), `allocatePayments()` (FIFO),
  `hasHistory`, `timeline`, `createdAt`; `SupplierPayment.method` (optional)
- `lib/services/assistant_controller.dart` — new `record_purchase`; `_appendPurchase`;
  goods price no longer written as a payment; `mark_delivery_received` records a purchase;
  `supplier_balance` returns a goods/paid/due breakdown
- `lib/services/gemini_service.dart` — `purchase_*` args + explicit goods-vs-payment rule
- `lib/design/format.dart` — NEW: Arabic money/date/time formatting
- `lib/screens/supplier_records.dart` — NEW: supply/payment sheets, drill-down reports
  (purchases/payments/balance) with period filters, archive, safe delete
- `lib/screens/suppliers_screen.dart` — numbers → `goodsTotal`; overflow menu now has
  تسجيل توريد / تسجيل دفعة / أرشفة / حذف نهائي (only when no history)
- `lib/screens/supplier_details_screen.dart` — tappable finance tiles → reports;
  `تسجيل توريد بقيمة` + `تقرير المستحقات`; `_hasHistory` includes purchases
- `test/supplier_test.dart` — NEW: 8 tests incl. the 6 mandatory acceptance cases

## Known non-blocking warnings (`flutter analyze` = 0 errors)
Pre-existing only: 2 STT deprecations (chat_screen), unused `_dayLabel` (chat_screen),
unused import (main_shell), `value:`→`initialValue:` (rules_screen), unused `_searching`
(staff_screen), unused import (rules_service). Deliberately untouched — no functional impact,
and §1 says don't change what works without a specific proven need.

## Database migration safety
Additive JSON only, no destructive migration, verified by a back-compat test:
- New supplier field `purchases[]`; legacy `totalOwed` kept as an explicit
  "رصيد قديم (بدون تفاصيل)" opening line in the balance report.
- Old supplier balances are numerically unchanged after upgrade (test #5).
- Rollback: old app versions ignore unknown JSON keys → reverting the APK is safe.

## AI pipeline status
Updated for §2 and **not yet verified end-to-end against the live Gemini API** (needs a key):
`record_purchase` added; purchase args added to the schema; goods-vs-payment rule in the prompt.

## Reminder / notification status
Unchanged this step. ProGuard + R8 keep-rules and the boot receiver are present and were verified
in the workflow. Physical-device delivery after reboot is still **untested**.

## APK / artifact status
- Latest: run **#60** → release tag `build-60`, asset `app-release.apk` (53.5 MB)

## Recovery instructions
1. Read this file, then `.agent/VERIFICATION_REPORT.md`.
2. `git log --oneline -5` — expect `2e4835f` on top of `2189cad`.
3. Local checks: `flutter pub get && flutter analyze && flutter test`.
4. Push to `main` → GitHub Actions builds → release `build-<run_number>`.
5. Continue with **§3 + §5**.

## Next action
Implement **To Accio §3** (real editable employee file) together with **§5** (real times in
records) — they share the model — as surgical additions, then §8, §6, §9, §13.

## Honest status
§2 is complete and verified. **§3, §5, §6, §8, §9, §13 and §1-timezone are NOT done.**
This is a deliberate, stable pause point — not a completed brief.
