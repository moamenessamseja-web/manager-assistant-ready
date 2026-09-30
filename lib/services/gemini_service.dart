import 'dart:convert';
import 'package:http/http.dart' as http;
class GeminiService {
 final String apiKey;
 GeminiService(this.apiKey);
 Future<Map<String,dynamic>> parse(String text) async {
  final today=DateTime.now().toIso8601String().substring(0,10);
  final prompt='''أنت مساعد إدارة لمشروع صغير في مصر. التاريخ اليوم $today. حلل كلام المستخدم بالمصري وأرجع JSON فقط. intents: create_commitment, add_employee, add_advance, mark_attendance, other. الحقول: intent, person, type, amount, due_date, remind_at, follow_up_rule, employee_name, employee_role, start_date, salary, text_original. type واحد من debt_to_collect/debt_to_pay/supplier/task/rent/booking. افهم بكرة وبعده والخميس الجاي وأول الشهر. لا تخترع معلومات غير مذكورة. إذا كان التزام واضحاً بلا موعد تذكير، اجعل التذكير غداً 09:00. النص: $text''';
  final body={'contents':[{'parts':[{'text':prompt}]}],'generationConfig':{'temperature':0.1,'responseMimeType':'application/json','responseSchema':{'type':'OBJECT','properties':{'intent':{'type':'STRING'},'person':{'type':'STRING'},'type':{'type':'STRING'},'amount':{'type':'NUMBER','nullable':true},'due_date':{'type':'STRING'},'remind_at':{'type':'STRING'},'follow_up_rule':{'type':'STRING'},'employee_name':{'type':'STRING'},'employee_role':{'type':'STRING'},'start_date':{'type':'STRING'},'salary':{'type':'NUMBER','nullable':true},'text_original':{'type':'STRING'}},'required':['intent','text_original']}}};
  final r=await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'),headers:{'Content-Type':'application/json','x-goog-api-key':apiKey},body:jsonEncode(body));
  if(r.statusCode<200||r.statusCode>=300) throw Exception('Gemini API ${r.statusCode}');
  final j=jsonDecode(r.body);final t=j['candidates']?[0]?['content']?['parts']?[0]?['text'];if(t==null)throw Exception('لم يصل رد صالح من Gemini');return Map<String,dynamic>.from(jsonDecode(t));
 }
}
