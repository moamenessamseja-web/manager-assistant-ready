import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../services/cafe_profile_service.dart';

/// شعار الكافيه (لو اترفع) وإلا أيقونة عامة. ملف مفقود/تالف = الأيقونة، من غير
/// ما الشاشة تنهار. بياخد حجم الأب (جوّه Container بحجم ثابت).
class CafeLogoImage extends StatelessWidget {
  final IconData fallback;
  final Color? color;
  final double size;
  const CafeLogoImage({super.key, required this.fallback, this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final icon = Icon(fallback, size: size, color: color);
        final f = CafeProfileService.logoFile;
        if (f == null) return icon;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(f, fit: BoxFit.cover, errorBuilder: (_, __, ___) => icon),
        );
      },
    );
  }
}

/// اسم الكافيه في العناوين: سطر واحد مع نقط لو طويل.
class CafeNameText extends StatelessWidget {
  final TextStyle? style;
  final int maxLines;
  const CafeNameText({super.key, this.style, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) => Text(
        CafeProfileService.displayName,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
