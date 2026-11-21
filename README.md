# Manager Assistant

**Easier Management. Clearer Follow-up. Less Administrative Clutter.**

An Arabic-first app for independent cafés and small businesses. It replaces the paper notebook and the scattered
WhatsApp notes with one place where the owner records what happens during the day and sees what needs attention.

العربية: [README_AR.md](README_AR.md)

## What it helps you manage

| Area | What you can do |
|---|---|
| **Employees** | Attendance and check-out, advances, deductions, bonuses, tips (kept separate from wages), pay by month / day / shift / hour, shift length and pattern (8 h, 12 h, fixed, rotating) |
| **Suppliers** | Deliveries (expected and received), purchases, payments, outstanding balance per supplier |
| **Customer receivables** | Customers, credit sales and extra charges, partial or full payments, opening balances, balance and history per customer |
| **Commitments & reminders** | Local reminders; a customer's *promise to pay* is tracked as a reminder and never changes the balance until a payment is recorded |
| **Daily follow-up** | A Today screen and a weekly Brief that separate *what is owed right now* from *what moved this week* |

### Typing or speaking an entry

The chat accepts short Egyptian Arabic sentences and turns them into the same records the manual screens create:

```
ضيف على حموده ١٠٠ جنيه طلبات بتاريخ ٢٠ نوفمبر     → credit sale
جمال دفع ٢٠٠ جنيه                                  → customer payment
فكرني صبحي هيدفع ٤٠٠ بكرة الساعة ٥ مساءً            → reminder (balance unchanged)
حساب جمال كام؟   /   مين عليه فلوس؟                 → balance / who owes
```

How it works: a **local, rule-based Arabic command engine** (normalisation of Arabic text and digits, intent rules,
field extraction, name matching). It runs on the phone. It does not use any AI service, needs no account and no
API key, and makes no network calls to understand a sentence.

Safety rules the engine follows: it never guesses a missing name, amount, date or direction; it asks a short
question (with tap buttons) instead; a quantity is never read as money; every saved operation is idempotent so a
retry or a double tap cannot record it twice. Success is reported only after the record is actually saved.

## Limitations (please read before selling or deploying)

- **Data lives on the device only.** There is no cloud sync and no multi-device or multi-user business account.
  If the phone is lost, reset or the app is uninstalled, the data is lost.
- **No backup/restore yet.** Until a verified backup feature exists, do not describe the app as having one.
- **Changing the app identity creates a separate installation.** Version `com.moamen.manager_assistant` installs
  *next to* older test builds (`com.example…`) and does not carry their data over.
- **Voice input depends on the phone's own speech service** (and on Arabic being available on it). Recognised text
  is placed in the text box for review and is **never sent automatically**. Typing always works, and the keyboard's
  dictation button is a valid alternative.
- The command engine understands common phrasings, **not every sentence**. When it does not understand, it says so.
- Not a POS, not an inventory system, and **not a legally certified accounting or payroll system**. Figures are
  operational records to help the owner follow up.
- Android is the verified platform. iOS configuration exists but has only been compile-checked, never run on a device.

## For developers

- Flutter 3.47.7 (pinned in CI), Dart 3.13. Local storage via `shared_preferences`, notifications via
  `flutter_local_notifications`, voice via `speech_to_text`.
- `lib/services/local_command_parser.dart` — deterministic parser; `assistant_controller.dart` — validation and
  execution; `storage_service.dart` — serialised, verified writes.
- Offline test suite: `flutter test --exclude-tags live`. The parser and pure models can also be tested with plain
  Dart.
- The Android project is generated in CI (`flutter create --org com.moamen --project-name manager_assistant`);
  application id **`com.moamen.manager_assistant`**.
- Builds: Actions → "Build APK" produces a release APK (analyze + tests first) and publishes it as a GitHub Release for manual download. Signing: Flutter's default (debug) key — not a production signing identity; a private release key is a deliberate later step before any store release.
- Project memory and verification evidence live in `.agent/`.
