import 'package:flutter/foundation.dart';

/// نقطة إشعار مركزية وحيدة: أي كتابة بيانات في StorageService بتستدعي
/// AppState.instance.notify()، فأي شاشة أو ودجت بيسمع لها بيتحدّث فورًا —
/// بدل ما يحتاج المستخدم يقفل التطبيق ويفتحه تاني عشان يشوف بيانات محدّثة
/// اتسجلت من شاشة تانية (مثلاً سجل من الشات وهو واقف في شاشة اليوم).
///
/// عمدًا بسيطة وعامة (ChangeNotifier واحد لكل التطبيق) بدل state management
/// framework جديد — أصغر تغيير ممكن يحل المشكلة الفعلية.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  void notify() => notifyListeners();
}
