import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import '../services/assistant_controller.dart';
import '../services/chat_history_service.dart';
import '../services/app_error_service.dart';
import '../design/tokens.dart';
import '../design/app_theme.dart';

/// شاشة المحادثة — Premium Chat Interface
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _S();
}

class _S extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _stt = SpeechToText();
  bool _busy = false;
  bool _listening = false;

  /// يمنع إرسال النص الصوتي مرتين لنفس جلسة التسجيل (§7).
  bool _voiceSent = false;
  String? _errorMsg;
  final _msgs = <ChatMessage>[];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initStt();
  }

  /// استعادة الرسائل المحفوظة عند فتح الشاشة (§7).
  Future<void> _loadHistory() async {
    await ChatHistoryService.init();
    final saved = ChatHistoryService.all();
    if (!mounted) return;
    setState(() {
      _msgs
        ..clear()
        ..addAll(saved);
    });
    _scrollToBottom();
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize(
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _errorMsg = _parseError(err);
        });
        if (_errorMsg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(_errorMsg!), backgroundColor: AppColors.danger),
          );
        }
      },
      onStatus: (s) {
        // الإرسال بقى من onResult فقط — تغيير حالة التسجيل لا يُسقط أمرًا
        // ولا يُرسل النص مرتين.
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
    );
    if (!ok && mounted) {
      setState(() => _errorMsg = 'المصوت غير متاح على جهازك');
    }
  }

  String _parseError(dynamic err) {
    final msg = err.errorMsg?.toString() ?? '';
    if (msg.contains('timeout') || msg.contains('speech_timeout')) {
      return 'لم يتم اكتشاف أي كلام، حاول مرة أخرى';
    }
    if (msg.contains('no_match') || msg.contains('notRecognized')) {
      return 'لم أتمكن من التعرف على الكلام، حاول مجددًا';
    }
    if (msg.contains('permission') || msg.contains('unavailable')) {
      return 'يرجى السماح بالوصول للميكروفون من إعدادات الجهاز';
    }
    if (msg.contains('network')) {
      return 'خطأ في الاتصال بالإنترنت';
    }
    return 'حدث خطأ أثناء التعرف على الكلام';
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _stt.stop();
    super.dispose();
  }

  /// إرسال رسالة — محمي من الإرسال المزدوج، ورسالة المستخدم لا تُفقد أبدًا
  /// حتى لو فشلت العملية (§7)، وأي خطأ يظهر كرسالة عربية مفهومة (§8).
  Future<void> _send(String rawText) async {
    final t = rawText.trim();
    if (t.isEmpty || _busy) return;
    _busy = true;

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.user,
      text: t,
      time: DateTime.now(),
    );
    final statusMsg = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.status,
      text: 'جارٍ التنفيذ…',
      time: DateTime.now(),
    );

    setState(() {
      _msgs.add(userMsg);
      _msgs.add(statusMsg);
      _text.clear();
    });
    _scrollToBottom();

    // نحفظ رسالة المستخدم فورًا — مش بتضيع لو العملية فشلت.
    try {
      await ChatHistoryService.append(userMsg);
    } catch (e, st) {
      AppErrorService.log('chat.saveUser', e, st);
    }

    String reply;
    try {
      reply = await AssistantController.handle(t);
    } catch (e, st) {
      AppErrorService.log('chat.handle', e, st);
      reply = AppErrorService.userMessage(e);
    }

    if (!mounted) return;
    final out = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.assistant,
      text: reply,
      time: DateTime.now(),
    );
    setState(() {
      _msgs.removeWhere((m) => m.id == statusMsg.id);
      _msgs.add(out);
      _busy = false;
    });
    _scrollToBottom();

    try {
      await ChatHistoryService.append(out);
    } catch (e, st) {
      AppErrorService.log('chat.saveReply', e, st);
    }
  }

  /// مسح سجل المحادثة — بطلب صريح من المستخدم (§4).
  Future<void> _clearHistory() async {
    try {
      await ChatHistoryService.clear();
    } catch (e, st) {
      AppErrorService.log('chat.clearHistory', e, st);
    }
    if (!mounted) return;
    setState(() => _msgs.clear());
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _stt.stop();
      setState(() {
        _listening = false;
        _errorMsg = null;
      });
      return;
    }

    // Check availability first
    final available = await _stt.initialize();
    if (!available) {
      setState(() => _errorMsg = 'المصوت غير متاح على جهازك');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('المصوت غير متاح على جهازك، تحقق من إعدادات الجهاز'),
            backgroundColor: AppColors.danger,
            action: SnackBarAction(
                label: 'حسنًا', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }
      return;
    }

    setState(() {
      _listening = true;
      _errorMsg = null;
      _voiceSent = false;
    });

    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'ar_EG',
        listenMode: ListenMode.confirmation,
      ),
      onResult: (r) {
        if (!r.finalResult) return;
        final words = r.recognizedWords.trim();
        // نعرض النص المسموع للمستخدم ثم نرسله **مرة واحدة فقط** (§7).
        if (words.isEmpty || _voiceSent || _busy) return;
        _voiceSent = true;
        setState(() => _text.text = words);
        _send(words);
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpace.x2),
            const Text('مساعد الإدارة'),
          ],
        ),
        actions: [
          if (_listening)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpace.x2),
              child: _PulsingMic(),
            ),
          PopupMenuButton<String>(
            tooltip: 'خيارات المحادثة',
            onSelected: (v) {
              if (v == 'clear') _clearHistory();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('مسح المحادثة')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _msgs.isEmpty
                ? _EmptyState()
                : _MessagesList(msgs: _msgs, scroll: _scroll),
          ),

          // Loading bar
          if (_busy)
            const LinearProgressIndicator(
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.primary,
              minHeight: 2,
            ),

          // Input bar
          _InputBar(
            controller: _text,
            listening: _listening,
            busy: _busy,
            onSend: _send,
            onMic: _toggleListen,
          ),
        ],
      ),
    );
  }
}

/// Messages list with date separators
class _MessagesList extends StatelessWidget {
  final List<ChatMessage> msgs;
  final ScrollController scroll;

  const _MessagesList({required this.msgs, required this.scroll});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    String? lastDay;

    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      if (m.dayKey != lastDay) {
        items.add(_DateSeparator(label: _dayLabel(m.dayKey)));
        lastDay = m.dayKey;
      }
      items.add(_Bubble(msg: m, showTail: !_isSameDayAndRole(msgs, i)));
    }

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.x3,
        AppSpace.x2,
        AppSpace.x3,
        AppSpace.x2,
      ),
      children: items,
    );
  }

  bool _isSameDayAndRole(List<ChatMessage> msgs, int i) {
    if (i == msgs.length - 1) return false;
    final curr = msgs[i];
    final next = msgs[i + 1];
    return curr.role == next.role && curr.dayKey == next.dayKey;
  }
}

String _dayLabel(String key) {
  final parts = key.split('-');
  final d =
      DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (d == today) return 'اليوم';
  if (d == yesterday) return 'أمس';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Pill-shaped date separator
class _DateSeparator extends StatelessWidget {
  final String label;

  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.x3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.x3,
            vertical: AppSpace.x1,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            label,
            style: AppText.caption.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chat bubble
class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final bool showTail;

  const _Bubble({required this.msg, required this.showTail});

  String get _time =>
      '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // رسالة حالة (جارٍ التنفيذ…) — pill متوسط ومكتوم.
    if (msg.role == ChatRole.status) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.x3,
              vertical: AppSpace.x1,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              msg.text,
              style: AppText.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    final isUser = msg.role == ChatRole.user;

    // User bubble: teal bg, white text, right-aligned
    // Assistant bubble: white bg, dark text, left-aligned
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x1),
      child: Align(
        alignment: isUser
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isUser ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadiusDirectional.only(
                    // Top-left (start) is rounded for user, sharp for assistant
                    topStart: Radius.circular(isUser ? AppRadius.lg : 0),
                    // Top-right (end) is sharp for user, rounded for assistant
                    topEnd: Radius.circular(isUser ? 0 : AppRadius.lg),
                    // Bottom-start: rounded if same-side-as-top is rounded (user), else sharp
                    bottomStart: Radius.circular(showTail ? AppRadius.lg : 0),
                    // Bottom-end: rounded if same-side-as-top is rounded (assistant), else sharp
                    bottomEnd: Radius.circular(
                        showTail ? (isUser ? 0 : AppRadius.lg) : 0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isUser ? AppColors.primary : Colors.black)
                          .withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.x4,
                  vertical: AppSpace.x3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      msg.text,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        height: 1.6,
                        color: isUser ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _time,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Input bar with mic toggle and send
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool listening;
  final bool busy;
  final void Function(String) onSend;
  final VoidCallback onMic;

  const _InputBar({
    required this.controller,
    required this.listening,
    required this.busy,
    required this.onSend,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.x3,
        AppSpace.x2,
        AppSpace.x3,
        AppSpace.x3,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Mic button
            _MicButton(listening: listening, busy: busy, onTap: onMic),

            const SizedBox(width: AppSpace.x2),

            // Text field
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (listening)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.x4,
                        vertical: AppSpace.x3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          _PulsingDot(),
                          const SizedBox(width: AppSpace.x2),
                          const Expanded(
                            child: Text(
                              'جارٍ الاستماع...',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 15,
                                color: AppColors.primary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.mic,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  if (!listening)
                    TextField(
                      controller: controller,
                      enabled: !busy,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      style:
                          const TextStyle(fontFamily: 'Tajawal', fontSize: 15),
                      decoration: InputDecoration(
                        hintText: busy ? 'جارٍ الرد...' : 'اكتب ما تريد...',
                        hintStyle: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          color: AppColors.textDisabled,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.x4,
                          vertical: AppSpace.x3,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: AppSpace.x2),

            // Send button
            _SendButton(
              enabled: !listening && !busy,
              onTap: () => onSend(controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mic button with visual state
class _MicButton extends StatelessWidget {
  final bool listening;
  final bool busy;
  final VoidCallback onTap;

  const _MicButton({
    required this.listening,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !busy;
    final color = listening
        ? AppColors.danger
        : (enabled ? AppColors.primary : AppColors.textDisabled);

    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            listening ? Icons.mic_off : Icons.mic,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Send button
class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.primary : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.send,
            color: enabled ? Colors.white : AppColors.textDisabled,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Pulsing mic indicator in app bar
class _PulsingMic extends StatefulWidget {
  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _a = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 14, color: AppColors.danger),
            SizedBox(width: 4),
            Text(
              'يتكلم',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing dot for listening state
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Empty state
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpace.x5),
            Text(
              'مساعدك الذكي',
              style: AppText.titleMedium,
            ),
            const SizedBox(height: AppSpace.x2),
            Text(
              'اتكلم أو اكتب بالأسلوب العادي\nمثال: "أحمد عليه 3500 هيدفع الخميس"',
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
