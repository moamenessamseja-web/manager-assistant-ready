import 'package:flutter/material.dart';
import '../models/rule.dart';
import '../services/storage_service.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});
  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  String _freq = 'monthly';

  @override
  Widget build(BuildContext context) {
    final rules = StorageService.rules();
    return Scaffold(
      appBar: AppBar(title: const Text('القواعد والتنبيهات')),
      body: rules.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا يوجد قواعد متابعة بعد.\nمثال من الشات: "كل أول الشهر فكرني بالإيجار 8000"',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: rules.map((r) {
                final freqAr = {'monthly': 'شهرية', 'weekly': 'أسبوعية', 'daily': 'يومية'}[r.frequency] ?? r.frequency;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Icon(r.active ? Icons.notifications_active : Icons.notifications_off),
                    title: Text(r.text),
                    subtitle: Text('$freqAr — القادمة: ${r.nextDue.toString().substring(0, 10)}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Switch(
                        value: r.active,
                        onChanged: (v) async {
                          r.active = v;
                          await StorageService.saveRule(r);
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await StorageService.deleteRule(r.id);
                          setState(() {});
                        },
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton(onPressed: _addRule, child: const Icon(Icons.add_alarm)),
    );
  }

  void _addRule() {
    final text = TextEditingController();
    final amount = TextEditingController();
    final anchor = TextEditingController(text: '1');
    _freq = 'monthly';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('قاعدة متابعة جديدة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: text, decoration: const InputDecoration(labelText: 'نص القاعدة (مثل: فكرني بالإيجار)')),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (اختياري)')),
            DropdownButtonFormField<String>(
              value: _freq,
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('شهرية')),
                DropdownMenuItem(value: 'weekly', child: Text('أسبوعية')),
                DropdownMenuItem(value: 'daily', child: Text('يومية')),
              ],
              onChanged: (v) => setD(() => _freq = v ?? 'monthly'),
              decoration: const InputDecoration(labelText: 'التكرار'),
            ),
            if (_freq != 'daily')
              TextField(
                controller: anchor,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: _freq == 'monthly' ? 'يوم الشهر (1-31)' : 'يوم الأسبوع (1=إثنين..7=أحد)'),
              ),
          ]),
          actions: [
            TextButton(
              onPressed: () async {
                if (text.text.trim().isEmpty) return;
                final a = int.tryParse(anchor.text) ?? 1;
                final now = DateTime.now();
                DateTime next;
                if (_freq == 'weekly') {
                  final addDays = (a - now.weekday) % 7;
                  next = DateTime(now.year, now.month, now.day, 9).add(Duration(days: addDays == 0 ? 7 : addDays));
                } else if (_freq == 'daily') {
                  next = DateTime(now.year, now.month, now.day, 9).add(const Duration(days: 1));
                } else {
                  var y = now.year, m = now.month;
                  if (now.day >= a) {
                    m++;
                    if (m > 12) {
                      m = 1;
                      y++;
                    }
                  }
                  final lastDay = DateTime(y, m + 1, 0).day;
                  next = DateTime(y, m, a.clamp(1, lastDay), 9);
                }
                await StorageService.saveRule(FollowUpRule(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  text: text.text.trim(),
                  frequency: _freq,
                  anchor: a,
                  amount: double.tryParse(amount.text),
                  nextDue: next,
                ));
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
