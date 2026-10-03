import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/assistant_controller.dart';
import '../design/tokens.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _S();
}

class _S extends State<ChatScreen> {
  final c = TextEditingController();
  final sp = SpeechToText();
  bool listening = false, busy = false;
  final msgs = <Map<String, String>>[];

  Future<void> send(String s) async {
    if (s.trim().isEmpty || busy) return;
    setState(() {
      msgs.add({'r': 'u', 't': s});
      busy = true;
      c.clear();
    });
    try {
      final r = await AssistantController.handle(s);
      setState(() => msgs.add({'r': 'a', 't': r}));
    } catch (e) {
      setState(() => msgs.add({'r': 'a', 't': '❌ $e'}));
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> listen() async {
    if (listening) {
      await sp.stop();
      setState(() => listening = false);
      return;
    }
    if (await sp.initialize()) {
      setState(() => listening = true);
      await sp.listen(
        localeId: 'ar_EG',
        onResult: (r) {
          if (r.finalResult) {
            setState(() => listening = false);
            send(r.recognizedWords);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext x) => Scaffold(
        appBar: AppBar(title: const Text('مساعد الإدارة')),
        body: Column(children: [
          Expanded(
            child: msgs.isEmpty
                ? const Center(
                    child: Text(
                      'اتكلم طبيعي…\nمثال: أحمد عليه 3500 هيدفع الخميس ذكرني الأربعاء',
                      textAlign: TextAlign.center,
                      style: AppText.bodyMuted,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpace.x2),
                    itemCount: msgs.length,
                    itemBuilder: (c, i) {
                      final m = msgs[i];
                      final isUser = m['r'] == 'u';
                      // AlignmentDirectional بدل Alignment الفعلي: بيحترم اتجاه
                      // الواجهة (RTL هنا) بدل ما يفترض يمين/شمال ثابتة.
                      return Align(
                        alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                        child: Card(
                          color: isUser ? AppColors.primaryLight : null,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.x3),
                            child: Text(m['t']!),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(AppSpace.x2),
            child: Row(children: [
              IconButton(onPressed: listen, icon: Icon(listening ? Icons.mic_off : Icons.mic)),
              Expanded(
                child: TextField(
                  controller: c,
                  onSubmitted: send,
                  decoration: const InputDecoration(hintText: 'اكتب ما تريد تسجيله…'),
                ),
              ),
              IconButton(onPressed: () => send(c.text), icon: const Icon(Icons.send)),
            ]),
          ),
        ]),
      );
}
