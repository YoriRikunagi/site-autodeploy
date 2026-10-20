#!/usr/bin/env bash
# Проверка живого сайта после выкладки: страницы открываются, на них нужная версия и важные элементы.
# Что проверять, задаётся в deploy/smoke-checks.txt.
set -uo pipefail
URL="${1%/}"; ID="$2"
fail=0

page() { curl -fsSL --max-time 15 "$URL/$1?v=$ID-$RANDOM"; }

echo "Ждём, пока на сайте появится версия №$ID"
for i in $(seq 1 18); do
  page "" | grep -q "name=\"release\" content=\"$ID\"" && { echo "Версия №$ID на сайте"; break; }
  [ "$i" = 18 ] && { echo "::error::версия №$ID так и не появилась на сайте"; exit 1; }
  sleep 10
done

while IFS='|' read -r path text; do
  trim() { sed -E 's/^[[:space:]]+|[[:space:]]+$//g'; }
  path=$(printf '%s' "$path" | trim); text=$(printf '%s' "$text" | trim)
  if [ -z "$path" ] || [ "${path:0:1}" = "#" ]; then continue; fi
  [ "$path" = "/" ] && path=""
  body=$(page "$path") || { echo "::error::страница /$path не открывается"; fail=1; continue; }
  if echo "$body" | grep -qF -- "$text"; then echo "ок  /$path  «$text»"
  else echo "::error::на странице /$path нет «$text»"; fail=1; fi
done < deploy/smoke-checks.txt

exit $fail
