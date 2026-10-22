import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../design/format.dart';
import '../design/tokens.dart';
import '../models/commitment.dart';
import '../models/rule.dart';
import '../services/local_command_parser.dart';
import '../services/recurrence.dart';
import '../services/reminder_manager.dart';
import '../services/reminder_service.dart';

/// اختيار وقت زي منبه الموبايل: ساعة (١–١٢) + دقيقة (٠٠–٥٩) + ص/م.
class AlarmTimeField extends StatelessWidget {
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;
  const AlarmTimeField({super.key, required this.time, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Recurrence.to12(time.hour);
    void emit(int h12, int minute, bool pm) => onChanged(
        TimeOfDay(hour: Recurrence.hour24(h12, pm), minute: minute));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الوقت', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const ValueKey('alarm-hour'),
                initialValue: t.hour12,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'ساعة', isDense: true),
                items: [
                  for (var h = 1; h <= 12; h++)
                    DropdownMenuItem(value: h, child: Text('$h')),
                ],
                onChanged: (v) => emit(v ?? t.hour12, time.minute, t.pm),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const ValueKey('alarm-minute'),
                initialValue: time.minute,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'دقيقة', isDense: true),
                items: [
                  for (var m = 0; m < 60; m++)
                    DropdownMenuItem(
                        value: m, child: Text(m.toString().padLeft(2, '0'))),
                ],
                onChanged: (v) => emit(t.hour12, v ?? time.minute, t.pm),
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<bool>(
              key: const ValueKey('alarm-ampm'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('ص')),
                ButtonSegment(value: true, label: Text('م')),
              ],
              selected: {t.pm},
              onSelectionChanged: (s) => emit(t.hour12, time.minute, s.first),
            ),
          ],
        ),
      ],
    );
  }
}

const _freqLabels = {
  'once': 'مرة واحدة',
  'daily': 'يومي',
  'weekly': 'أسبوعي',
  'monthly': 'شهري',
};
const _weekdayLabels = {
  1: 'الإثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

/// نافذة إنشاء/تعديل تذكير. بترجّع رسالة نجاح (String) أو null لو اتلغت.
/// - [oneOff]: تعديل تذكير لمرة واحدة. - [rule]: تعديل قاعدة متكررة.
Future<String?> showReminderEditor(BuildContext context,
    {Commitment? oneOff, FollowUpRule? rule}) {
  return showDialog<String>(
    context: context,
    builder: (_) => ReminderEditorDialog(oneOff: oneOff, rule: rule),
  );
}

class ReminderEditorDialog extends StatefulWidget {
  final Commitment? oneOff;
  final FollowUpRule? rule;
  const ReminderEditorDialog({super.key, this.oneOff, this.rule});

  @override
  State<ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<ReminderEditorDialog> {
  late final TextEditingController _text;
  late final TextEditingController _amount;
  late final TextEditingController _monthDay;
  final String _id = const Uuid().v4(); // ثابت للنموذج: ضغطتين = تذكير واحد
  late String _freq;
  late int _weekday;
  late DateTime _date;
  late TimeOfDay _time;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.oneOff != null || widget.rule != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final c = widget.oneOff;
    final r = widget.rule;
    _text = TextEditingController(text: c?.textOriginal ?? r?.text ?? '');
    final amt = c?.amount ?? r?.amount;
    _amount = TextEditingController(
        text: amt == null ? '' : amt.toStringAsFixed(amt % 1 == 0 ? 0 : 2));
    _freq = r?.frequency ?? 'once';
    _weekday = (r?.frequency == 'weekly' ? r!.anchor : now.weekday).clamp(1, 7);
    _monthDay = TextEditingController(
        text: '${r?.frequency == 'monthly' ? r!.anchor : now.day}');
    // الافتراضي: بعد ساعة تقريبًا (مش وقت فات).
    final base = c?.remindAt ?? r?.nextDue ?? now.add(const Duration(hours: 1));
    _date = DateTime(base.year, base.month, base.day);
    _time = TimeOfDay(hour: base.hour, minute: base.minute);
  }

  @override
  void dispose() {
    _text.dispose();
    _amount.dispose();
    _monthDay.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(DateTime(today.year, today.month, today.day))
          ? today
          : _date,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 5),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _text.text.trim();
    double? amount;
    if (_amount.text.trim().isNotEmpty) {
      amount = double.tryParse(LocalCommandParser.normalize(_amount.text.trim()));
      if (amount == null || amount < 0) {
        setState(() => _error = 'المبلغ لازم يكون رقم.');
        return;
      }
    }
    final String message;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_freq == 'once') {
        final when = DateTime(
            _date.year, _date.month, _date.day, _time.hour, _time.minute);
        final err = ReminderManager.validateOneOff(text, when);
        if (err != null) {
          setState(() {
            _error = err;
            _saving = false;
          });
          return;
        }
        final ReminderOutcome? out;
        if (widget.oneOff != null) {
          out = await ReminderManager.updateOneOff(widget.oneOff!,
              text: text, amount: amount, when: when);
        } else {
          out = await ReminderManager.createOneOff(
              text: text, amount: amount, when: when, id: _id);
        }
        message = '✅ اتحفظ — التنبيه ${arabicDateTime12(when)}${out?.warningSuffix ?? ''}';
      } else {
        final anchor = _freq == 'monthly'
            ? (int.tryParse(LocalCommandParser.normalize(_monthDay.text.trim())) ?? 0)
            : (_freq == 'weekly' ? _weekday : 1);
        final err = ReminderManager.validateRule(text, _freq, anchor);
        if (err != null) {
          setState(() {
            _error = err;
            _saving = false;
          });
          return;
        }
        final ReminderOutcome? out;
        if (widget.rule != null) {
          out = await ReminderManager.updateRule(widget.rule!,
              text: text,
              amount: amount,
              frequency: _freq,
              anchor: anchor,
              hour: _time.hour,
              minute: _time.minute);
        } else {
          out = (await ReminderManager.createRule(
                  text: text,
                  amount: amount,
                  frequency: _freq,
                  anchor: anchor,
                  hour: _time.hour,
                  minute: _time.minute,
                  id: _id))
              .outcome;
        }
        message = '✅ اتحفظت القاعدة${out?.warningSuffix ?? ''}';
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'حصلت مشكلة أثناء الحفظ. حاول تاني.';
          _saving = false;
        });
      }
      return;
    }
    if (mounted) Navigator.pop(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final freqLocked = widget.oneOff != null;
    final freqs = widget.rule != null
        ? const ['daily', 'weekly', 'monthly']
        : (freqLocked ? const ['once'] : const ['once', 'daily', 'weekly', 'monthly']);
    return AlertDialog(
      title: Text(_editing ? 'تعديل التذكير' : 'تذكير / قاعدة جديدة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('reminder-text'),
              controller: _text,
              decoration: const InputDecoration(
                  labelText: 'نص التذكير (مثل: دفع الإيجار)'),
            ),
            TextField(
              key: const ValueKey('reminder-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ (اختياري)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey('reminder-freq'),
              initialValue: _freq,
              items: [
                for (final f in freqs)
                  DropdownMenuItem(value: f, child: Text(_freqLabels[f]!)),
              ],
              onChanged: freqs.length == 1
                  ? null
                  : (v) => setState(() => _freq = v ?? 'once'),
              decoration: const InputDecoration(labelText: 'التكرار'),
            ),
            const SizedBox(height: 8),
            if (_freq == 'once')
              OutlinedButton.icon(
                key: const ValueKey('reminder-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(arabicDate(_date)),
              ),
            if (_freq == 'weekly')
              DropdownButtonFormField<int>(
                key: const ValueKey('reminder-weekday'),
                initialValue: _weekday,
                items: [
                  for (final e in _weekdayLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _weekday = v ?? 1),
                decoration: const InputDecoration(labelText: 'يوم الأسبوع'),
              ),
            if (_freq == 'monthly')
              TextField(
                key: const ValueKey('reminder-monthday'),
                controller: _monthDay,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'يوم الشهر (1-31)'),
              ),
            const SizedBox(height: 12),
            AlarmTimeField(
                time: _time, onChanged: (t) => setState(() => _time = t)),
            const SizedBox(height: 8),
            Text(
              _freq == 'once'
                  ? 'هيوصلك التنبيه ${arabicDate(_date)} الساعة ${clockTime12(DateTime(2000, 1, 1, _time.hour, _time.minute)).replaceAll(RegExp(r"^0"), "")}'
                  : 'هيتكرر في نفس الساعة ${clockTime12(DateTime(2000, 1, 1, _time.hour, _time.minute))}',
              style: const TextStyle(fontSize: 12),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء')),
        FilledButton(
            key: const ValueKey('reminder-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'جاري الحفظ…' : 'حفظ')),
      ],
    );
  }
}
