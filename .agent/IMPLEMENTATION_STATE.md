# Implementation State

- **Brief:** `my best agint.md` (the original agent brief) + `sonnet_come_back.md`
  (the active task that restored §9's API-key field — see Session 3 below).
  `To Accio.md` is superseded.
- **Baseline:** `main @ 2429a12` (= build #63, green) — resumed from here.
- **Session 1 commit:** `196a2d7` → **build #64 green** (§3 + §4 + §9 + §5 safety + tests + docs).
- **Session 2:** `06f89e6` → **build #65 green** (§6 + §7 + §8 + analyzer cleanup, one commit).
- **Session 3 (this one):** restored the Gemini API-key Settings field that Session 1
  removed — see "Session 3" section below for why and what changed.
- **Verification (Session 2):** `flutter analyze` → **0 issues**; `flutter test --exclude-tags live`
  → **42/42 pass**, with Flutter **3.47.7** (the CI version).
- **Verification (Session 3):** not re-run locally — **no Flutter/Dart SDK in this sandbox**
  (see "Session 3" section). Brace/paren balance checked by script; correctness relies on
  the CI run for the pushed commit. Update this line once that run's result is known.

## §3 — Local command engine (done in `196a2d7`)
`lib/models/command_result.dart` + `lib/services/local_command_parser.dart`: Arabic normalization
(Arabic-Indic/Eastern digits, diacritics, alef/taa/yaa), intent detection for
attendance/advances/deductions/bonuses/employees/suppliers/purchases/payments/deliveries/
rules/commitments/queries, amount + quantity/unit + name extraction, role qualifier, multi-name.
`confident` is false when required data is missing → the executor asks instead of guessing.

## §4 — Conversation context (done in `196a2d7`)
`lib/services/conversation_context_service.dart` persists `lastPeople` (with **stable record ids**)
and a **pending operation** (30-minute TTL, disambiguation options with ids). `absent_today` stores
absentees by id, so «سجلهم حضور» runs on those exact records. Follow-up answers complete the
original operation; duplicate names are resolved via numbered options.

## §5 — Financial/entity safety (done in `196a2d7`)
`_addEmployee` never invents a salary (asks) and refuses exact-duplicate names. Ambiguous names stop
and ask instead of auto-creating or acting on the wrong record.

## §6 — Storage safety and data integrity (this session)
`lib/services/storage_service.dart` rewritten:
- **Tolerant reads** — a single corrupt JSON record is skipped and logged; the rest of the list is
  still returned and the app never crashes. **Nothing is auto-deleted**: the original stored value
  is left untouched (proven by a test that asserts the stored list still has both entries).
  `StorageService.lastCorruptCount` exposes how many records were skipped.
- **Verified writes** — if `setStringList` returns false (or throws) the write raises
  `StorageException`; no path can report success without a confirmed save.
- **Serialized writes** — every read-modify-write runs through a single gate, so concurrent saves
  cannot lose each other's updates (proven by a 12-way concurrent save test).
- Additive-only JSON; older versions ignore unknown keys, so reverting the APK stays safe.
- `lib/services/app_error_service.dart` adds a bounded local diagnostics log (60 entries, secrets
  redacted) — no keys or personal data are ever written.

## §7 — Chat and voice (this session)
- `lib/services/chat_history_service.dart` **(new)** — persists messages locally with their
  **type** (`user` / `assistant` / `status`) and time, capped at 300; restores them when the screen
  opens; explicit `clear()`; tolerant of a corrupt history (never crashes, never wipes).
- `lib/screens/chat_screen.dart`:
  - messages load from and are written to the persistent history — no more in-memory-only list;
  - the **user message is saved first and is never lost** if the operation fails;
  - a transient **status bubble** («جارٍ التنفيذ…») shows while processing;
  - **double-send is impossible**: a `_busy` guard plus a `_voiceSent` flag, and voice sending now
    happens only in `onResult` (a status change can no longer re-send or drop an utterance);
  - the recognized speech is shown as the user's own bubble, so it is always reviewable;
  - an AppBar menu offers **«مسح المحادثة»** (explicit user-requested clear, §4).

## §8 — Unified error handling (this session)
- `lib/services/app_error_service.dart` **(new)** — classifies errors (`storage` / `network` /
  `notification` / `input` / `unexpected`), logs technical detail locally with secrets redacted, and
  returns a **plain Arabic message** with no exception text, no file paths and no internal names.
- `AssistantController` now runs every dispatch through `_safeDispatch`, so no raw exception can
  reach the user; failures surface as honest messages (e.g. «لم نتمكن من حفظ العملية. لم يتم تأكيد
  تسجيلها.») and **never** as success or as a generic «لم أفهم».
- `chat_screen` no longer prints `❌ $e`; it uses `AppErrorService.userMessage(e)`.
- Notifications: `schedule_failed` copy changed to «تم تسجيل العملية بنجاح، لكن تعذر ضبط التذكير.
  تقدر تتابع إعدادات التنبيهات.» (no developer-facing screen names).
- `main.dart` startup is resilient: a notification-service failure is logged and never blocks the
  app or any local operation.

## §9 — Gemini optional, key field restored in Settings (Session 1 removed it; Session 3 restored it)
Session 1 (`196a2d7`) removed the API-key field from the Settings UI entirely, reading `my best
agint.md` §9 ("hidden from the product") as "no field at all". That directly contradicts the
*active* task brief (`sonnet_come_back.md` §8): "Do not remove the existing Gemini API-key field
from Settings... I specifically need to test the application in two modes." The owner's
2026-10-16 instruction confirmed this explicitly: keep Gemini alongside offline, chat must work
in both modes.

**Session 3 fix** (smallest safe change — UI + strings only, zero business-logic changes):
- `lib/screens/settings_screen.dart`: added a "Gemini key (optional)" section — `TextField`
  (obscured, with a show/hide toggle), a save button (`StorageService.setApiKey`) and a clear
  button, plus a configured/not-configured status line. `StorageService.apiKey` /
  `StorageService.setApiKey` already existed and were already wired into
  `AssistantController._handleWithGemini` (`196a2d7`) — only the UI was missing. No change to
  `gemini_service.dart`, `assistant_controller.dart`, or the local-engine-first dispatch order.
- `lib/design/strings.dart`: added `gemini_section_note`, `clear_key`, `key_cleared`,
  `key_configured`, `key_not_configured` (ar + en). `gemini_key`/`gemini_hint`/`save_key`/
  `saved`/`key_note` already existed from before Session 1 removed the field — reused as-is.
- `README_AR.md`: corrected the two lines that claimed no key field exists.
- The local command engine is still the **default and primary** path for every supported
  operation; the key only ever affects the optional Gemini fallback for phrasing the local
  parser doesn't recognize. An empty/missing key is still the out-of-the-box state.

## §11 — Tests
- `test/local_command_parser_test.dart` (18) — parser, fully offline.
- `test/storage_and_error_test.dart` (**new, 11**) — corrupt-record tolerance (no data wipe),
  concurrent-write safety, error classification + secret redaction, chat-history persistence,
  explicit clear, corrupt-history tolerance.
- Pre-existing: `test/employee_test.dart` (6), `test/supplier_test.dart` (8), `test/model_test.dart` (1).
- `test/gemini_live_test.dart` (3, tag `live`) — real end-to-end; **auto-skipped** without
  `GEMINI_API_KEY`; the key is never stored in the repo.
- `test/storage_and_error_test.dart` (Session 3, **+4**): `StorageService.apiKey` empty by
  default, save/read round-trip, clear-returns-empty, and a `testWidgets` regression guard that
  pumps `SettingsScreen` and asserts the key `TextField` exists and `save_key` actually persists
  the entered value via `StorageService`. This is the repo's **first widget test** — see the
  honest caveat below.
- **Total offline (Session 2 count): 42/42 pass. Session 3 adds 4 more (not yet CI-confirmed —
  see "Honest status").**

## §12 — Docs
`README_AR.md` rewritten (offline-first behaviour, how to run/test, what works offline, limits).
`CHANGELOG.md` 1.2.0+3. `pubspec.yaml` 1.2.0+3.

## Analyzer
`flutter analyze` → **0 issues**. The last five pre-existing warnings (unused imports/fields/getters
in `main_shell`, `rules_service`, `staff_screen`, `supplier_details_screen`, `today_screen`) were
removed in this session.

## Frozen / out of scope (by user instruction)
- **Timezone / Africa-Cairo** and **notifications** — behaviour untouched. The only notification
  change in this session is the wording of the failure message (§8).
- The notification-diagnostics screen was deliberately left in place (notifications are frozen).

## Still not verified
Device-level behaviour (photo picker, notification delivery after reboot, chat→attendance on a real
phone) is **untested** — CI proves compile + packaging only.

## Recovery instructions
1. Read this file.
2. `flutter pub get && flutter analyze && flutter test --exclude-tags live`.
3. Optional live AI check: `GEMINI_API_KEY=... flutter test test/gemini_live_test.dart`.
4. Push to `main` → GitHub Actions builds → release `build-<run_number>`.

## Honest status
§3, §4, §5, §6, §7, §8, §9, §11, §12 are implemented and were **verified locally in Session 2**
(0 analyzer issues, 42/42 tests). Session 3 (the Gemini-key restoration) is **not locally
verified** — there is no Flutter/Dart SDK in this sandbox, so `flutter analyze` / `flutter test`
could not be run before pushing. What Session 3 *did* verify before pushing: brace/paren/bracket
balance across every changed file (script-checked, matched), `git diff --stat` scoped to exactly
the 4 intended files, and a manual read of the diff against the existing design-system and
string-table conventions used elsewhere in the same files. The actual compile/test/widget-test
result is whatever the pushed commit's CI run reports — read that run's conclusion (and, if red,
its `build_log_tail.txt` release asset) before treating this change as verified; don't infer
success from the diff alone. Device-level checks (does the saved key actually reach a live
Gemini call on a real phone) remain outstanding, as before.
