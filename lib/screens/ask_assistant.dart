import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../design/tokens.dart';
import '../services/app_error_service.dart';
import '../services/assistant_controller.dart';
import '../services/chat_history_service.dart';
import '../services/choice_builder.dart';
import '../services/conversation_context_service.dart';

/// حقل «اسأل المساعد» — مكوّن مشترك لـ«اليوم» والـ Brief. بيفتح ورقة سفلية
/// فيها محادثة مصغّرة بنفس المحرك (نفس التحقق والأزرار)، فمفيش منطق مكرر.
class AskAssistantBar extends StatefulWidget {
  const AskAssistantBar({super.key});

  @override
  State<AskAssistantBar> createState() => _AskAssistantBarState();
}

class _AskAssistantBarState extends State<AskAssistantBar> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    _c.clear();
    showAskAssistantSheet(context, initialText: t, autoSend: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _c,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _go(),
              decoration: const InputDecoration(
                hintText: 'اسأل المساعد…',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'إرسال',
            icon: const Icon(Icons.send_rounded),
            onPressed: _go,
          ),
        ],
      ),
    );
  }
}

/// يفتح ورقة «اسأل المساعد». [contextNote] سطر توضيحي للسياق (مش بيتبعت
/// للمحرك ولا بيتخترع منه معلومات). [autoSend] بيبعت [initialText] فورًا.
Future<void> showAskAssistantSheet(
  BuildContext context, {
  String initialText = '',
  bool autoSend = false,
  String? contextNote,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _AskSheet(
      initialText: initialText,
      autoSend: autoSend,
      contextNote: contextNote,
    ),
  );
}

class _Line {
  final bool user;
  final String text;
  const _Line(this.user, this.text);
}

class _AskSheet extends StatefulWidget {
  final String initialText;
  final bool autoSend;
  final String? contextNote;
  const _AskSheet(
      {required this.initialText, required this.autoSend, this.contextNote});

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _c = TextEditingController();
  final _lines = <_Line>[];
  bool _busy = false;
  List<ChatChoice> _choices = const [];
  String? _pendingId;

  @override
  void initState() {
    super.initState();
    _c.text = widget.initialText;
    ConversationContextService.init().then((_) {
      if (mounted) setState(_refresh);
    });
    if (widget.autoSend && widget.initialText.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _refresh() {
    final p = ConversationContextService.pending();
    _pendingId = p?.id;
    _choices = ChoiceBuilder.forPending(p);
  }

  Future<void> _send() {
    final t = _c.text.trim();
    if (t.isEmpty || _busy) return Future.value();
    _c.clear();
    return _run(t, (id) => AssistantController.handle(t, messageId: id));
  }

  Future<void> _choice(ChatChoice c) {
    final id = _pendingId;
    if (id == null || _busy) return Future.value();
    return _run(c.label, (_) => AssistantController.handleChoice(id, c));
  }

  Future<void> _run(String shown, Future<String> Function(String id) action) async {
    setState(() {
      _busy = true;
      _lines.add(_Line(true, shown));
    });
    final mid = const Uuid().v4();
    // نفس سجل الشات: اللي بيتقال هنا بيظهر كمان في تبويب المحادثة.
    try {
      await ChatHistoryService.init();
      await ChatHistoryService.append(ChatMessage(
          id: mid, role: ChatRole.user, text: shown, time: DateTime.now()));
    } catch (e, st) {
      AppErrorService.log('ask.saveUser', e, st);
    }
    String reply;
    try {
      reply = await action(mid);
    } catch (e, st) {
      AppErrorService.log('ask.handle', e, st);
      reply = AppErrorService.userMessage(e);
    }
    try {
      await ChatHistoryService.append(ChatMessage(
          id: const Uuid().v4(),
          role: ChatRole.assistant,
          text: reply,
          time: DateTime.now()));
    } catch (e, st) {
      AppErrorService.log('ask.saveReply', e, st);
    }
    if (!mounted) return;
    setState(() {
      _lines.add(_Line(false, reply));
      _busy = false;
      _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('اسأل المساعد',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ),
          if (widget.contextNote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(widget.contextNote!, style: AppText.caption),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: h * 0.4),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                children: [
                  for (final l in _lines)
                    Align(
                      alignment: l.user
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: l.user
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(l.text),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_choices.isNotEmpty && !_busy)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in _choices)
                    ActionChip(
                      label: Text(c.label),
                      avatar: c.kind == ChoiceKind.cancel
                          ? const Icon(Icons.close, size: 16)
                          : null,
                      onPressed: () => _choice(c),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'اكتب سؤالك أو اختر من الأزرار',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'إرسال',
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _busy ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
