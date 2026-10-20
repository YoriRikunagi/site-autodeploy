#!/usr/bin/env bash
# Проверки перед выкладкой. Любая ошибка — выкладка не начинается, сайт остаётся как был.
set -uo pipefail
SITE="${1:-site}"
fail=0
err() { echo "::error::$*"; fail=1; }

echo "1) Обязательные файлы"
for f in index.html; do
  [ -f "$SITE/$f" ] || err "нет файла $SITE/$f"
done

echo "2) Синтаксис PHP"
while IFS= read -r -d '' f; do
  php -l "$f" >/dev/null 2>&1 || err "ошибка синтаксиса PHP: $f"
done < <(find "$SITE" -name '*.php' -print0)

echo "3) Разметка HTML"
npx --yes html-validate@9 --config scripts/htmlvalidate.json "$SITE/**/*.html" || err "ошибки в HTML (подробности выше)"

echo "4) Внутренние ссылки"
while IFS= read -r -d '' page; do
  dir=$(dirname "$page")
  grep -oE '(href|src)="[^"#?]+' "$page" | sed -E 's/^(href|src)="//' | while read -r link; do
    case "$link" in http*|mailto:*|tel:*|//*) continue ;; esac
    [ -e "$dir/$link" ] || echo "::error::битая ссылка в $page: $link"
  done
done < <(find "$SITE" -name '*.html' -print0) | tee /tmp/links.log
grep -q '::error::' /tmp/links.log && fail=1

echo "5) Пароли и ключи не попали в репозиторий"
if grep -rInE '(DB_PASSWORD|password\s*=\s*["'"'"'][^"'"'"']+|api[_-]?key\s*[:=]|BEGIN (RSA|OPENSSH) PRIVATE KEY)' "$SITE" ; then
  err "похоже на пароль или ключ в коде сайта"
fi
find "$SITE" -name '.env*' | grep -q . && err "в сайте лежит .env"

[ $fail -eq 0 ] && echo "Все проверки пройдены" || echo "Проверки не пройдены, выкладка отменена"
exit $fail
