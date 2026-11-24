import 'package:flutter/material.dart';
import '../design/tokens.dart';

/// هيكل موحّد لنماذج الإدخال السريع (bottom sheet): عنوان + حقول + رسالة خطأ + حفظ.
class FormSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final String? error;
  final bool saving;
  final VoidCallback onSave;
  final String saveLabel;

  const FormSheet({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.error,
    this.saving = false,
    this.saveLabel = 'حفظ',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpace.x4, AppSpace.x4, AppSpace.x4, MediaQuery.of(context).viewInsets.bottom + AppSpace.x4),
      child: ConstrainedBox(
        // Keep long forms inside the visible viewport; their contents scroll
        // instead of placing the save action below the physical screen.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.x3),
            for (final c in children) ...[c, const SizedBox(height: AppSpace.x3)],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.x3),
                child: Text(error!, style: const TextStyle(color: AppColors.danger)),
              ),
            FilledButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(saveLabel),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showFormSheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => child,
    );
