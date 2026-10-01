import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey;
  GeminiService(this.apiKey);

  // ملاحظة: مفتاح الـ API الحالي مفعّل على Flash-Lite فقط وليس Flash العادي.
  // استخدام أي اسم موديل آخر هنا سيرجع خطأ صلاحيات (403/404) من Google.
  static const String _model = 'gemini-3.5-flash-lite';

  Future<Map<String, dynamic>> parse(String text) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prompt = '''
أنت مساعد إدارة لمشروع صغير (كافيه/مطعم/محل) في مصر. التاريخ اليوم $today.
حلل كلام المستخدم بالعامي المصري وأرجع JSON فقط بدون أي شرح.

النوايا الممكنة (intent):
- create_commitment: دين على عميل، مهمة، حجز، إيجار (كل التزام عادي مش متعلق بموظف أو مورد)
- add_employee: تسجيل موظف جديد
- add_advance: سلفة لموظف
- mark_attendance: تسجيل حضور موظف
- add_supplier: تسجيل مورد جديد (زي "مورد البن" أو "محل الألبان")
- supplier_delivery: توريد متوقع من مورد قائم (كمية وصنف وتاريخ متوقع)
- mark_delivery_received: تأكيد استلام توريد (ويُحسب كدين على المحل للمورد لو ذُكر مبلغ)
- add_supplier_payment: سداد مبلغ لمورد (تقليل المديونية)
- add_rule: قاعدة متابعة متكررة زي "كل أول الشهر فكرني بالإيجار" أو "كل جمعة ابعتلي ملخص"
- other: أي حاجة مش واضحة

الحقول المطلوبة حسب النية:
person: اسم العميل/المورد/الموظف
type: لـ create_commitment فقط: debt_to_collect/debt_to_pay/task/rent/booking
amount: رقم فقط بدون وحدة
due_date: YYYY-MM-DD
remind_at: YYYY-MM-DD HH:mm
follow_up_rule: نص حر لو فيه شرط متابعة
employee_name, employee_role, start_date, salary: لموظف جديد
supplier_item: الصنف الأساسي اللي المورد بيوردّه (بن/لبن/خبز...)
supplier_phone: رقم تليفون لو ذُكر
delivery_item: صنف التوريد المحدد
delivery_quantity: رقم الكمية فقط
delivery_unit: وحدة القياس (كيلو/كرتونة/لتر...)
rule_text: نص القاعدة كاملاً
rule_frequency: monthly/weekly/daily
rule_anchor: رقم يوم الشهر (1-31) لو شهرية، أو رقم يوم الأسبوع (1=إثنين..7=أحد) لو أسبوعية
text_original: نص المستخدم كما هو

افهم التواريخ النسبية: بكرة، بعده، الخميس الجاي، أول الشهر، آخر الشهر.
لا تخترع معلومات غير مذكورة فعلياً في كلام المستخدم.
لو الالتزام واضح بلا موعد تذكير محدد، اجعل التذكير غداً الساعة 09:00.

النص: $text''';

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'intent': {'type': 'STRING'},
            'person': {'type': 'STRING'},
            'type': {'type': 'STRING'},
            'amount': {'type': 'NUMBER', 'nullable': true},
            'due_date': {'type': 'STRING'},
            'remind_at': {'type': 'STRING'},
            'follow_up_rule': {'type': 'STRING'},
            'employee_name': {'type': 'STRING'},
            'employee_role': {'type': 'STRING'},
            'start_date': {'type': 'STRING'},
            'salary': {'type': 'NUMBER', 'nullable': true},
            'supplier_item': {'type': 'STRING'},
            'supplier_phone': {'type': 'STRING'},
            'delivery_item': {'type': 'STRING'},
            'delivery_quantity': {'type': 'NUMBER', 'nullable': true},
            'delivery_unit': {'type': 'STRING'},
            'rule_text': {'type': 'STRING'},
            'rule_frequency': {'type': 'STRING'},
            'rule_anchor': {'type': 'NUMBER', 'nullable': true},
            'text_original': {'type': 'STRING'},
          },
          'required': ['intent', 'text_original']
        }
      }
    };

    final r = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent'),
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
      body: jsonEncode(body),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Gemini API ${r.statusCode}: ${r.body}');
    }
    final j = jsonDecode(r.body);
    final t = j['candidates']?[0]?['content']?['parts']?[0]?['text'];
    if (t == null) throw Exception('لم يصل رد صالح من Gemini');
    return Map<String, dynamic>.from(jsonDecode(t));
  }
}
