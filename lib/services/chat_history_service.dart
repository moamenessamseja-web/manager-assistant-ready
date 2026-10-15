import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_error_service.dart';

/// نوع الرسالة — نميّز رسالة المستخدم عن رد المساعد عن حالة التنفيذ (§7).
enum ChatRole { user, assistant, status }

/// رسالة محادثة محفوظة بشكل دائم.
class ChatMessage {
  final String id;

  /// `user` أو `assistant` أو `status` (حالة تنفيذ مؤقتة).
  final ChatRole role;
  final String text;
  final DateTime time;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'time': time.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id']?.toString() ?? '',
        role: ChatRole.values.firstWhere(
          (r) => r.name == j['role'],
          orElse: () => ChatRole.assistant,
        ),
        text: j['text']?.toString() ?? '',
        time: DateTime.tryParse(j['time']?.toString() ?? '') ?? DateTime.now(),
      );

  /// مفتاح اليوم لعرض فواصل التاريخ.
  String get dayKey => DateTime(time.year, time.month, time.day)
      .toIso8601String()
      .substring(0, 10);
}

/// سجل المحادثة الدائم (§7).
///
/// الرسائل تُحفظ محليًا (SharedPreferences) فتبقى بعد إغلاق الشاشة أو إعادة
/// تشغيل التطبيق. القراءة متسامحة مع أي سجل تالف — تُتخطّى المدخلات التالفة
/// فقط ولا تُمسح بقية المحادثة.
class ChatHistoryService {
  ChatHistoryService._();

  static SharedPreferences? _p;
  static const String _kKey = 'chat_history_v1';

  /// أقصى عدد رسائل محفوظة — نُبقي الأحدث ونحذف الأقدم.
  static const int maxMessages = 300;

  static Future<void> init() async {
    _p ??= await SharedPreferences.getInstance();
  }

  /// كل الرسائل المحفوظة بترتيبها الزمني.
  static List<ChatMessage> all() {
    final raw = _p?.getString(_kKey);
    if (raw == null || raw.isEmpty) return <ChatMessage>[];
    try {
      final list = jsonDecode(raw) as List;
      final out = <ChatMessage>[];
      var corrupt = 0;
      for (final e in list) {
        try {
          out.add(ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)));
        } catch (err) {
          corrupt++;
          AppErrorService.log('chatHistory.read', err);
        }
      }
      if (corrupt > 0) {
        AppErrorService.log('chatHistory.read',
            'تخطّينا $corrupt مدخلًا تالفًا من أصل ${list.length}.');
      }
      return out;
    } catch (e, s) {
      AppErrorService.log('chatHistory.read', e, s);
      // لا نمسح السجل التالف ولا نُسقط التطبيق.
      return <ChatMessage>[];
    }
  }

  static Future<void> _writeAll(List<ChatMessage> msgs) async {
    await init();
    final trimmed = msgs.length > maxMessages
        ? msgs.sublist(msgs.length - maxMessages)
        : msgs;
    try {
      final ok = await _p!.setString(
        _kKey,
        jsonEncode(trimmed.map((m) => m.toJson()).toList()),
      );
      if (!ok) throw StorageException('فشل حفظ سجل المحادثة');
    } catch (e, s) {
      AppErrorService.log('chatHistory.write', e, s);
      rethrow;
    }
  }

  /// إضافة رسالة واحدة (الأكثر استخدامًا).
  static Future<void> append(ChatMessage m) => _writeAll([...all(), m]);

  /// استبدال السجل كاملًا (يُستخدم عند تعديل/حذف رسالة).
  static Future<void> replaceAll(List<ChatMessage> msgs) => _writeAll(msgs);

  /// مسح سجل المحادثة بالكامل — يطلبه المستخدم صراحةً (§4).
  static Future<void> clear() async {
    await init();
    await _p!.remove(_kKey);
  }
}
