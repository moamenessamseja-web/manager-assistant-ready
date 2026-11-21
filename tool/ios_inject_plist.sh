#!/usr/bin/env bash
# Adds the iOS privacy strings required by speech_to_text to ios/Runner/Info.plist.
# Run after `flutter create --platforms=ios ...`. Idempotent. macOS only (PlistBuddy).
set -euo pipefail
PLIST="ios/Runner/Info.plist"
[ -f "$PLIST" ] || { echo "missing $PLIST"; exit 1; }
PB=/usr/libexec/PlistBuddy
add() {
  local key="$1" val="$2"
  if "$PB" -c "Print :$key" "$PLIST" >/dev/null 2>&1; then
    "$PB" -c "Set :$key $val" "$PLIST"
  else
    "$PB" -c "Add :$key string $val" "$PLIST"
  fi
}
add NSMicrophoneUsageDescription "نستخدم الميكروفون عشان تقول الأمر بصوتك ويتحوّل لنص تراجعه قبل ما تبعته."
add NSSpeechRecognitionUsageDescription "نستخدم التعرف على الكلام لتحويل صوتك لنص داخل حقل الكتابة. النص بيفضل عندك للمراجعة ومش بيتنفّذ تلقائيًا."
"$PB" -c "Print :NSMicrophoneUsageDescription" "$PLIST" >/dev/null
"$PB" -c "Print :NSSpeechRecognitionUsageDescription" "$PLIST" >/dev/null
echo "Info.plist speech/microphone usage descriptions present."
