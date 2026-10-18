Manager Assistant — Implementation Plan and Development Instructions

1. Agreement and Overall Direction

Your analysis is correct and well aligned with the product goals. Proceed with the agreed direction and priorities, while following the product requirements and implementation order described below.

The goal is to make Manager Assistant a reliable business assistant that works offline first, understands common Egyptian Arabic expressions, asks clear questions when information is missing or ambiguous, and helps users complete tasks without leaving the current screen.

I am not a programmer. Keep the implementation easy to maintain, explain important decisions in simple language, and do not ask me to make unnecessary technical decisions.

Start working immediately. Do not stop after creating another plan or asking for approval on routine implementation decisions. Review the existing code, preserve the verified baseline, and implement the approved scope in two phases.

2. Verified Baseline and Repository Safety

Repository:

"https://github.com/moamenessamseja-web/manager-assistant-ready"

Verified working commit:

"fea404ffdf4c06b5ceff2a36dfba6c287a969c7d"

Build 82 was downloaded and manually tested. Its behavior was confirmed to be satisfactory.

Before making any changes:

1. Inspect the current repository, branches, working tree status, and commit history.
2. Verify that the specified commit exists, identify the current branch, and check the status of the main branch.
3. Compare the current code with the verified Build 82 baseline.
4. Preserve all correct work already completed in phases B–F.
5. Review the current parser, "extractSlots", "pending-operation" handling, storage implementation, chat interface, Today screen, Brief screen, and existing tests.
6. Identify all existing functionality that must be preserved.

Do not overwrite working changes, delete commits, or revert to an older commit without a clear technical reason.

If Build 82 has not been merged, prepare a safe merge path and run the required checks before merging. Do not blindly merge unverified or conflicting changes.

3. Phase One — Core Product Improvements

Complete priorities 1 through 5 before starting Phase Two.

Priority 1 — Stabilize and Protect the Verified Baseline

- Preserve the functionality of Build 82.
- Verify the actual branch and commit history before merging any existing work.
- Resolve conflicts carefully.
- Run the current tests and CI checks.
- Investigate failures instead of deleting tests or weakening validations to make the build pass.
- Record the verified baseline and the changes made during this phase.

The objective is to improve the application without losing behavior that already works.

Priority 2 — Improve Arabic Number Understanding and Local Context

Implement a deterministic, layered local parser that distinguishes between monetary amounts, product quantities, dates, times, and other relevant fields.

Do not rely on one exact sentence or one fixed phrase for each operation.

A. Monetary Amount Indicators

Classify a number as a monetary amount when the surrounding words provide a sufficiently clear financial signal.

Useful Egyptian Arabic indicators include:

- "جنيه"
- "جنية"
- "ج"
- "جنيه مصري"
- "دولار"
- "دولارات"
- "مبلغ"
- "فلوس"
- "مبلغ مالي"

Examples:

- "دفعت 500 جنيه" → monetary amount: 500.
- "المبلغ 1200" → monetary amount: 1200 when the context clearly identifies the field as an amount.
- "معايا 200 دولار" → monetary amount: 200, with the currency recorded when currency support is available.

Normalize common spelling variations such as "جنيه" and "جنية" while preserving the intended meaning.

Important: short abbreviations such as "ج" can be ambiguous. Use surrounding words and the current operation context instead of treating every isolated occurrence as definitive evidence of currency.

B. Quantity Indicators and Measurement Units

A number followed by a known product unit should normally be interpreted as a quantity rather than money.

The current application already allows users to enter supplier units such as kilo, carton, and similar units. The chat parser should use the unit keywords that appear after the number.

For example:

"توريد من محمد ٢٠ زجاجة عصير"

There is no explicit currency indicator, but the words "توريد", "محمد", and "عصير" identify a supplier transaction and product context. Therefore, the number should be interpreted as a quantity. The measurement unit already exists in the supplier profile, and the current manual-entry flow already supports supplier name, product, quantity, unit, unit price, and notes. Treat these existing fields and values as contextual signals.

This guidance may also be added to the instructions page in the side navigation.

Support common Egyptian expressions and spelling variations, including:

- "كيلو" and "كيلوجرام"
- "ك" when its meaning is clear from context
- "كرتونة"
- "كرتونه"
- "كرتون"
- "صندوق"
- "زجاجة"
- "ازازة"
- "علبة"
- "علبه"
- "باكو"
- "كيس"
- "شكارة"
- "كوباية"
- "كوبايه"
- "كوب"
- "فنجان"

Also support other common measurement and packaging units that already appear in the application or in realistic user examples.

Examples:

- "اشتريت 5 كراتين" → quantity: 5.
- "عندي 3 كيلو سكر" → quantity: 3 kilograms.
- "اشتريت 12 زجاجة" → quantity: 12.
- "دفعت 500 جنيه" → amount: 500, not quantity: 500.

These are initial examples, not an exhaustive dictionary.

Design unit recognition so that new units and spelling variations can be added and tested without rewriting the entire parser.

Do not assume that every number without a unit is money or that every number is a quantity. Use the current operation, nearby words, and conversation context.

C. Keep Parsed Fields Separate

Maintain a strict separation between the following concepts throughout parsing and storage:

- Monetary amount
- Quantity
- Unit
- Currency
- Transaction type
- Product, customer, or supplier
- Date
- Time
- Reminder or commitment details

Do not automatically copy the same number into multiple fields merely because the parser is uncertain.

D. Normalize Arabic Carefully

Handle common variations such as:

- Different spellings and colloquial expressions.
- Arabic-Indic and Western digits.
- Extra spaces and punctuation.
- Common spelling variations.
- Egyptian dialect phrasing.
- Reasonable variations in word order.

Normalization must not remove information needed to understand amounts, names, units, dates, or times.

E. Ask Instead of Guessing

When a number could reasonably represent either money or quantity, ask a short clarification question.

For example:

الرقم 500 تقصد بيه إيه؟

[مبلغ مالي] [كمية] [إلغاء]

Use the actual conversation context to customize the question and options.

Do not save an important financial transaction when the amount, quantity, transaction type, or related entity is uncertain.

Priority 3 — Contextual Chat Buttons and Pending Operations

Improve the existing "pending-operation" and "extractSlots" implementation where necessary.

Add clickable suggestion buttons that are connected to the current context and help users complete an operation without repeatedly re-entering information.

Examples:

When the transaction type is unclear:

[مشتريات] [مبيعات] [مصروفات]

When the customer or supplier is unclear:

[أحمد] [محمد] [مورد آخر]

When a required field is missing:

Ask for the missing field and provide useful choices whenever possible.

When confirmation is required:

[تأكيد الحفظ] [تعديل] [إلغاء]

Requirements:

1. Buttons must reflect the actual pending operation and its missing or ambiguous fields.
2. Every button action must be linked to the correct operation identifier.
3. Older buttons must never modify a newer operation by mistake.
4. Validate every selected value before saving.
5. Support correction, cancellation, and completion of incomplete operations.
6. Prevent duplicate recording if the user presses a button multiple times.
7. Make the interaction suitable for small screens.
8. Keep button labels short, clear, and natural in Egyptian Arabic.

Do not implement buttons as visual elements only. They must be connected to the actual application logic.

Priority 4 — Add Contextual Guidance to Today Cards

Contextual guidance should appear both in the conversation and in Today screen cards.

Improve the existing Today cards so users can understand the displayed information and act on it without unnecessary navigation.

When appropriate, provide actions such as:

- View details.
- Ask the assistant about the item.
- Complete missing information.
- Confirm or correct a suggested action.
- Open the related record.

Available actions must depend on the actual card type and application state.

For example, if a reminder or commitment card contains missing information, provide an appropriate action to complete it.

Preserve the current card behavior and existing design rules. Do not redesign the entire screen unless necessary.

Priority 5 — Add an Instructions Page and Contextual Assistant Entry Points

A. Add an Instructions Page

Add an item to the existing side navigation menu near Settings and the other current items.

Use a clear Arabic label such as:

تعليمات الاستخدام

The page must explain how to use Manager Assistant through practical examples rather than technical terminology.

Organize the content into short sections, such as:

1. Recording purchases and sales.
2. Entering monetary amounts.
3. Entering product quantities and units.
4. Working with customers and suppliers.
5. Creating reminders and commitments.
6. Understanding clarification questions and suggestion buttons.
7. Correcting an operation before saving.
8. Understanding what the assistant can and cannot do offline.

Examples of user guidance:

- "دفعت 500 جنيه" — explains how to express a monetary amount.
- "اشتريت 5 كراتين" — explains how to express a product quantity.
- "فكرني بكرة الساعة 5" — explains how reminder requests work and that the application may ask for clarification.

These are examples, not mandatory commands. The parser must support reasonable variations in wording.

The instructions page should be written in natural, simple Egyptian Arabic. Keep it concise, useful, and easy to update when new features are added.

Do not claim that every possible phrasing is supported.

B. Add an “Ask the Assistant” Entry Point to Today

Add a chat field or a clear assistant entry point to the Today screen with the title:

اسأل المساعد

Users must be able to ask a question or start a supported operation directly from this screen without first navigating to a separate chat screen.

When possible, preserve the current screen context so the assistant can help with the visible card, reminder, commitment, or related record.

For example, a user viewing a reminder should be able to ask about that reminder directly.

Do not invent unavailable context. If the reference is ambiguous, ask the user which item they mean.

C. Add the Same Capability to Brief

Provide a similar assistant entry point on the Brief screen.

Users must be able to ask questions or start supported operations directly from Brief.

Preserve relevant screen context when it is safe and clear to do so.

Avoid duplicating business logic between screens. Reuse shared chat and assistant components where appropriate.

D. Consistency and Usability

The chat, Today cards, Brief screen, and instructions page must work together as one coherent experience.

Use consistent terminology in suggestion buttons and instructional text.

Do not require users to memorize special commands. The application should guide them through natural conversational input.

4. Phase Two — Reliability, Offline Operation, and Release Readiness

Start Phase Two after Phase One has been implemented and verified. The following priorities remain part of the overall plan, but release and payment activities must not block ongoing development.

Priority 6 — Permanent Duplicate Prevention

The current eight-second in-memory duplicate guard is insufficient.

Implement a persistent mechanism that prevents duplicate transactions from being recorded.

Requirements:

- Assign a stable unique identifier to each operation or incoming command when needed.
- Link clarification buttons to the operation identifier they belong to.
- Check whether an operation has already been processed before writing.
- Ensure duplicate prevention survives application restarts.
- Prevent repeated taps or retries from recording the same transaction twice.
- Handle concurrent attempts safely.
- Do not add a database migration solely for this improvement.

Choose an implementation compatible with the current storage system.

If the current storage cannot safely guarantee duplicate prevention without a larger change, document the limitation and implement the safest, most maintainable solution possible.

Priority 7 — Remove Gemini and External AI Dependencies

Remove Gemini only after local parsing, clarification flows, and interaction paths have been implemented and tested.

Review the entire project for:

- Gemini SDK usage.
- API keys and configuration.
- External AI requests.
- HTTP clients and network callers.
- Unnecessary network permissions.
- Secrets or credentials that may have been committed to the repository.

Remove unused dependencies and permissions only after confirming that no remaining functionality requires them.

Do not replace Gemini with another external AI API.

The target architecture is offline-first. Normal parsing, clarification, supported business operations, and local data access must work without an external AI service.

Speech recognition may rely on device-installed speech services. Preserve reliable text input as a fallback and clearly handle speech recognition unavailability.

Do not claim that the entire application works offline until this has been verified.

If an API key previously exposed in the repository may still be valid, recommend revoking and replacing it through the appropriate secure process. Never print secrets in logs or documentation.

Priority 8 — Backup, Storage Abstraction, and Future Readiness

A. Backup and Restore

Implement reliable backup/export and import/restore functionality before making any risky change to application identity or storage.

Users must be able to export important application data and restore it later.

Include business records and related relationships supported by the current data model.

Requirements:

- Validate imported files before changing existing data.
- Handle corrupted or incompatible files safely.
- Avoid overwriting valid user data without warning.
- Prevent duplicate records during repeated imports whenever possible.
- Provide clear success and failure messages in Arabic.
- Test a complete export and restore cycle.

Backup and restore must not be considered reliable until an actual restore has been tested.

B. Add a Repository Layer Above the Current Storage

Do not migrate to SQLite now.

Add or improve a storage abstraction layer so business logic does not depend directly on low-level storage details.

Preserve the current storage engine and data.

The goal is to make a future migration to SQLite easier if advanced reports, financial summaries, or complex queries later justify it.

Do not perform a database migration as part of this task.

C. Package Identity and Signing — Explicitly Deferred

I am currently replacing my bank cards and arranging a suitable USD payment method. Therefore, Google Play signing and payment-related release steps must be postponed.

Do not block current development because of payment, Play Console registration, signing, or publishing.

For now:

- Continue improving and testing the application locally and through CI.
- Do not change the application package identifier without a reviewed migration plan and explicit authorization.
- Do not create a new signing identity randomly.
- Do not publish a release or make irreversible changes in Play Console.
- Document the current package identifier and signing status.
- Prepare a short recommendation for choosing a permanent package identifier later.

Possible naming directions include Business You, Control, or an Egypt-inspired brand. These are initial ideas and are not final authorization to set the package identifier.

When release work resumes, verify the current Google Play requirements and plan package identity, signing, backup, and installation compatibility together.

D. Google Play and SQLite Later

Review the current Google Play requirements when release preparation becomes appropriate.

Do not assume that old documentation is still accurate. Verify the required target SDK and any active closed-testing rules using the current official requirements.

Avoid adding native dependencies, security products, or build settings without a demonstrated need.

Re-evaluate SQLite when advanced reporting and financial queries become an actual development priority, not merely because the application is approaching release.

5. Local Phrase Review and Improvement

Implement an optional, privacy-conscious method for recording locally misunderstood or corrected phrases.

The purpose is to improve the parser using real examples.

Requirements:

- Make data collection optional and explain its purpose.
- Keep the record on the device by default.
- Do not send phrases automatically.
- Avoid collecting unnecessary financial or personal information.
- Provide a clear way for users to review examples and intentionally share them if they choose.
- Convert reviewed examples into regression tests and explicit parser rules.
- Do not automatically train or modify the parser based on unreviewed user input.

Do not add an on-device LLM as part of this work.

Evaluate third-party libraries only when they solve a demonstrated problem. Consider Egyptian dialect support, offline operation, application size, performance, licensing, maintenance, and device compatibility.

Do not add a large model or new dependency merely because it appears more intelligent.

6. Reminder Date and Time Handling

When a user requests a reminder without specifying a date or time, or when the date or time is ambiguous, ask for the missing information before scheduling the reminder.

Examples:

- "فكرني أكلم أحمد" → ask when.
- "فكرني بكرة" → ask for the time if the current reminder behavior requires a specific time.
- "فكرني الساعة 5" → clarify whether the user means 5 AM or 5 PM, using forms such as "٥ ص", "٥ م", "5 AM", "5 PM", "صباحًا", or "مساءً", then ask for the date if it cannot be safely determined from context.
- Support time formats such as "17:00", "5:00 PM", "٥:٠٠ م", and "الساعة ٥ مساءً".
- When the user writes only "5", do not assume AM or PM if that could create an incorrect reminder.
- Understand Arabic and English time expressions, including "am", "pm", "AM", "PM", "ص", "م", "صباحا", "صباحًا", "مساءا", and "مساءً".
- Display times clearly in responses when needed, such as "٠٥:٠٠ ص", "٠٥:٠٠ م", or "17:00". Both Arabic and English formats may be shown to reduce ambiguity.
- If the assistant cannot understand the time, ask the user to write it clearly, for example: "اكتب الوقت مثل ٥:٠٠ ص أو ٥:٠٠ م أو 17:00 أو 5:00 PM".
- Support Arabic and English weekdays, including السبت/Saturday، الأحد/Sunday، الاثنين/Monday، الثلاثاء/Tuesday، الأربعاء/Wednesday، الخميس/Thursday، and الجمعة/Friday.
- Treat Saturday as the first day of the week when displaying or interpreting weekdays.
- Distinguish between a weekday name and a full calendar date, and support Arabic and Western date formats where possible.
- Do not assume that "السبت القادم" or "الأحد الجاي" refers to one fixed date without considering the current day and application context.
- When the day or date is ambiguous, present clear options instead of guessing.

Use the application’s existing date and time conventions. Do not invent dates, times, or time zones.

When appropriate, provide selectable options such as:

[اليوم] [بكرة] [اختيار تاريخ]

and:

[بعد ساعة] [الساعة 5 صباحًا] [الساعة 5 مساءً] [اختيار وقت]

The options must reflect the actual current context and supported scheduling behavior.

Test reminders around day boundaries, after application restarts, and with the current notification behavior.

Preserve working notification behavior unless a change is necessary and verified.

7. Testing Requirements

Add automated tests for expected behavior and ambiguous cases.

Include realistic Egyptian examples such as:

- "دفعت 500 جنيه"
- "دفعت 500 جنية"
- "المبلغ 1200"
- "اشتريت 5 كراتين"
- "اشتريت 5 كرتونة"
- "عندي 3 كيلو سكر"
- "اشتريت 12 زجاجة"
- "فكرني بكرة الساعة 5 مساءً"
- "فكرني السبت الساعة ٥:٠٠ ص"
- "فكرني يوم Sunday الساعة 5 PM"
- "فكرني 17:00"
- "فكرني الساعة ٠٥:٠٠ م"
- Alternative word order and common spelling variations.
- Arabic-Indic and Western digits.
- Missing amount, quantity, customer, or supplier.
- Truly ambiguous numbers.
- Reminder requests missing a date or time.
- Follow-up answers that complete a pending operation.
- Repeated button presses and duplicate requests.
- Application restart while an operation is incomplete.
- Backup and restore, including invalid import files.
- Offline operation with no external AI requests.

Verify that the parser does not confuse quantities with monetary amounts.

Test the actual UI behavior of suggestion buttons and assistant entry points on Today and Brief.

Do not rely only on unit tests. Run available build and integration tests, and clearly distinguish automated verification from checks that still require a real device.

8. Definition of Done

Do not consider a phase complete until:

- Existing Build 82 functionality is preserved, or any necessary behavior changes are clearly documented.
- The implementation associated with the phase is complete.
- Available automated tests and CI checks pass, or remaining failures are clearly documented.
- No user data is intentionally discarded.
- No external AI requests are made by functionality intended to work locally.
- Ambiguous financial operations are clarified instead of guessed.
- Duplicate prevention is tested against repeated actions and application restarts.
- Arabic guidance and buttons are clear and consistent.
- Backup and restore are not considered complete until restoration has been tested.
- Documentation reflects the actual implementation rather than planned or assumed behavior.

9. Required Documentation and Immediate Actions

Create a Markdown file named "agent.md" in the repository root containing this implementation brief.

Keep it under version control with the project so future work can follow the agreed direction.

Then begin implementation immediately.

Phase One Deliverables

1. Review of the baseline and branches.
2. Safe integration of verified Build 82 work when necessary.
3. Improved local Arabic parsing and ambiguity handling.
4. Improved chat buttons and pending operations.
5. Improved Today cards, an instructions page, and assistant entry points in Today and Brief.
6. Tests and a concise progress report.

Phase Two Deliverables

1. Permanent duplicate prevention.
2. Safe removal of Gemini and unnecessary external AI dependencies.
3. Reliable backup and restore.
4. A storage repository layer without migrating to SQLite.
5. Release-readiness notes covering package identity, signing, and current Play requirements, while postponing payment-related steps.

The numbered priorities define the overall direction. Implement them in the order that best respects dependencies and data-safety requirements.

At the end of each phase, provide a report explaining:

- What changed.
- Which tests and builds passed.
- Any remaining failures or risks.
- The main files and components modified.
- What remains for the next phase.

Write the delivery summary in clear Arabic suitable for a non-technical person.

Final instruction: Preserve verified work, implement the agreed features, test them, and continue making progress. Do not stop at planning, do not migrate to SQLite now, and do not allow payment or Google Play signing delays to block development.